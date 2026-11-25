package chats

import (
	"context"
	"fmt"
	"reflect"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// eventually waits for cond, checked under the chat's lock.
func eventually(t *testing.T, c *chat, cond func() bool) {
	t.Helper()
	testcheck.Wait(t, "a condition under the chat's lock", func() bool {
		c.mu.Lock()
		defer c.mu.Unlock()
		return cond()
	})
}

// idle waits until the chat's published status says its turn is over.
func idle(t *testing.T, c *chat) {
	t.Helper()
	eventually(t, c, func() bool { return !c.statusLocked().Busy })
}

func (f *fakeAgent) texts() ([]string, []string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]string(nil), f.prompts...), append([]string(nil), f.steered...)
}

func TestQueueGoesAfterTheTurnInOrder(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	send := func(text string, how Send) error {
		return svc.Prompt(t.Context(), c.id, model.Message{Text: text}, how)
	}
	if err := send("one", SendIdle); err != nil {
		t.Fatal(err)
	}
	if send("two", SendIdle) == nil {
		t.Error("a busy chat took a prompt without queueing it")
	}
	for _, text := range []string{"two", "three", "four"} {
		if err := send(text, SendQueue); err != nil {
			t.Fatal(err)
		}
	}
	if m, err := svc.Unqueue(c.id, c.queue[1].ID); err != nil || m.Text != "three" {
		t.Errorf("Unqueue = %+v, %v", m, err)
	}
	agent.release()
	eventually(t, c, func() bool { return len(c.queue) == 1 && c.busyLocked() })
	agent.release()
	eventually(t, c, func() bool { return len(c.queue) == 0 && c.busyLocked() })
	agent.release()
	idle(t, c)
	if got, _ := agent.texts(); !reflect.DeepEqual(got, []string{"one", "two", "four"}) {
		t.Errorf("prompts = %q", got)
	}
}

// Unqueue racing the turn's end, which sends the queue's first message:
// the message is either taken back or sent, never both and never lost.
func TestUnqueueAsTheTurnEnds(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	send := func(text string, how Send) {
		t.Helper()
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: text}, how))
	}
	send("first", SendIdle)
	var took, sent []string
	for i := range 30 {
		eventually(t, c, func() bool { return c.busyLocked() && len(c.queue) == 0 })
		text := fmt.Sprintf("q%d", i)
		send(text, SendQueue)
		c.mu.Lock()
		id := c.queue[0].ID
		c.mu.Unlock()
		var wg sync.WaitGroup
		var err error
		var m model.Message
		wg.Go(func() { m, err = svc.Unqueue(c.id, id) })
		wg.Go(agent.release)
		wg.Wait()
		switch {
		case err == nil && m.Text == text:
			took = append(took, text)
			idle(t, c)
			send(fmt.Sprintf("t%d", i), SendIdle)
		case err != nil && strings.Contains(err.Error(), "has it already"):
			sent = append(sent, text)
		default:
			t.Fatalf("Unqueue = %+v, %v", m, err)
		}
	}
	agent.release()
	idle(t, c)
	t.Logf("%d taken back, %d sent", len(took), len(sent))
	prompts, _ := agent.texts()
	for _, text := range sent {
		if n := len(slices.DeleteFunc(slices.Clone(prompts), func(p string) bool { return p != text })); n != 1 {
			t.Errorf("%s, sent, reached the agent %d times", text, n)
		}
	}
	for _, text := range took {
		if slices.Contains(prompts, text) {
			t.Errorf("%s, taken back, reached the agent", text)
		}
	}
}

func TestQueueSteersBetweenToolCalls(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.steerable, c.steer = true, true
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendQueue))
	if _, steered := agent.texts(); len(steered) != 0 {
		t.Fatalf("steered %q before the agent's chance", steered)
	}
	ranTool(c, "t1")
	eventually(t, c, func() bool { return len(c.items) == 3 && c.items[2].Text == "two" })
	eventually(t, c, func() bool { _, steered := agent.texts(); return reflect.DeepEqual(steered, []string{"two"}) })
	agent.release()
	idle(t, c)
}

func TestSendNowStopsTheTurn(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "held"}, SendQueue))
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "now"}, SendNow); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return c.busyLocked() && c.items[len(c.items)-1].Text == "now" })
	if c.items[1].Kind != model.Notice || len(c.queue) != 1 {
		t.Errorf("items = %+v, queue = %+v", c.items, c.queue)
	}
	agent.release()
	eventually(t, c, func() bool { return len(c.queue) == 0 })
	eventually(t, c, func() bool { got, _ := agent.texts(); return reflect.DeepEqual(got, []string{"one", "now", "held"}) })
	agent.release()
	idle(t, c) // else Close's cancel could close the gate the release did
}

// A subagent's own step ending isn't the agent's chance: a message steered
// in then would send the subagent's Agent call to the background.
func TestQueueWaitsOutASubagentsSteps(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.steerable, c.steer = true, true
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendQueue))
	call := func(id string, meta map[string]any) {
		send(c, acp.SessionUpdate{SessionUpdate: "tool_call",
			ToolCall: &acp.ToolCall{ToolCallID: acp.ToolCallID(id), Title: "ls", Status: "in_progress", Meta: meta}})
		send(c, acp.SessionUpdate{SessionUpdate: "tool_call_update",
			ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Status: "completed"}})
	}
	call("sub1", map[string]any{"claudeCode": map[string]any{"parentToolUseId": "agent1"}})
	// The update is taken under the chat's lock, and a steer it began is
	// marked so there (steering) before its worker takes the message.
	c.mu.Lock()
	steering, queued := c.steering, len(c.queue)
	c.mu.Unlock()
	if _, steered := agent.texts(); steering || len(steered) != 0 || queued != 1 {
		t.Fatalf("steering %v, steered %q, %d queued after a subagent's step", steering, steered, queued)
	}
	call("t1", nil)
	eventually(t, c, func() bool { _, steered := agent.texts(); return reflect.DeepEqual(steered, []string{"two"}) })
	agent.release()
	idle(t, c)
}

// A stopped turn holds the queue: a tool call the stop fails, ending
// before the agent's answer, is no chance to steer the next message in.
func TestAToolEndAfterStopSteersNothing(t *testing.T) {
	svc, agent, c := newTimedChat(t, `{"sessionId":"s1"}`, &memModes{}, Timing{StopGrace: 20 * time.Millisecond}) // Stop gives up on the held turn at once
	agent.steerable, c.steer = true, true
	agent.ignoreCancel = true
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendQueue))
	send(c, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "ls", Status: "in_progress"}})
	if _, err := svc.Stop(context.Background(), c.id, false); err != nil {
		t.Fatal(err)
	}
	send(c, acp.SessionUpdate{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "failed"}})
	eventually(t, c, func() bool { return !c.steering })
	if _, steered := agent.texts(); len(steered) > 0 {
		t.Errorf("steered %q into the stopped turn", steered)
	}
	agent.release()
	idle(t, c)
	c.mu.Lock()
	defer c.mu.Unlock()
	if !c.held || len(c.queue) != 1 || c.queue[0].Text != "two" {
		t.Errorf("held %v, queue %+v", c.held, c.queue)
	}
}

// A Stop while a steered message is out ends the hand-off: the agent may
// take that one, the rest stays in the queue, held.
func TestStopEndsTheSteering(t *testing.T) {
	svc, agent, c := newTimedChat(t, `{"sessionId":"s1"}`, &memModes{}, Timing{StopGrace: 20 * time.Millisecond}) // Stop gives up on the held turn at once
	agent.steerable, c.steer = true, true
	agent.ignoreCancel = true
	agent.gate, agent.steerGate = make(chan struct{}), make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendQueue))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "three"}, SendQueue))
	ranTool(c, "t1")
	eventually(t, c, func() bool { return len(c.queue) == 1 }) // "two" is out
	if _, err := svc.Stop(context.Background(), c.id, false); err != nil {
		t.Fatal(err)
	}
	close(agent.steerGate) // the agent took "two" before the stop reached it
	eventually(t, c, func() bool { return !c.steering })
	if _, steered := agent.texts(); !reflect.DeepEqual(steered, []string{"two"}) {
		t.Errorf("steered %q", steered)
	}
	agent.release()
	idle(t, c)
	c.mu.Lock()
	defer c.mu.Unlock()
	if !c.held || len(c.queue) != 1 || c.queue[0].Text != "three" {
		t.Errorf("held %v, queue %+v", c.held, c.queue)
	}
}

// A message with images for an agent that takes none is refused while the
// chat is busy as when it is idle; one queued while the chat reopened, before
// that was known, goes without them, steered or as the next prompt, and the
// chat says so.
func TestQueuedImagesGoOnlyToAnAgentThatTakesThem(t *testing.T) {
	for _, steer := range []bool{false, true} {
		svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
		agent.steerable, c.steer = steer, steer
		agent.gate = make(chan struct{})
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
		eventually(t, c, func() bool { return !c.started.IsZero() })
		pic := model.Message{Text: "pic", Images: []model.Image{{MimeType: "image/png", Data: []byte("png")}}}
		c.mu.Lock()
		c.canImage = false
		c.mu.Unlock()
		if svc.Prompt(t.Context(), c.id, pic, SendQueue) == nil {
			t.Fatal("queued images for an agent that takes none")
		}
		c.mu.Lock()
		pic.ID = "q1" // as queued while the chat reopened
		c.queue = append(c.queue, pic)
		c.mu.Unlock()
		if steer {
			ranTool(c, "t1")
			eventually(t, c, func() bool { _, steered := agent.texts(); return len(steered) == 1 })
		} else {
			agent.release()
			eventually(t, c, func() bool { prompts, _ := agent.texts(); return len(prompts) == 2 })
		}
		agent.mu.Lock()
		last := agent.prompt
		if steer {
			last = agent.steerBlocks
		}
		agent.mu.Unlock()
		if len(last) == 0 || last[0].Text == nil || last[0].Text.Text != "pic" {
			t.Fatalf("steer %v: the agent's last message isn't the queued one: %+v", steer, last)
		}
		for _, b := range last {
			if b.Image != nil {
				t.Errorf("steer %v: an image went to an agent that takes none", steer)
			}
		}
		agent.release()
		idle(t, c)
		// The message as the transcript has it is what went: its blocks are made from it.
		c.mu.Lock()
		i := slices.IndexFunc(c.items, func(it model.Item) bool { return it.Text == "pic" })
		withImages := i < 0 || len(c.items[i].Images) > 0
		said := slices.ContainsFunc(c.items, func(it model.Item) bool { return it.Kind == model.Notice && strings.Contains(it.Text, "without them") })
		c.mu.Unlock()
		if withImages || !said {
			t.Errorf("steer %v: the message went with its images (%v), or the chat doesn't say they didn't (%v): %q", steer, withImages, !said, texts(c))
		}
	}
}

// Send now on a queued message whose send doesn't happen (the request
// ends while the agent winds its turn down) leaves it where it was in the
// queue: it isn't lost between taking it out and sending it.
func TestSendNowOfAQueuedMessageThatDoesntGoKeepsIt(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate, agent.ignoreCancel = make(chan struct{}), true
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	for _, text := range []string{"a", "b"} {
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: text}, SendQueue))
	}
	c.mu.Lock()
	id := c.queue[0].ID
	c.mu.Unlock()
	ctx, cancel := context.WithCancel(t.Context())
	sent := make(chan error, 1)
	go func() { sent <- svc.SendQueuedNow(ctx, c.id, id) }()
	eventually(t, c, func() bool { return c.sendingNow == 2 }) // taken (takeToSend), and waiting for the turn to end
	cancel()
	if err := <-sent; err == nil {
		t.Fatal("sent")
	}
	c.mu.Lock()
	var queued []string
	for _, m := range c.queue {
		queued = append(queued, m.Text)
	}
	c.mu.Unlock()
	if !reflect.DeepEqual(queued, []string{"a", "b"}) {
		t.Errorf("queue %q", queued)
	}
	agent.release()
	idle(t, c)
}

// Send now on a queued message stops the turn and sends it, in one call:
// it leaves the queue, and goes ahead of what stays queued.
func TestSendNowOfAQueuedMessage(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	for _, text := range []string{"a", "b"} {
		testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: text}, SendQueue))
	}
	c.mu.Lock()
	id := c.queue[1].ID
	c.mu.Unlock()
	testcheck.NoErr(t, svc.SendQueuedNow(t.Context(), c.id, id))
	eventually(t, c, func() bool { return c.busyLocked() && c.items[len(c.items)-1].Text == "b" && len(c.queue) == 1 })
	agent.release()
	eventually(t, c, func() bool { got, _ := agent.texts(); return reflect.DeepEqual(got, []string{"one", "b", "a"}) })
	agent.release()
	idle(t, c)
}

// A queued message on its way to the agent (Send now) keeps its chat from
// resting from the moment it leaves the queue: a restart that saw the
// chat quiet before the message reached the agent would refuse it, and
// the queue it went back to dies with the daemon.
func TestSendNowOfAQueuedMessageHoldsARestart(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "a"}, SendQueue))
	if _, err := svc.Stop(t.Context(), c.id, false); err != nil {
		t.Fatal(err)
	}
	idle(t, c) // stopped: the queue is held, and only Send now sends it
	c.mu.Lock()
	id := c.queue[0].ID
	c.mu.Unlock()
	taken, m, at, err := svc.takeToSend(c.id, id)
	testcheck.NoErr(t, err)
	if ok, _ := svc.Rest(); ok {
		svc.Unrest()
		t.Fatal("Rest found the chat quiet with its message on its way")
	}
	testcheck.NoErr(t, svc.sendTaken(t.Context(), taken, m, at))
	agent.release()
	eventually(t, c, func() bool { got, _ := agent.texts(); return reflect.DeepEqual(got, []string{"one", "a"}) })
	idle(t, c)
	if ok, holding := svc.Rest(); !ok {
		t.Errorf("the chat holds a restart once its message went: %s", holding)
	}
}

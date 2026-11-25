package chats

import (
	"context"
	"slices"
	"strings"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestRewindForksBeforeTheMessage(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	if err := svc.SetConfig(context.Background(), c.id, "mode", "plan"); err != nil {
		t.Fatal(err)
	}
	turn := func(text, reply string) {
		// A tool call after the agent's text: the fork at the text drops it.
		agent.updates = []acp.SessionUpdate{chunk(reply, "ok"), {SessionUpdate: "tool_call",
			ToolCall: &acp.ToolCall{ToolCallID: acp.ToolCallID("t-" + reply), Title: "ls", Status: "completed"}}}
		if err := svc.Prompt(t.Context(), c.id, model.Message{Text: text}, SendIdle); err != nil {
			t.Fatal(err)
		}
		idle(t, c)
	}
	turn("one", "m1")
	turn("two", "m2")
	turn("three", "m3")
	if c.items[3].ForkAt != "m1" || c.items[0].ForkAt != "" {
		t.Fatalf("fork points: %+v", c.items)
	}
	if c.items[3].Sent.IsZero() || c.items[4].Sent.IsZero() {
		t.Errorf("each message has its time: %v, %v", c.items[3].Sent, c.items[4].Sent)
	}
	m, err := svc.Rewind(context.Background(), c.id, c.items[3].ID)
	if err != nil || m.Text != "two" {
		t.Fatalf("Rewind = %+v, %v", m, err)
	}
	fork := agent.forkMeta["jetbrains"].(map[string]any)["air"].(map[string]any)["fork"].(map[string]any)
	if fork["messageId"] != "m1" || len(c.items) != 2 || c.sid != "fork1" || c.record.SessionID != "fork1" ||
		len(c.record.Earlier) != 1 || c.record.Earlier[0].ID != "s1" {
		t.Errorf("fork %v, items %+v, session %+v", fork, c.items, c.record)
	}

	// Back to the first message: a new session, a chat without messages.
	if _, err := svc.Rewind(context.Background(), c.id, c.items[0].ID); err != nil {
		t.Fatal(err)
	}
	if len(c.items) != 0 || c.sid != "s1" || c.record.Title != "" || c.record.HasMessages || len(c.record.Earlier) != 2 {
		t.Errorf("items %+v, session %+v", c.items, c.record)
	}
	if c.record.Mode != "plan" || current(c, "mode") != "plan" {
		t.Errorf("after rewinding, mode %q (stored %q), want plan", current(c, "mode"), c.record.Mode)
	}
}

// Rewind refuses while the chat or its agent works; and a fork that lands
// after its agent quit or its message went changes nothing: the chat
// keeps its items, its session and its copy, says why, and the fork is
// left for Delete or the next reopen to throw away.
func TestRewindFailures(t *testing.T) {
	svc, agent, c, store, _ := newCopyingChat(t)
	for _, text := range []string{"one", "two"} {
		agent.updates = []acp.SessionUpdate{chunk("m-"+text, "ok")}
		turn(t, svc, c, text)
	}
	two := c.items[2].ID
	conversation := describe(c.items)

	// A turn under way, held by the agent.
	agent.mu.Lock()
	agent.gate, agent.updates = make(chan struct{}), []acp.SessionUpdate{chunk("m-three", "ok")}
	gate := agent.gate
	agent.mu.Unlock()
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "three"}, SendIdle))
	if _, err := svc.Rewind(t.Context(), c.id, two); err == nil || !strings.Contains(err.Error(), "busy") {
		t.Errorf("during a turn: %v, want busy", err)
	}
	close(gate)
	idle(t, c)
	agent.mu.Lock()
	agent.gate = nil // the turn left a new one
	agent.mu.Unlock()

	for _, r := range []struct {
		name, says string
		block      func(c *chat) (undo func())
	}{
		{"the agent's own turn", "on its own", func(c *chat) func() { c.ownTurn = true; return func() { c.ownTurn = false } }},
		{"a prompt waiting on the user", "waiting for your answer", func(c *chat) func() {
			c.waiting["p"] = make(chan string, 1)
			return func() { delete(c.waiting, "p") }
		}},
		{"a background subagent", "in the background", func(c *chat) func() {
			c.items = append(c.items, model.Item{ID: "sa", Subagent: &model.Subagent{State: "running"}})
			return func() { c.items = c.items[:len(c.items)-1] }
		}},
	} {
		c.mu.Lock()
		undo := r.block(c)
		c.mu.Unlock()
		_, err := svc.Rewind(t.Context(), c.id, two)
		c.mu.Lock()
		undo()
		c.mu.Unlock()
		if err == nil || !strings.Contains(err.Error(), r.says) {
			t.Errorf("%s: %v, want %q", r.name, err, r.says)
		}
	}
	if _, err := svc.Rewind(t.Context(), c.id, "nothing"); err == nil {
		t.Error("rewound to no message")
	}

	unchanged := func(what string, err error, says string) {
		t.Helper()
		c.mu.Lock()
		defer c.mu.Unlock()
		if err == nil || !strings.Contains(err.Error(), says) {
			t.Errorf("%s: %v, want %q", what, err, says)
		}
		var said []model.Item
		for _, it := range c.items {
			if it.Kind == model.Notice {
				said = append(said, it)
			}
		}
		if len(said) == 0 || !strings.Contains(said[len(said)-1].Text, "Couldn't rewind") {
			t.Errorf("%s: no notice: %+v", what, said)
		}
		if c.sid != "s1" || c.record.SessionID != "s1" || len(c.record.Earlier) != 0 || !slices.Contains(c.record.Throwaway, "fork1") {
			t.Errorf("%s: session %s, record %+v", what, c.sid, c.record)
		}
		if got := copied(t, store, c.id); !strings.HasPrefix(got, conversation) {
			t.Errorf("%s: the copy was cut: %s", what, got)
		}
	}
	rewind := func() <-chan error {
		agent.mu.Lock()
		agent.forkGate, agent.entered = make(chan struct{}), make(chan string, 1)
		agent.mu.Unlock()
		done := make(chan error, 1)
		go func() { _, err := svc.Rewind(context.Background(), c.id, two); done <- err }()
		<-agent.entered
		return done
	}

	// The message goes while the fork is made (the agent cut it: a
	// compaction, a replay).
	done := rewind()
	c.mu.Lock()
	kept := slices.Clone(c.items)
	c.items = slices.DeleteFunc(c.items, func(it model.Item) bool { return it.ID == two })
	c.mu.Unlock()
	close(agent.forkGate)
	unchanged("the message gone", <-done, "the message is gone")
	c.mu.Lock()
	c.items = append(kept, c.items[len(kept)-1:]...) // back, with the notice
	c.mu.Unlock()

	// The agent quits mid-fork.
	done = rewind()
	agent.quit()
	eventually(t, c, func() bool { return c.agent == nil })
	close(agent.forkGate)
	unchanged("the agent quit", <-done, "the agent quit")
}

func TestStopTakesBackAnUnansweredMessage(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	ctx := context.Background()
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	idle(t, c)

	agent.updates, agent.gate = nil, make(chan struct{})
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendIdle))
	m, err := svc.Stop(ctx, c.id, true)
	if err != nil || m == nil || m.Text != "two" || len(c.items) != 2 || c.sid != "fork1" {
		t.Fatalf("Stop = %+v, %v; items %+v", m, err, c.items)
	}

	// Answered already: it only stops.
	agent.updates = []acp.SessionUpdate{chunk("m3", "ok")}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "three"}, SendIdle))
	eventually(t, c, func() bool { return len(c.items) == 4 })
	if m, err := svc.Stop(ctx, c.id, true); m != nil || err != nil {
		t.Errorf("Stop after an answer = %+v, %v", m, err)
	}
	idle(t, c)

	// Without rewinding, it stays, with a notice.
	agent.updates, c.forkAt = nil, nil
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "four"}, SendIdle))
	if m, err := svc.Stop(ctx, c.id, true); m == nil || m.Text != "four" || err != nil {
		t.Errorf("Stop = %+v, %v", m, err)
	}
	if last := c.items[len(c.items)-1]; last.Status != "taken_back" || c.items[len(c.items)-3].Text != "four" {
		t.Errorf("items = %+v", c.items)
	}
}

// stopTurn starts a turn the agent holds until it's cancelled (or, with
// ignore, until the test lets it go), and returns the chat once it runs.
func stopTurn(t *testing.T, grace time.Duration, ignore bool) (*Service, *fakeAgent, *chat) {
	t.Helper()
	svc, agent, c := newTimedChat(t, `{"sessionId":"s1"}`, &memModes{}, Timing{StopGrace: grace})
	agent.mu.Lock()
	agent.gate, agent.ignoreCancel = make(chan struct{}), ignore
	agent.mu.Unlock()
	t.Cleanup(agent.release) // before the service closes: a failed test's turn ends
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.started.IsZero() })
	return svc, agent, c
}

// stillRuns says the chat's turn hasn't ended.
func stillRuns(c *chat) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.busyLocked() || !c.started.IsZero()
}

// Stop returns once the stopped turn ended, when the agent obeys at once.
func TestStopWaitsForTheTurnsEnd(t *testing.T) {
	svc, _, c := stopTurn(t, time.Minute, false)
	if _, err := svc.Stop(t.Context(), c.id, false); err != nil {
		t.Fatal(err)
	}
	if stillRuns(c) {
		t.Error("Stop returned before the turn ended")
	}
}

// An agent that takes a while to obey: Stop waits for it, within the
// grace.
func TestStopWaitsForASlowAgent(t *testing.T) {
	svc, agent, c := stopTurn(t, time.Minute, true)
	stopped := make(chan error, 1)
	go func() { _, err := svc.Stop(t.Context(), c.id, false); stopped <- err }()
	testcheck.Wait(t, "the cancel", func() bool {
		agent.mu.Lock()
		defer agent.mu.Unlock()
		return slices.Contains(agent.wire, "cancel")
	})
	select {
	case err := <-stopped:
		t.Fatalf("Stop returned while the turn ran: %v", err)
	default:
	}
	agent.release()
	testcheck.NoErr(t, <-stopped)
	if stillRuns(c) {
		t.Error("Stop returned before the turn ended")
	}
}

// An agent that ignores the stop: Stop returns once the grace is over, as
// before, the turn still running; it ends when the agent ends it.
func TestStopGivesUpOnAnAgentThatIgnoresIt(t *testing.T) {
	svc, agent, c := stopTurn(t, 20*time.Millisecond, true)
	if _, err := svc.Stop(t.Context(), c.id, false); err != nil {
		t.Fatal(err)
	}
	if !stillRuns(c) {
		t.Error("the turn ended while the agent held it")
	}
	agent.release()
	idle(t, c)
}

// lastAsked is the id of the chat's last user message.
func lastAsked(c *chat) string {
	c.mu.Lock()
	defer c.mu.Unlock()
	for _, it := range slices.Backward(c.items) {
		if it.Kind == model.UserMessage {
			return it.ID
		}
	}
	return ""
}

// rewinding begins a Rewind of c to message at that waits as its fork is
// made until the release it returns, which waits for its end: meanwhile
// the chat is busy rewinding, its agent running.
func rewinding(t *testing.T, svc *Service, agent *fakeAgent, c *chat, at string) (release func() error) {
	t.Helper()
	gate := make(chan struct{})
	agent.mu.Lock()
	agent.forkGate, agent.entered = gate, make(chan string, 1)
	agent.mu.Unlock()
	done := make(chan error, 1)
	go func() { _, err := svc.Rewind(context.Background(), c.id, at); done <- err }()
	select {
	case got := <-agent.entered:
		if got != "fork" {
			t.Fatalf("the rewind waits at %s", got)
		}
	case err := <-done:
		close(gate)
		t.Fatalf("the rewind ended before its fork: %v", err)
	}
	return func() error {
		close(gate)
		return <-done
	}
}

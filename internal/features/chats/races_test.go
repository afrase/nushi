package chats

import (
	"context"
	"errors"
	"reflect"
	"slices"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/model"
)

func (f *fakeAgent) onWire() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(f.wire)
}

func TestACancelNeverOvertakesItsPrompt(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate, agent.sendGate = make(chan struct{}), make(chan struct{})
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	if _, err := svc.Stop(context.Background(), c.id, false); err != nil {
		t.Fatal(err)
	}
	close(agent.sendGate) // the prompt is written only now
	eventually(t, c, func() bool { return !c.busy })
	if got := agent.onWire(); !reflect.DeepEqual(got, []string{"prompt one", "cancel"}) {
		t.Errorf("the agent got %q", got)
	}
}

func TestSendNowRechecksTheChatAfterWaiting(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate, agent.ignoreCancel = make(chan struct{}), true
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	now := make(chan error)
	go func() { now <- svc.Prompt(t.Context(), c.id, model.Message{Text: "now"}, SendNow) }()
	archived := make(chan error)
	go func() { archived <- svc.Archive(c.id, true) }()
	eventually(t, c, func() bool { return c.session.Archived && c.stopping })
	agent.release()
	if err := <-now; err == nil {
		t.Error("an archived chat took a message")
	}
	if err := <-archived; err != nil {
		t.Fatal(err)
	}
	if got, _ := agent.texts(); !reflect.DeepEqual(got, []string{"one"}) {
		t.Errorf("prompts = %q", got)
	}
}

func TestArchiveDeliversNothingToTheAgentItStops(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate, agent.ignoreCancel = make(chan struct{}), true
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendQueue))
	archived := make(chan error)
	go func() { archived <- svc.Archive(c.id, true) }()
	eventually(t, c, func() bool { return c.stopping })
	agent.release() // the turn ends on its own, not cancelled
	if err := <-archived; err != nil {
		t.Fatal(err)
	}
	if got, _ := agent.texts(); !reflect.DeepEqual(got, []string{"one"}) {
		t.Errorf("prompts = %q", got)
	}
	c.mu.Lock()
	queued, held := len(c.queue), c.held
	c.mu.Unlock()
	if queued != 1 || !held {
		t.Errorf("the queue after Archive: %d, held %v; want two, held", queued, held)
	}
}

// Unarchived in the same run, a chat's transcript is replayed once, not
// added to the one it had.
func TestUnarchiveReplaysOnce(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "hi")}
	turn(t, svc, c, "one")
	before := texts(c)
	if err := svc.Archive(c.id, true); err != nil {
		t.Fatal(err)
	}
	if err := svc.Archive(c.id, false); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return !c.busy && c.agent != nil })
	if got := texts(c); !reflect.DeepEqual(got, before) {
		t.Errorf("after unarchiving: %q, want %q", got, before)
	}
}

func TestOneSteeringWorkerThatRespectsAStop(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.steerable, c.steer = true, true
	agent.gate, agent.steerGate = make(chan struct{}), make(chan struct{})
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendQueue))
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "three"}, SendQueue))
	toolDone := func(id string) {
		_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call",
			ToolCall: &acp.ToolCall{ToolCallID: acp.ToolCallID(id), Title: "ls", Status: "in_progress"}}})
		_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call_update",
			ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Status: "completed"}}})
	}
	toolDone("t1")
	eventually(t, c, func() bool { return len(c.queue) == 1 }) // "two" is being handed over
	toolDone("t2")                                             // a second chance while the first hand-off waits
	c.mu.Lock()
	queued := len(c.queue)
	c.mu.Unlock()
	if queued != 1 {
		t.Fatalf("a second worker took the queue: %d left", queued)
	}

	// Stopped meanwhile: the turn ends, and the agent no longer takes "two".
	if _, err := svc.Stop(context.Background(), c.id, false); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return !c.busy })
	agent.mu.Lock()
	agent.refuseSteer = true
	agent.mu.Unlock()
	close(agent.steerGate)
	eventually(t, c, func() bool { return !c.steering })
	if got, _ := agent.texts(); !reflect.DeepEqual(got, []string{"one"}) {
		t.Errorf("prompts = %q: a stopped turn started another", got)
	}
	var queue []string
	for _, m := range c.queue {
		queue = append(queue, m.Text)
	}
	if !reflect.DeepEqual(queue, []string{"two", "three"}) {
		t.Errorf("queue = %q", queue)
	}
	if got := texts(c); slices.Contains(got, "user:two") {
		t.Errorf("a message back in the queue is in the transcript too: %q", got)
	}
}

// The daemon stopping cancels a running turn, so the agent ends it (and the
// command it runs) and records it, before the agent is stopped.
func TestCloseEndsTheTurnFirst(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return len(agent.onWire()) == 1 })
	svc.Close()
	if got := agent.onWire(); !reflect.DeepEqual(got, []string{"prompt one", "cancel", "stop"}) {
		t.Errorf("the agent got %q", got)
	}
}

func TestAMessageTooLargeIsRefused(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	big := model.Image{MimeType: "image/png", Data: make([]byte, agentproc.MaxMessage*3/4)}
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "look", Images: []model.Image{big}}, SendIdle); err == nil {
		t.Error("a message past what the agent takes was sent")
	}
	if got, _ := agent.texts(); len(got) > 0 || len(c.items) > 0 {
		t.Errorf("prompts %q, items %v", got, c.items)
	}
}

func TestAFailedDeleteLeavesTheChatAsItWas(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	sessions := svc.sessions.(*memSessions)
	sessions.deleteErr = errors.New("disk full")
	agent.gate, agent.ignoreCancel = make(chan struct{}), true
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	deleted := make(chan error)
	go func() { deleted <- svc.Delete(context.Background(), c.id, nil) }()
	eventually(t, c, func() bool { return c.halting })
	// Saved while it stops.
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "session_info_update",
		SessionInfoUpdate: &acp.SessionInfoUpdate{Title: acp.Nullable[string]{Value: new("Renamed"), Present: true}}}})
	agent.release()
	if err := <-deleted; err == nil {
		t.Fatal("Delete worked")
	}
	sessions.mu.Lock()
	defer sessions.mu.Unlock()
	if slices.ContainsFunc(sessions.saved, func(s model.Session) bool { return s.Archived }) || c.halting {
		t.Errorf("after a failed delete: halting %v, saved %+v", c.halting, sessions.saved)
	}
}

// A SendNow whose agent ignores the cancel gives up with its context, and
// the chat takes messages again: the call doesn't wait for good.
func TestSendNowGivesUpWithItsContext(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate, agent.ignoreCancel = make(chan struct{}), true
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	ctx, cancel := context.WithCancel(t.Context())
	now := make(chan error, 1)
	go func() { now <- svc.Prompt(ctx, c.id, model.Message{Text: "now"}, SendNow) }()
	eventually(t, c, func() bool { return c.sendingNow == 1 })
	cancel()
	select {
	case err := <-now:
		if !errors.Is(err, context.Canceled) {
			t.Errorf("gave up with %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("SendNow waited past its context")
	}
	eventually(t, c, func() bool { return c.sendingNow == 0 })
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
	if got, _ := agent.texts(); !reflect.DeepEqual(got, []string{"one"}) {
		t.Errorf("prompts = %q", got)
	}
}

// Stop with takeBack waits for the stopped turn's end, or for its context.
func TestTakeBackGivesUpWithItsContext(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate, agent.ignoreCancel = make(chan struct{}), true
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.started.IsZero() })
	ctx, cancel := context.WithTimeout(t.Context(), 100*time.Millisecond)
	defer cancel()
	stopped := make(chan error, 1)
	go func() { _, err := svc.Stop(ctx, c.id, true); stopped <- err }()
	select {
	case err := <-stopped:
		if !errors.Is(err, context.DeadlineExceeded) {
			t.Errorf("gave up with %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Stop waited past its context")
	}
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
}

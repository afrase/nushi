package chats

import (
	"context"
	"errors"
	"reflect"
	"slices"
	"testing"

	"github.com/afrase/nushi/acp"
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
	svc.Prompt(c.id, model.Message{Text: "one"}, SendIdle)
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
	svc.Prompt(c.id, model.Message{Text: "one"}, SendIdle)
	now := make(chan error)
	go func() { now <- svc.Prompt(c.id, model.Message{Text: "now"}, SendNow) }()
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
	svc.Prompt(c.id, model.Message{Text: "one"}, SendIdle)
	svc.Prompt(c.id, model.Message{Text: "two"}, SendQueue)
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
}

func TestOneSteeringWorkerThatRespectsAStop(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.steerable, c.steer = true, true
	agent.gate, agent.steerGate = make(chan struct{}), make(chan struct{})
	svc.Prompt(c.id, model.Message{Text: "one"}, SendIdle)
	svc.Prompt(c.id, model.Message{Text: "two"}, SendQueue)
	svc.Prompt(c.id, model.Message{Text: "three"}, SendQueue)
	toolDone := func(id string) {
		c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call",
			ToolCall: &acp.ToolCall{ToolCallID: acp.ToolCallID(id), Title: "ls", Status: "in_progress"}}})
		c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call_update",
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
}

func TestAFailedDeleteLeavesTheChatAsItWas(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	sessions := svc.sessions.(*memSessions)
	sessions.deleteErr = errors.New("disk full")
	agent.gate, agent.ignoreCancel = make(chan struct{}), true
	svc.Prompt(c.id, model.Message{Text: "one"}, SendIdle)
	deleted := make(chan error)
	go func() { deleted <- svc.Delete(context.Background(), c.id, nil) }()
	eventually(t, c, func() bool { return c.halting })
	// Saved while it stops.
	c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "session_info_update",
		SessionInfoUpdate: &acp.SessionInfoUpdate{Title: "Renamed"}}})
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

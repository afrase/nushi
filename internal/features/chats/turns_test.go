package chats

import (
	"context"
	"errors"
	"slices"
	"testing"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// A message the agent answered without words can't be kept by a fork at
// the agent's last words: the message after it can't be rewound to.
func TestRewindNeverDropsAnEarlierMessage(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	turn(t, svc, c, "one")
	agent.updates = []acp.SessionUpdate{{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "ls", Status: "failed"}}}
	turn(t, svc, c, "two")
	agent.updates = nil
	turn(t, svc, c, "three")
	three := c.items[len(c.items)-1]
	if three.ForkAt != "" || three.Rewindable {
		t.Errorf("three: %+v", three)
	}
	if _, err := svc.Rewind(context.Background(), c.id, three.ID); err == nil {
		t.Error("rewound past two")
	}
}

// A message the agent didn't take back goes back to the queue, and out of
// the transcript, wherever it is there.
func TestAFailedSteerTakesTheMessageOut(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.steerable, c.steer = true, true
	agent.gate, agent.steerGate = make(chan struct{}), make(chan struct{})
	svc.Prompt(c.id, model.Message{Text: "one"}, SendIdle)
	svc.Prompt(c.id, model.Message{Text: "two"}, SendQueue)
	c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call",
		ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "ls", Status: "in_progress"}}})
	c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call_update",
		ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "completed"}}})
	eventually(t, c, func() bool { return len(c.queue) == 0 })
	c.SessionUpdate(acp.SessionNotification{SessionID: "s1", Update: chunk("m1", "more")}) // after the steered item
	agent.mu.Lock()
	agent.steerErr = errors.New("Session not found")
	agent.mu.Unlock()
	close(agent.steerGate)
	eventually(t, c, func() bool { return len(c.queue) == 1 })
	if got := texts(c); slices.Contains(got, "user:two") {
		t.Errorf("transcript %q", got)
	}
	agent.release()
}

// A permission prompt in a turn the agent started itself: Stop cancels it,
// and nothing rewinds past it meanwhile.
func TestAPromptInTheAgentsOwnTurn(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	turn(t, svc, c, "one")
	answer := make(chan *acp.RequestPermissionResponse)
	go func() {
		resp, _ := c.RequestPermission(context.Background(), acp.RequestPermissionRequest{SessionID: "s1",
			ToolCall: acp.ToolCallUpdate{ToolCallID: "t9", Title: "rm -rf build"}, Options: []acp.PermissionOption{{OptionID: "yes", Name: "Yes", Kind: "allow_once"}}})
		answer <- resp
	}()
	eventually(t, c, func() bool { return len(c.waiting) == 1 })
	first := c.items[0].ID
	if _, err := svc.Rewind(context.Background(), c.id, first); err == nil {
		t.Error("rewound under a pending prompt")
	}
	if _, err := svc.Stop(context.Background(), c.id, false); err != nil {
		t.Fatal(err)
	}
	if resp := <-answer; resp.Outcome.Outcome != "cancelled" || svc.Status(c.id).Waiting {
		t.Errorf("after Stop: %+v, waiting %v", resp.Outcome, svc.Status(c.id).Waiting)
	}
	if got := agent.onWire(); got[len(got)-1] != "cancel" {
		t.Errorf("the agent got %q", got)
	}
	// Item ids are never reused, cut or not.
	c.mu.Lock()
	c.items = c.items[:1]
	id := c.addLocked(model.Item{Kind: model.Notice})
	c.mu.Unlock()
	if id == "item-2" {
		t.Errorf("a reused id %s", id)
	}
}

package chats

import (
	"context"
	"reflect"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// eventually waits for cond, checked under the chat's lock.
func eventually(t *testing.T, c *chat, cond func() bool) {
	t.Helper()
	for range 200 {
		c.mu.Lock()
		ok := cond()
		c.mu.Unlock()
		if ok {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatal("timed out")
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
	eventually(t, c, func() bool { return len(c.queue) == 1 && c.busy })
	agent.release()
	eventually(t, c, func() bool { return len(c.queue) == 0 && c.busy })
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
	if got, _ := agent.texts(); !reflect.DeepEqual(got, []string{"one", "two", "four"}) {
		t.Errorf("prompts = %q", got)
	}
}

func TestQueueSteersBetweenToolCalls(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.steerable, c.steer = true, true
	agent.gate = make(chan struct{})
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendQueue))
	if _, steered := agent.texts(); len(steered) != 0 {
		t.Fatalf("steered %q before the agent's chance", steered)
	}
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call",
		ToolCall: &acp.ToolCall{ToolCallID: "t1", Title: "ls", Status: "in_progress"}}})
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call_update",
		ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "t1", Status: "completed"}}})
	eventually(t, c, func() bool { return len(c.items) == 3 && c.items[2].Text == "two" })
	eventually(t, c, func() bool { _, steered := agent.texts(); return reflect.DeepEqual(steered, []string{"two"}) })
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
}

func TestSendNowStopsTheTurn(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "held"}, SendQueue))
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "now"}, SendNow); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return c.busy && c.items[len(c.items)-1].Text == "now" })
	if c.items[1].Kind != model.Notice || len(c.queue) != 1 {
		t.Errorf("items = %+v, queue = %+v", c.items, c.queue)
	}
	agent.release()
	eventually(t, c, func() bool { return len(c.queue) == 0 })
	eventually(t, c, func() bool { got, _ := agent.texts(); return reflect.DeepEqual(got, []string{"one", "now", "held"}) })
	agent.release()
	eventually(t, c, func() bool { return !c.busy }) // else Close's cancel could close the gate the release did
}

// A subagent's own step ending isn't the agent's chance: a message steered
// in then would send the subagent's Agent call to the background.
func TestQueueWaitsOutASubagentsSteps(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.steerable, c.steer = true, true
	agent.gate = make(chan struct{})
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "one"}, SendIdle))
	noErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "two"}, SendQueue))
	call := func(id string, meta map[string]any) {
		_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call",
			ToolCall: &acp.ToolCall{ToolCallID: acp.ToolCallID(id), Title: "ls", Status: "in_progress", Meta: meta}}})
		_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call_update",
			ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Status: "completed"}}})
	}
	call("sub1", map[string]any{"claudeCode": map[string]any{"parentToolUseId": "agent1"}})
	time.Sleep(20 * time.Millisecond)
	if _, steered := agent.texts(); len(steered) != 0 || len(c.queue) != 1 {
		t.Fatalf("steered %q after a subagent's step", steered)
	}
	call("t1", nil)
	eventually(t, c, func() bool { _, steered := agent.texts(); return reflect.DeepEqual(steered, []string{"two"}) })
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
}

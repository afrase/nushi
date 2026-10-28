package chats

import (
	"context"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// backgroundSubagent is Claude starting a subagent in the background, as
// a turn's updates: its Agent call (a1), which completes at once.
func backgroundSubagent() []acp.SessionUpdate {
	const id = "a1"
	return []acp.SessionUpdate{
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: acp.ToolCallID(id), Title: "Task", Status: "pending",
			Meta: map[string]any{"claudeCode": map[string]any{"toolName": "Agent"}}, RawInput: []byte(`{"subagent_type":"general-purpose"}`)}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Status: "completed",
			Content: []acp.ToolCallContent{{Type: "content", Content: &acp.Content{
				Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: "Async agent launched successfully.\nagentId: ab59"}}}}}}},
	}
}

// result is Claude's usage report at the end of a model cycle the user
// started (Dialect.TurnDone).
func result() acp.SessionUpdate {
	return acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{Used: 1, Size: 2,
		Cost: &acp.Cost{Amount: 0.1, Currency: "USD"}, Meta: map[string]any{"_claude/origin": map[string]any{"kind": "human"}}}}
}

func update(c *chat, u acp.SessionUpdate) {
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: u})
}

// Claude holds a turn's prompt open while subagents it started in the
// background run; the chat is idle once the turn's own work has ended: a
// message goes at once, as a prompt, and the held prompt's answer changes
// nothing.
func TestABackgroundSubagentLeavesTheChatIdle(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	agent.updates = append(backgroundSubagent(), chunk("m1", "It runs in the background."), result())
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "start one"}, SendIdle); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return !c.busy && c.started.IsZero() })
	if st := c.statusLocked(); st.Busy || !st.Started.IsZero() || st.Background != 1 {
		t.Errorf("status while only the subagent runs: %+v", st)
	}
	if sa := c.itemLocked("a1").Subagent; sa == nil || sa.State != "running" {
		t.Errorf("the subagent: %+v", sa)
	}

	// Its steps are its own, not the agent's working on its own.
	update(c, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "s1", Title: "make test", Status: "in_progress",
		Meta: map[string]any{"claudeCode": map[string]any{"toolName": "Bash", "parentToolUseId": "a1"}}}})
	c.mu.Lock()
	own := c.ownTurn
	c.mu.Unlock()
	if own {
		t.Error("a subagent's step counted as the agent working on its own")
	}
	if err := svc.Move(context.Background(), c.id, t.TempDir(), false); err == nil {
		t.Error("moved the chat, stopping its background subagent")
	}

	agent.updates = []acp.SessionUpdate{chunk("m2", "51")}
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "17 times 3?"}, SendIdle); err != nil {
		t.Fatalf("a message while only the subagent runs: %v", err)
	}
	eventually(t, c, func() bool { prompts, _ := agent.texts(); return len(prompts) == 2 })
	if _, steered := agent.texts(); len(steered) != 0 {
		t.Errorf("steered %q", steered)
	}
	agent.release() // both prompts answered: the held one first
	eventually(t, c, func() bool { return !c.busy && !c.released })
	for _, it := range c.items {
		if it.Kind == model.Notice {
			t.Errorf("a notice: %+v", it)
		}
	}
}

// The result of the work a steered message cut short isn't the turn's
// end: the next one is.
func TestASteeredTurnEndsAtItsLastResult(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	agent.updates = backgroundSubagent()
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "start one"}, SendIdle); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return c.itemLocked("a1") != nil && c.itemLocked("a1").Status == "completed" })
	c.mu.Lock()
	c.steered = 1
	c.mu.Unlock()
	update(c, result())
	c.mu.Lock()
	busy := c.busy
	c.mu.Unlock()
	if !busy {
		t.Fatal("the cut-short work's result ended the turn")
	}
	update(c, result())
	eventually(t, c, func() bool { return !c.busy })
	agent.release()
}

// A result with no subagent left in the background waits for the prompt's
// answer, as any turn.
func TestAResultAloneDoesntEndTheTurn(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	agent.updates = []acp.SessionUpdate{chunk("m1", "done"), result()}
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "hi"}, SendIdle); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return c.itemLocked("m1") != nil })
	c.mu.Lock()
	busy := c.busy
	c.mu.Unlock()
	if !busy {
		t.Error("ended before the prompt's answer")
	}
	agent.release()
	eventually(t, c, func() bool { return !c.busy })
}

// Claude's sessions ask that a stop spare background subagents; a
// subagent stopped with the agent says so.
func TestStoppingTheAgentStopsItsSubagents(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	opts, _ := agent.newMeta["claudeCode"].(map[string]any)["options"].(map[string]any)
	if on, _ := opts["perTaskStopAffordance"].(bool); !on {
		t.Errorf("session/new's _meta: %v", agent.newMeta)
	}
	_, _, err := c.forkSession(context.Background(), agent, "s1", t.TempDir(), map[string]any{"jetbrains": 1})
	if err != nil || agent.forkMeta["claudeCode"] == nil || agent.forkMeta["jetbrains"] != 1 {
		t.Errorf("session/fork's _meta: %v (%v)", agent.forkMeta, err)
	}

	for _, u := range backgroundSubagent() {
		update(c, u)
	}
	if err := svc.Sleep(c.id); err != nil {
		t.Fatal(err)
	}
	if sa := c.itemLocked("a1").Subagent; sa.State != "stopped" || sa.Ended.IsZero() {
		t.Errorf("a background subagent after its chat slept: %+v", sa)
	}
}

// A stopped turn ends with the agent's answer, which says it stopped,
// though its result comes first.
func TestAStoppedTurnWaitsForItsAnswer(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.gate = make(chan struct{})
	agent.ignoreCancel = true
	agent.updates = backgroundSubagent()
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "start one"}, SendIdle); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return c.itemLocked("a1") != nil && c.itemLocked("a1").Status == "completed" })
	go func() { _, _ = svc.Stop(context.Background(), c.id, false) }()
	eventually(t, c, func() bool { return c.stopped })
	update(c, result())
	c.mu.Lock()
	busy := c.busy
	c.mu.Unlock()
	if !busy {
		t.Error("a stopped turn ended at its result")
	}
	agent.mu.Lock()
	agent.cancelled = true
	agent.mu.Unlock()
	agent.release()
	eventually(t, c, func() bool { return !c.busy && c.items[len(c.items)-1].Status == "cancelled" })
}

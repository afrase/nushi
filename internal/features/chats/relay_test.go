package chats

import (
	"context"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/model"
)

func TestMessagesGoToSubagentsThroughTheAgent(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{
		ToolCallID: "a1", Title: "Find it", Status: "completed", Meta: map[string]any{"claudeCode": map[string]any{"toolName": "Agent"}},
		RawInput: []byte(`{"subagent_type":"Explore"}`), Content: []acp.ToolCallContent{{Type: "content", Content: &acp.Content{
			Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: "Async agent launched successfully.\nagentId: ab59"}}}}}}}})
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "and README.md", To: "nope"}, SendQueue); err == nil {
		t.Error("a message for no subagent went")
	}
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "and README.md", To: "a1"}, SendQueue); err != nil {
		t.Fatal(err)
	}
	eventually(t, c, func() bool { return !c.busy })
	got, _ := agent.texts()
	if len(got) != 1 || got[0] != claude.Relay("Explore", "ab59", "and README.md") {
		t.Errorf("prompts = %q", got)
	}
	c.mu.Lock()
	it := c.items[len(c.items)-1]
	c.mu.Unlock()
	if it.Kind != model.UserMessage || it.Text != "and README.md" || it.RelayTo != "Explore" {
		t.Errorf("message = %+v", it)
	}
	// Taken back, it is still for that subagent.
	if m := messageOf(it); m.To != "a1" || m.Relay == nil || m.Relay.Agent != "Explore" {
		t.Errorf("taken back: %+v", m)
	}

	// Replayed, the agent's history holds the whole prompt.
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "user_message_chunk",
		UserMessageChunk: &acp.ContentChunk{MessageID: "u9", Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: got[0]}}}}})
	c.mu.Lock()
	it = c.items[len(c.items)-1]
	c.mu.Unlock()
	if it.RelayTo != "Explore" || strings.Contains(it.Text, "Forward") {
		t.Errorf("replayed = %+v", it)
	}

	// A replayed subagent (no steps, no report) that a message runs again.
	_ = c.SessionUpdate(context.Background(), &acp.SessionNotification{SessionID: "s1", Update: acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{
		ToolCallID: "r1", Title: "head -1 a.go", Kind: "execute", Meta: map[string]any{"claudeCode": map[string]any{"parentToolUseId": "a1"}}}}})
	c.mu.Lock()
	sa := *c.items[0].Subagent
	c.mu.Unlock()
	if sa.State != "running" || sa.Started.IsZero() {
		t.Errorf("run again: %+v", sa)
	}
}

// A message for a subagent follows the agent's call that passes it on: sent,
// then relayed (or failed); one the agent's turn ends without passing on
// fails.
func TestARelayFollowsTheAgentsCall(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	for _, u := range backgroundSubagent() {
		update(c, u)
	}
	sendMessage := func(status string) []acp.SessionUpdate {
		return []acp.SessionUpdate{
			{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "sm1", Title: "SendMessage", Status: "pending",
				Meta: map[string]any{"claudeCode": map[string]any{"toolName": "SendMessage"}}, RawInput: []byte(`{"to":"ab59","message":"and README.md"}`)}},
			{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: "sm1", Status: acp.ToolCallStatus(status)}},
		}
	}
	last := func() model.Item {
		c.mu.Lock()
		defer c.mu.Unlock()
		return c.items[slices.IndexFunc(c.items, func(it model.Item) bool { return it.Kind == model.UserMessage })]
	}
	for _, tc := range []struct {
		calls    []acp.SessionUpdate
		want, by string
	}{
		{sendMessage("completed"), "relayed", "sm1"},
		{sendMessage("failed"), "failed", "sm1"},
		{[]acp.SessionUpdate{chunk("m1", "I'll leave it.")}, "failed", ""},
	} {
		c.mu.Lock()
		c.items = slices.DeleteFunc(c.items, func(it model.Item) bool { return it.Kind != model.ToolCall || it.ID != "a1" })
		c.mu.Unlock()
		agent.updates = tc.calls
		if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "and README.md", To: "a1"}, SendIdle); err != nil {
			t.Fatal(err)
		}
		eventually(t, c, func() bool { return !c.busy })
		if it := last(); it.RelayState != tc.want || it.RelayedBy != tc.by {
			t.Errorf("after %s: %s by %q", tc.calls[len(tc.calls)-1].SessionUpdate, it.RelayState, it.RelayedBy)
		}
	}

	// Replayed, the message names its subagent again.
	update(c, acp.SessionUpdate{SessionUpdate: "user_message_chunk", UserMessageChunk: &acp.ContentChunk{MessageID: "u9",
		Content: acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: claude.Relay("general-purpose", "ab59", "hi")}}}})
	c.mu.Lock()
	it := c.items[len(c.items)-1]
	c.mu.Unlock()
	if it.RelayCall != "a1" || it.RelayState != "" {
		t.Errorf("replayed: %+v", it)
	}
}

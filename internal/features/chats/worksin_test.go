package chats

import (
	"path/filepath"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// worktreeCall is a tool call of Claude's that moves where it works: its
// start, the update that carries its result (none for nil), and its end.
func worktreeCall(id, tool, parent, status string, resp map[string]any) []acp.SessionUpdate {
	meta := func(withResp bool) map[string]any {
		cc := map[string]any{"toolName": tool}
		if parent != "" {
			cc["parentToolUseId"] = parent
		}
		if withResp && resp != nil {
			cc["toolResponse"] = resp
		}
		return map[string]any{"claudeCode": cc}
	}
	return []acp.SessionUpdate{
		{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: acp.ToolCallID(id), Title: tool, Kind: "other", Status: "pending", Meta: meta(false)}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Meta: meta(true)}},
		{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Status: acp.ToolCallStatus(status), Meta: meta(false)}},
	}
}

// A tool call that says where the agent works keeps it on its item, in the
// chat and in its copy (so after a restart): only the main agent's call
// that succeeded, with an absolute path the app can send back as it is,
// or one back in its folder.
func TestTheCallThatEnteredAWorktreeKeepsIt(t *testing.T) {
	svc, agent, c, _ := refChat(t)
	wt := filepath.Join(t.TempDir(), "wt")
	entered := map[string]any{"worktreePath": wt, "worktreeBranch": "worktree-made-up"}
	var updates []acp.SessionUpdate
	for _, call := range [][]acp.SessionUpdate{
		worktreeCall("enter", "EnterWorktree", "", "completed", entered),
		worktreeCall("sub", "EnterWorktree", "agent1", "completed", entered),
		worktreeCall("relative", "EnterWorktree", "", "completed", map[string]any{"worktreePath": "wt", "worktreeBranch": "b"}),
		worktreeCall("bytes", "EnterWorktree", "", "completed", map[string]any{"worktreePath": wt + "\xff", "worktreeBranch": "b"}),
		worktreeCall("failed", "EnterWorktree", "", "failed", entered),
		worktreeCall("refused", "ExitWorktree", "", "failed", nil),
		worktreeCall("exit", "ExitWorktree", "", "completed", map[string]any{"action": "keep"}),
	} {
		updates = append(updates, call...)
	}
	// Claude sending the entry's call again, without its result, keeps it.
	updates = append(updates, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "enter", Title: "EnterWorktree",
		Kind: "other", Status: "completed", Meta: map[string]any{"claudeCode": map[string]any{"toolName": "EnterWorktree"}}}})
	// A call sent again as failed, after the update that carried its
	// result, keeps none.
	updates = append(updates, worktreeCall("late", "EnterWorktree", "", "completed", entered)...)
	updates = append(updates, acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: "late", Title: "EnterWorktree",
		Kind: "other", Status: "failed", Meta: map[string]any{"claudeCode": map[string]any{"toolName": "EnterWorktree"}}}})
	agent.updates = updates
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "go"}, SendIdle))
	idle(t, c)

	want := map[string]*model.AgentWorktree{"enter": {Path: wt}, "exit": {}}
	check := func(from string, items []model.Item) {
		t.Helper()
		for _, id := range []string{"enter", "sub", "relative", "bytes", "failed", "refused", "exit", "late"} {
			i := slices.IndexFunc(items, func(it model.Item) bool { return it.ID == id })
			if i < 0 {
				t.Errorf("%s: no item %s", from, id)
				continue
			}
			got, w := items[i].WorksIn, want[id]
			if (got == nil) != (w == nil) || got != nil && *got != *w {
				t.Errorf("%s: %s's WorksIn = %+v, want %+v", from, id, got, w)
			}
		}
	}
	snap, err := svc.Get(c.id)
	testcheck.NoErr(t, err)
	check("shown", snap.Items)
	copied, err := c.copies.Read(c.id)
	testcheck.NoErr(t, err)
	check("copied", copied)
}

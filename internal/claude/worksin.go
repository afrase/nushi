package claude

import "github.com/afrase/nushi/internal/model"

// WorksIn reads where Claude works once one of its tool calls completes:
// EnterWorktree's result names the worktree it entered (worktreePath),
// and ExitWorktree's, any result, says it is back in the
// session's folder. Both come as the call's _meta.claudeCode.toolResponse,
// on an update before the one that completes it, and only for a call
// that succeeded: a failed one has none (docs/facts/claude.md). The path
// is Claude Code's own tool result, not the model's text.
func (Harness) WorksIn(meta map[string]any) (model.AgentWorktree, bool) {
	cc, _ := meta["claudeCode"].(map[string]any)
	resp, _ := cc["toolResponse"].(map[string]any)
	if resp == nil {
		return model.AgentWorktree{}, false
	}
	switch claudeCode(meta, "toolName") {
	case "EnterWorktree":
		path, _ := resp["worktreePath"].(string)
		return model.AgentWorktree{Path: path}, path != ""
	case "ExitWorktree":
		return model.AgentWorktree{}, true
	}
	return model.AgentWorktree{}, false
}

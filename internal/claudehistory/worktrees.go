package claudehistory

import (
	"path/filepath"

	"github.com/afrase/claude-acp-go/claudeagent/sessions"
)

// SubagentWorktrees says which worktree claude made for each subagent of
// session id in folder's history, by the Agent tool call that started it,
// as the subagents' sidecars say (docs/facts/claude.md). A subagent whose
// worktree went, or that made its own, has none there.
func (l Local) SubagentWorktrees(id, folder string) map[string]string {
	agents, err := sessions.Store{ConfigDir: filepath.Dir(l.Projects)}.Subagents(id, folder)
	if err != nil {
		return nil
	}
	out := map[string]string{}
	for _, a := range agents {
		if a.ParentToolUseID != "" && a.WorktreePath != "" {
			out[a.ParentToolUseID] = a.WorktreePath
		}
	}
	return out
}

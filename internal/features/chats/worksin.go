package chats

import (
	"path/filepath"
	"unicode/utf8"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// worksInLocked keeps on a tool call's item where the agent says it works
// once the call completes (WorkReader): only the main agent's call (a
// subagent's worktree is its own), only one that didn't fail, and only an
// absolute path of valid UTF-8 (mended, it would name another folder;
// docs/security.md). The path isn't checked with git here: it is the agent's
// own tool result, not the model's words, and nothing follows it. The
// item only offers Move chat here, which the user presses and which
// takes the path as any folder the user picks (ADR 0150,
// docs/security.md).
func (c *chat) worksInLocked(it *model.Item, meta map[string]any) {
	if c.kind.workReader == nil || it.Parent != "" {
		return
	}
	if it.Status == string(acp.ToolCallStatusFailed) {
		it.WorksIn = nil
		return
	}
	if to, ok := c.kind.workReader.WorksIn(meta); ok && (to.Path == "" || filepath.IsAbs(to.Path) && utf8.ValidString(to.Path)) {
		it.WorksIn = &to
	}
}

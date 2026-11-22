package chats

import (
	"context"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// A chat's pushed branches (ChatRecord.Pushed): a pull request is found by
// its branch's head only for a branch one of the chat's own tool calls
// pushed. A new chat in a folder whose branch already has a pull request
// doesn't take it (the owner, 2026-11-16: "When opening a new chat it
// shouldn't include any PRs"; ADR 0059's amendment).

// gitPushRE and prCreateRE are what a tool call that pushed or opened a
// pull request ran, read from its lowercased text (callText).
var (
	gitPushRE  = regexp.MustCompile(`\bgit\b[^\n|;&]*\spush\b`)
	prCreateRE = regexp.MustCompile(`\bgh\s+pr\s+create\b`)
)

// callText is a tool call's title, input and tool, lowercased: what
// pushed and opensPull read.
func callText(it model.Item) string {
	return strings.ToLower(it.Title + "\n" + it.Input + "\n" + it.Tool)
}

// opensPull says a tool call's text (callText) opens a pull request: it
// ran gh pr create, or was a create_pull_request tool (GitHub's MCP
// server's). The app's opensPull (pull_link.dart) reads it the same
// way.
func opensPull(what string) bool {
	return prCreateRE.MatchString(what) || strings.Contains(what, "create_pull_request")
}

// pushed says a completed tool call may have pushed the folder's branch:
// it ran git push, or opened a pull request.
func pushed(it model.Item) bool {
	if it.Kind != model.ToolCall || it.Status != "completed" {
		return false
	}
	what := callText(it)
	return gitPushRE.MatchString(what) || opensPull(what)
}

// pushedLocked records the folder's branch as the chat's own once a tool
// call of it pushed, and when (not as a reopen replays it, nor a side
// chat's). It reads the branch with the chat locked, once a push, so the
// ask that follows the push sees it.
//
//nolint:contextcheck // as an agent's update is taken, after the request behind it is gone: the chat's own life bounds it
func (c *chat) pushedLocked(it model.Item) {
	if c.replaying || c.muted || c.parent != nil || c.worktrees == nil || !pushed(it) {
		return
	}
	ctx, cancel := context.WithTimeout(c.svc.ctx, 5*time.Second)
	defer cancel()
	branch := c.worktrees.Branch(ctx, c.record.Folder)
	if branch == "" {
		return
	}
	now := time.Now()
	c.saveLocked(func(s *model.ChatRecord) {
		s.Pushed = slices.Clone(s.Pushed)
		if i := slices.IndexFunc(s.Pushed, func(p model.BranchPush) bool { return p.Branch == branch }); i >= 0 {
			s.Pushed[i].Last = now
			return
		}
		s.Pushed = append(s.Pushed, model.BranchPush{Branch: branch, First: now, Last: now})
		if over := len(s.Pushed) - model.MaxPushed; over > 0 {
			s.Pushed = slices.Delete(s.Pushed, 0, over)
		}
	})
	c.logLocked().Info("branch pushed in the chat")
}

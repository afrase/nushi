package chats

import (
	"context"
	"regexp"
	"strings"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// The agent hears of its worktree's branch renamed (ADR 0016's amendment):
// a rename between turns, Nushi's after the chat's title or the user's
// Rename branch…, goes with the next prompt as a short text block of its
// own before the user's, once; several renames as one, from the name the
// agent last had to the latest; none when it's back to that name. A
// rename before the first prompt is told too: Claude's system prompt
// took git's status, the branch's old name with it, when its session
// started (docs/facts/claude.md). What's pending is the worktree's Told
// against its Branch, kept with the chat.

// toldSuffix ends a "Branch renamed to …" line once the agent was told;
// no-break spaces keep it whole where the line wraps.
const toldSuffix = " ·\u00a0told\u00a0the\u00a0agent"

// branchNote is the note's text; the branch names are its only variable
// part, checked by git first.
func branchNote(from, to string) string {
	return "[Nushi] This worktree's branch was renamed from " + from + " to " + to + ". Use the new name."
}

// noteText matches a note at the start of a user's message as the agent
// replays it (its own text block, or run into the user's text).
var noteText = regexp.MustCompile(`^\[Nushi\] This worktree's branch was renamed from \S+ to \S+\. Use the new name\.\s*`)

// unnoted is a replayed user message's text without the note that went
// before it, and whether it had one.
func unnoted(text string) (string, bool) {
	loc := noteText.FindStringIndex(text)
	if loc == nil {
		return text, false
	}
	return text[loc[1]:], true
}

// told is what a prompt tells the agent of its branch: the name it then
// has, and the notices of the renames its note told of.
type told struct {
	branch  string
	noted   bool     // a note went with it
	notices []string // the renames' lines it told of
}

// branchNoteLocked returns the note for the prompt starting now, if the
// worktree's branch was renamed since the agent's last prompt (nil
// otherwise), and what to record once the prompt went.
//
//nolint:contextcheck // a turn starts on its own, after the request that queued its message
func (c *chat) branchNoteLocked() (*acp.ContentBlock, *told) {
	wt := c.session.Worktree
	if wt == nil || c.parent != nil {
		return nil, nil
	}
	t := &told{branch: wt.Branch}
	if wt.Told == "" || wt.Told == wt.Branch || c.worktrees == nil { // "": a worktree from before Told
		return nil, t
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	for _, name := range []string{wt.Told, wt.Branch} {
		if err := c.worktrees.CheckBranch(ctx, wt.Repo, name); err != nil {
			c.logLocked().Warn("the agent isn't told of its branch renamed", "err", err)
			return nil, t // dropped: the next prompt doesn't try again
		}
	}
	// The renames' lines since the prompt before this one (the user's
	// message for this one is in the transcript already).
	users := 0
	for i := len(c.items) - 1; i >= 0 && users < 2; i-- {
		switch it := c.items[i]; {
		case it.Kind == model.UserMessage && it.Parent == "":
			users++
		case it.Kind == model.Notice && it.Status == "branch_renamed" && !strings.HasSuffix(it.Text, toldSuffix):
			t.notices = append(t.notices, it.ID)
		}
	}
	t.noted = true
	return &acp.ContentBlock{Type: "text", Text: &acp.TextContent{Text: branchNote(wt.Told, wt.Branch)}}, t
}

// toldLocked records that a prompt went to the agent with t: the branch
// as the agent now has it, and its note's renames marked as told.
func (c *chat) toldLocked(t *told) {
	if wt := c.session.Worktree; wt == nil || wt.Branch != t.branch {
		return // moved meanwhile
	}
	c.saveLocked(func(s *model.Session) {
		wt := *s.Worktree // a copy: the session's is shared with the stored one
		wt.Told = t.branch
		s.Worktree = &wt
	})
	if t.noted {
		c.logLocked().Info("the agent was told of its branch renamed", "lines", len(t.notices)) // not the names: they're the chat's title
	}
	for _, id := range t.notices {
		if it := c.itemLocked(id); it != nil {
			it.Text += toldSuffix
			c.publishLocked(*it)
		}
	}
	c.copyLocked(false)
}

// toldBeforeLocked is, for a chat stored before Nushi kept Told, the
// branch as its agent has it: the worktree's (a rename until then was
// never told).
func (c *chat) toldBeforeLocked() {
	if wt := c.session.Worktree; wt != nil && wt.Told == "" {
		w := *wt
		w.Told = w.Branch
		c.session.Worktree = &w
	}
}

// unnotedLocked takes the note of a branch renamed out of a user's
// message the agent replays: it went before the message, not in it.
func (c *chat) unnotedLocked(it *model.Item) bool {
	if it.Kind != model.UserMessage {
		return false
	}
	text, ok := unnoted(it.Text)
	it.Text = text
	return ok
}

package chats

import (
	"context"
	"fmt"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// branchWorktrees has its folders on branch.
type branchWorktrees struct {
	stuckWorktrees
	branch string
}

func (w *branchWorktrees) Branch(context.Context, string) string { return w.branch }

// TestPushed: a completed tool call that ran git push or gh pr create, or
// a create_pull_request tool, pushed; one that didn't, or didn't complete,
// didn't.
func TestPushed(t *testing.T) {
	call := func(input string) model.Item {
		return model.Item{Kind: model.ToolCall, Status: "completed", Input: input}
	}
	for _, it := range []model.Item{
		call(`{"command": "git push -u origin HEAD"}`),
		call(`{"command": "git add . && git commit -m x && git -C /w push"}`),
		call(`{"command": "gh pr create --fill"}`),
		{Kind: model.ToolCall, Status: "completed", Title: "git push"},
		{Kind: model.ToolCall, Status: "completed", Tool: "mcp__github__create_pull_request"},
	} {
		if !pushed(it) {
			t.Errorf("not pushed: %+v", it)
		}
	}
	for _, it := range []model.Item{
		call(`{"command": "git status"}`),
		call(`{"command": "echo pushing"}`),
		call(`{"command": "gh pr view 3"}`),
		{Kind: model.ToolCall, Status: "failed", Input: `{"command": "git push"}`},
		{Kind: model.ToolCall, Status: "in_progress", Input: `{"command": "git push"}`},
		{Kind: model.AgentMessage, Status: "completed", Text: "Run git push next."},
	} {
		if pushed(it) {
			t.Errorf("pushed: %+v", it)
		}
	}
}

// branches are the branches of pushes.
func branches(pushes []model.BranchPush) []string {
	out := []string{}
	for _, p := range pushes {
		out = append(out, p.Branch)
	}
	return out
}

// TestFoundPullOnlyPushed (ADR 0059's amendment of 2026-11-16): a new chat
// on a branch with a pull request links nothing; once a tool call of its
// pushed the branch, that branch's is linked, and not in another chat on
// the same folder that didn't push; it goes when the branch changes and
// comes back with it; a fork keeps the pushed branches and its parent's
// life; a replayed push isn't one.
func TestFoundPullOnlyPushed(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	other, err := svc.Start(t.Context(), "", c.record.Folder, false)
	testcheck.NoErr(t, err)
	wts := &branchWorktrees{branch: "sub"}
	c.mu.Lock()
	c.worktrees = wts
	c.mu.Unlock()
	opened := time.Now().Add(time.Hour)
	all := func(id string) string {
		s, err := svc.Session(id)
		testcheck.NoErr(t, err)
		return fmt.Sprint(numbers(s.AllPulls()))
	}
	found := func(id, branch string, n int) {
		var p *model.ChatGitHub
		if n > 0 {
			l := pullLink(n, branch)
			p = &l
		}
		testcheck.NoErr(t, svc.FoundPull(id, branch, p, opened))
	}
	update := func(u acp.SessionUpdate) {
		testcheck.NoErr(t, c.SessionUpdate(t.Context(), &acp.SessionNotification{SessionID: acp.SessionID(c.sid), Update: u}))
	}
	run := func(id, command string) {
		update(acp.SessionUpdate{SessionUpdate: "tool_call", ToolCall: &acp.ToolCall{ToolCallID: acp.ToolCallID(id), Title: command, Kind: "execute", Status: "pending"}})
		update(acp.SessionUpdate{SessionUpdate: "tool_call_update", ToolCallUpdate: &acp.ToolCallUpdate{ToolCallID: acp.ToolCallID(id), Status: "completed"}})
	}

	found(c.id, "sub", 7)
	run("t1", "git status")
	found(c.id, "sub", 7)
	if got := all(c.id); got != "[]" {
		t.Fatalf("a new chat took its branch's pull request: %s", got)
	}
	c.mu.Lock()
	c.replaying = true
	c.pushedLocked(model.Item{Kind: model.ToolCall, Status: "completed", Title: "git push"})
	c.replaying = false
	c.mu.Unlock()
	found(c.id, "sub", 7)
	if got := all(c.id); got != "[]" {
		t.Fatalf("a replayed push: %s", got)
	}

	run("t2", "git push -u origin sub")
	run("t3", "git push")
	s, _ := svc.Session(c.id)
	if p := s.Pushed; fmt.Sprint(branches(p)) != "[sub]" || p[0].First.IsZero() || p[0].Last.Before(p[0].First) {
		t.Fatalf("pushed: %+v", p)
	}
	found(c.id, "sub", 7)
	found(other, "sub", 7)
	if got, theirs := all(c.id), all(other); got != "[7]" || theirs != "[]" {
		t.Fatalf("after its push: %s; the other chat's: %s", got, theirs)
	}
	found(c.id, "main", 0)
	if got := all(c.id); got != "[]" {
		t.Fatalf("its branch left: %s", got)
	}
	found(c.id, "sub", 7)
	if got := all(c.id); got != "[7]" {
		t.Fatalf("back on its branch: %s", got)
	}

	s, _ = svc.Session(c.id)
	f := forkRecord("f", "s2", s)
	if fmt.Sprint(branches(f.Pushed)) != "[sub]" || fmt.Sprint(numbers(f.AllPulls())) != "[7]" || !f.Since.Equal(s.Created) || !f.Lived(s.Created) {
		t.Fatalf("the fork: %+v", f)
	}
}

// TestFoundPullOthersStay: a found pull request leaves one opened in the
// chat, one linked by hand and the one it was started from as they were,
// and one unlinked isn't found again; a chat remembers its last
// model.MaxPushed branches.
func TestFoundPullOthersStay(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.gitHubHost = func(h string) bool { return h == "github.com" }
	c.mu.Lock()
	c.saveLocked(func(s *model.ChatRecord) { p := pullLink(3, ""); s.GitHub = &p })
	c.openedPullLocked(model.Item{Kind: model.ToolCall, Status: "completed", Input: `{"command": "gh pr create"}`, Text: "https://github.com/a/b/pull/12"})
	c.mu.Unlock()
	testcheck.NoErr(t, svc.AddPull(c.id, pullLink(8, "")))
	testcheck.NoErr(t, svc.FoundPull(c.id, "main", nil, time.Time{}))
	p3 := pullLink(3, "sub")
	testcheck.NoErr(t, svc.FoundPull(c.id, "sub", &p3, time.Time{}))
	if s, _ := svc.Session(c.id); fmt.Sprint(numbers(s.AllPulls())) != "[3 12 8]" {
		t.Fatalf("%v", numbers(s.AllPulls()))
	}

	wts := &branchWorktrees{}
	c.mu.Lock()
	c.worktrees = wts
	for i := range model.MaxPushed + 1 {
		wts.branch = fmt.Sprint("b", i)
		c.pushedLocked(model.Item{Kind: model.ToolCall, Status: "completed", Title: "git push"})
	}
	c.mu.Unlock()
	s, _ := svc.Session(c.id)
	if len(s.Pushed) != model.MaxPushed || s.Pushed[0].Branch != "b1" || s.PushedBranch("b0") {
		t.Fatalf("%v", branches(s.Pushed))
	}
	testcheck.NoErr(t, svc.UnlinkPull(c.id, pullLink(8, "")))
	p8 := pullLink(8, "b5")
	testcheck.NoErr(t, svc.FoundPull(c.id, "b5", &p8, time.Time{}))
	if s, _ := svc.Session(c.id); fmt.Sprint(numbers(s.AllPulls())) != "[3 12]" {
		t.Fatalf("found again once unlinked: %v", numbers(s.AllPulls()))
	}
}

// opensPullRows are tool calls that open a pull request and some that
// don't, in any case and spacing; the app's pull_live_card_test.dart
// keeps the same rows for livePullOf.
var opensPullRows = []struct {
	title, input, tool string
	opens              bool
}{
	{"", `{"command": "gh pr create --fill"}`, "", true},
	{"", `{"command": "gh  pr create --fill"}`, "", true},
	{"GH PR CREATE --fill", "", "", true},
	{"", "", "mcp__github__create_pull_request", true},
	{"Create_Pull_Request", "", "", true},
	{"", `{"name": "create_pull_request"}`, "", true},
	{"", `{"command": "gh pr view 3"}`, "", false},
	{"", `{"command": "gh pr created"}`, "", false},
	{"", `{"command": "gh pr merge 3"}`, "", false},
	{"", `{"command": "echo gh pr"}`, "", false},
}

// TestOpensPull: a completed tool call that opens a pull request, by the
// rows above, links the address in its output and counts as a push; one
// that doesn't, doesn't link.
func TestOpensPull(t *testing.T) {
	known := func(h string) bool { return h == "github.com" }
	for _, r := range opensPullRows {
		it := model.Item{Kind: model.ToolCall, Status: "completed", Title: r.title, Input: r.input, Tool: r.tool,
			Text: "https://github.com/a/b/pull/7"}
		if _, ok := openedPull(it, known); ok != r.opens {
			t.Errorf("openedPull %+v: %v", r, ok)
		}
		if r.opens && !pushed(it) {
			t.Errorf("not pushed: %+v", r)
		}
	}
}

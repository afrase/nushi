package e2e

import (
	"context"
	"path/filepath"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// A worktree a subagent works in shows as the chat's related worktree: an
// event says so when it's found and when it goes, GetRelatedWorktrees
// reads it, and its record stays after it's gone, across a restart.
func TestRelatedWorktrees(t *testing.T) {
	ctx := context.Background()
	repo, history := gitRepo(t), &acptest.History{}
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "start")
	base := testcheck.Git(t, repo, "rev-parse", "HEAD")
	wt := filepath.Join(repo, ".claude", "worktrees", "agent-a1")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "worktree-agent-a1", wt)
	wt = testcheck.Git(t, wt, "rev-parse", "--show-toplevel") // git's path: the temp folder may be a link
	testcheck.Git(t, wt, "commit", "-q", "--allow-empty", "-m", "work")
	head := testcheck.Git(t, wt, "rev-parse", "HEAD")

	data := t.TempDir()
	d := startDaemon(t, data, history, nil)
	a := open(t, d)
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: repo}))).ChatId
	read := func() []*nushiv1.RelatedWorktree {
		t.Helper()
		return must(a.c.GetRelatedWorktrees(ctx, connect.NewRequest(&nushiv1.GetRelatedWorktreesRequest{ChatId: id}))).Worktrees
	}
	if got := read(); len(got) != 0 {
		t.Errorf("before any subagent: %v", got)
	}
	is := func(r *nushiv1.RelatedWorktree, state string) bool {
		return r.Path == wt && r.Branch == "worktree-agent-a1" && r.BaseCommit == base && r.LastHead == head && r.CallId == "a1" && r.State == state
	}
	event := func(state string) *nushiv1.EventsResponse {
		return a.waitFor("related worktrees "+state, func(e *nushiv1.EventsResponse) bool {
			r := e.GetRelatedWorktrees()
			return r != nil && e.ChatId == id && len(r.Worktrees) == 1 && is(r.Worktrees[0], state)
		})
	}
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "subagent ls " + wt})))
	if e := event("present"); e.Seq != 0 {
		t.Errorf("the event has a number: %d", e.Seq)
	}
	settled(ctx, t, a, id)
	if got := read(); len(got) != 1 || !is(got[0], "present") {
		t.Errorf("found: %v", got)
	}

	testcheck.Git(t, repo, "worktree", "remove", wt)
	testcheck.Git(t, repo, "branch", "-D", "worktree-agent-a1")
	if got := read(); len(got) != 1 || !is(got[0], "removed") {
		t.Errorf("removed: %v", got)
	}
	event("removed")

	d.stop()
	a = open(t, startDaemon(t, data, history, nil))
	if got := read(); len(got) != 1 || !is(got[0], "removed") {
		t.Errorf("after a restart: %v", got)
	}
}

// A branch git takes and proto3 doesn't, on a worktree a subagent works
// in, costs the client nothing: GetRelatedWorktrees answers, and the
// Events stream goes on past it, the worktree beside it arriving.
func TestRelatedWorktreeNotUTF8(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	bad := filepath.Join(repo, ".claude", "worktrees", "bad")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "bad", bad)
	testcheck.PutBranch(t, repo, "bad", "bad\xff")
	fine := filepath.Join(repo, ".claude", "worktrees", "fine")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "fine", fine)
	a := open(t, startDaemon(t, t.TempDir(), &acptest.History{}, nil))
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: repo}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "subagent ls " + bad + " " + fine})))
	a.waitFor("the worktree beside it", func(e *nushiv1.EventsResponse) bool {
		r := e.GetRelatedWorktrees()
		return r != nil && len(r.Worktrees) == 1 && r.Worktrees[0].Branch == "fine"
	})
	settled(ctx, t, a, id)
	got := must(a.c.GetRelatedWorktrees(ctx, connect.NewRequest(&nushiv1.GetRelatedWorktreesRequest{ChatId: id}))).Worktrees
	if len(got) != 1 || got[0].Branch != "fine" {
		t.Errorf("read: %v", got)
	}
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "hello"})))
	a.waitFor("a later event", func(e *nushiv1.EventsResponse) bool { return e.ChatId == id && e.GetItem() != nil })
}

// A chat that opens on a found worktree whose branch git takes and proto3
// doesn't still reaches the client: the Events stream goes on past it,
// and the chat just has no worktree to speak of.
func TestFoundWorktreeNotUTF8(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	bad := filepath.Join(repo, ".claude", "worktrees", "bad")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "bad", bad)
	testcheck.PutBranch(t, repo, "bad", "bad\xff")
	a := open(t, startDaemon(t, t.TempDir(), &acptest.History{}, nil))
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: bad}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "hello"})))
	a.waitFor("a later event", func(e *nushiv1.EventsResponse) bool { return e.ChatId == id && e.GetItem() != nil })
	got := must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{})))
	if len(got.Chats) != 1 || got.Chats[0].Worktree != nil {
		t.Errorf("chats: %v", got.Chats)
	}
}

// What the Changes tab reads of a related worktree: its stats while it's
// there, and once it's gone what its commits changed, the commit it left
// from not among them; then, git having dropped them, that they are gone.
func TestRelatedWorktreeStatsAndDiffs(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	testcheck.Write(t, filepath.Join(repo, "main.txt"), "the chat's\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "the chat's")
	base := testcheck.Git(t, repo, "rev-parse", "HEAD")
	wt := filepath.Join(repo, ".claude", "worktrees", "agent-a1")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "worktree-agent-a1", wt)
	wt = testcheck.Git(t, wt, "rev-parse", "--show-toplevel")
	testcheck.Write(t, filepath.Join(wt, "work.txt"), "one\ntwo\n")
	testcheck.Git(t, wt, "add", ".")
	testcheck.Git(t, wt, "commit", "-q", "-m", "work")
	head := testcheck.Git(t, wt, "rev-parse", "HEAD")
	testcheck.Write(t, filepath.Join(wt, "wip.txt"), "wip\n")

	a := open(t, startDaemon(t, t.TempDir(), &acptest.History{}, nil))
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: repo}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "subagent ls " + wt})))
	settled(ctx, t, a, id)
	stats := func(paths ...string) []*nushiv1.RelatedWorktreeStats {
		t.Helper()
		return must(a.c.GetRelatedWorktreeStats(ctx, connect.NewRequest(&nushiv1.GetRelatedWorktreeStatsRequest{ChatId: id, Paths: paths}))).Stats
	}
	look := func() []*nushiv1.RelatedWorktree {
		t.Helper()
		return must(a.c.GetRelatedWorktrees(ctx, connect.NewRequest(&nushiv1.GetRelatedWorktreesRequest{ChatId: id}))).Worktrees
	}
	if got := look(); len(got) != 1 || got[0].State != "present" {
		t.Fatalf("found: %v", got)
	}
	if got := stats(wt, "/not/its/own"); len(got) != 1 || got[0].Files != 2 || got[0].Added != 3 || got[0].Ahead != 1 || got[0].CommitsGone {
		t.Errorf("present: %v", got)
	}

	testcheck.Git(t, repo, "worktree", "remove", "--force", wt)
	testcheck.Git(t, repo, "branch", "-q", "-D", "worktree-agent-a1")
	if got := look(); len(got) != 1 || got[0].State != "removed" || got[0].LastHead != head {
		t.Fatalf("removed: %v", got)
	}
	if got := stats(wt); len(got) != 1 || got[0].Files != 1 || got[0].Added != 2 || got[0].Ahead != 1 || got[0].CommitsGone {
		t.Errorf("removed: %v", got)
	}
	diff := must(a.c.GetDiff(ctx, connect.NewRequest(&nushiv1.GetDiffRequest{Folder: repo, After: base, Commit: head})))
	if len(diff.Files) != 1 || diff.Files[0].Path != "work.txt" {
		t.Errorf("diff: %v", diff.Files)
	}
	commits := must(a.c.ListCommits(ctx, connect.NewRequest(&nushiv1.ListCommitsRequest{Folder: repo, Base: base, Head: head})))
	if len(commits.Commits) != 1 || commits.Commits[0].Hash != head {
		t.Errorf("commits: %v", commits.Commits)
	}

	testcheck.Git(t, repo, "reflog", "expire", "--expire=now", "--all")
	testcheck.Git(t, repo, "gc", "-q", "--prune=now")
	if got := stats(wt); len(got) != 1 || !got[0].CommitsGone || got[0].Files != 0 {
		t.Errorf("collected: %v", got)
	}
}

package e2e

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/claude-acp-go/claudeagent/sessions"

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
	d := startDaemon(t, data, history)
	a := open(t, d)
	id := a.start(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: repo})
	read := func() []*nushiv1.RelatedWorktree {
		t.Helper()
		return must(a.c.GetRelatedWorktrees(ctx, connect.NewRequest(&nushiv1.GetRelatedWorktreesRequest{ChatId: id}))).Worktrees
	}
	if got := read(); len(got) != 0 {
		t.Errorf("before any subagent: %v", got)
	}
	is := func(r *nushiv1.RelatedWorktree, state string) bool {
		return r.Path == wt && r.Branch == "worktree-agent-a1" && r.BaseCommit == base && r.LastHead == head && r.CallId == "a1" && r.RunId == "" && r.State == state
	}
	event := func(state string) *nushiv1.EventsResponse {
		return a.waitFor("related worktrees "+state, func(e *nushiv1.EventsResponse) bool {
			r := e.GetRelatedWorktrees()
			return r != nil && e.ChatId == id && len(r.Worktrees) == 1 && is(r.Worktrees[0], state)
		})
	}
	a.send(id, "subagent ls "+wt)
	if e := event("present"); e.Seq != 0 {
		t.Errorf("the event has a number: %d", e.Seq)
	}
	a.settled(id)
	if got := read(); len(got) != 1 || !is(got[0], "present") {
		t.Errorf("found: %v", got)
	}

	testcheck.Git(t, repo, "worktree", "remove", wt)
	testcheck.Git(t, repo, "branch", "-D", "worktree-agent-a1")
	if got := read(); len(got) != 1 || !is(got[0], "removed") {
		t.Errorf("removed: %v", got)
	}
	event("removed")

	a = d.reopen(t)
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
	a := open(t, startDaemon(t, t.TempDir(), &acptest.History{}))
	id := a.start(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: repo})
	a.send(id, "subagent ls "+bad+" "+fine)
	a.waitFor("the worktree beside it", func(e *nushiv1.EventsResponse) bool {
		r := e.GetRelatedWorktrees()
		return r != nil && len(r.Worktrees) == 1 && r.Worktrees[0].Branch == "fine"
	})
	a.settled(id)
	got := must(a.c.GetRelatedWorktrees(ctx, connect.NewRequest(&nushiv1.GetRelatedWorktreesRequest{ChatId: id}))).Worktrees
	if len(got) != 1 || got[0].Branch != "fine" {
		t.Errorf("read: %v", got)
	}
	a.send(id, "hello")
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
	a := open(t, startDaemon(t, t.TempDir(), &acptest.History{}))
	id := a.start(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: bad})
	a.send(id, "hello")
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

	a := open(t, startDaemon(t, t.TempDir(), &acptest.History{}))
	id := a.start(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: repo})
	a.send(id, "subagent ls "+wt)
	a.settled(id)
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

// A path with two records (a worktree removed, and another made there on
// another branch since: issue #118) has a stat for each, in the list's
// order, which is what the app pairs them by: the removed one's from its
// commits, the new one's from its folder.
func TestRelatedWorktreeStatsOfOnePath(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "start")
	wt := filepath.Join(repo, ".claude", "worktrees", "feature-x")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-x", wt)
	wt = testcheck.Git(t, wt, "rev-parse", "--show-toplevel")
	testcheck.Write(t, filepath.Join(wt, "old.txt"), "one\n")
	testcheck.Git(t, wt, "add", ".")
	testcheck.Git(t, wt, "commit", "-q", "-m", "old work")

	a := open(t, startDaemon(t, t.TempDir(), &acptest.History{}))
	id := a.start(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: repo})
	look := func() []*nushiv1.RelatedWorktree {
		t.Helper()
		return must(a.c.GetRelatedWorktrees(ctx, connect.NewRequest(&nushiv1.GetRelatedWorktreesRequest{ChatId: id}))).Worktrees
	}
	a.send(id, "subagent ls "+wt)
	a.settled(id)
	if got := look(); len(got) != 1 || got[0].State != "present" {
		t.Fatalf("found: %v", got)
	}
	testcheck.Git(t, repo, "worktree", "remove", wt)
	if got := look(); len(got) != 1 || got[0].State != "removed" {
		t.Fatalf("removed: %v", got)
	}
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "feature-y", wt, "main")
	for _, name := range []string{"a.txt", "b.txt", "c.txt"} {
		testcheck.Write(t, filepath.Join(wt, name), "new\n")
	}
	a.send(id, "subagent call=b1 ls "+wt)
	a.settled(id)
	if got := look(); len(got) != 2 || got[0].CallId != "a1" || got[1].CallId != "b1" || got[1].State != "present" {
		t.Fatalf("made again: %v", got)
	}
	got := must(a.c.GetRelatedWorktreeStats(ctx, connect.NewRequest(&nushiv1.GetRelatedWorktreeStatsRequest{ChatId: id, Paths: []string{wt}}))).Stats
	if len(got) != 2 || got[0].Files != 1 || got[0].Ahead != 1 || got[1].Files != 3 || got[1].Ahead != 0 {
		t.Errorf("stats: %v; want the removed one's (1 file, 1 ahead), then the new one's (3 files)", got)
	}
}

// A worktree a workflow's subagents work in is the chat's related
// worktree too, the Workflow call's with its run's id: one a subagent's
// .meta.json says Claude gave it, and one another wrote a file in. The
// related_worktrees event says so when the run's files bring them; a
// subagent's record has no run id.
func TestRelatedWorktreesOfAWorkflow(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	given := filepath.Join(repo, ".claude", "worktrees", runID+"-1")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "worktree-"+runID+"-1", given)
	export := filepath.Join(filepath.Dir(repo), filepath.Base(repo)+"-export")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "export", export)
	t.Cleanup(func() { _ = os.RemoveAll(export) })

	data := t.TempDir()
	a := open(t, startDaemon(t, data, &acptest.History{}))
	id := a.start(&nushiv1.StartChatRequest{Agent: "claude-fake", Folder: repo})
	session := filepath.Join(sessions.Store{ConfigDir: filepath.Join(data, "claude")}.ProjectDir(repo), a.get(id).Chat.SessionId)
	testcheck.NoErr(t, os.CopyFS(session, os.DirFS(recordedRun)))
	run := filepath.Join(session, "subagents", "workflows", runID)
	// map:beta was given a worktree; map:alpha writes a file in another,
	// beside the chat's folder.
	testcheck.Write(t, filepath.Join(run, "agent-a5f5ee54570c1d136.meta.json"),
		`{"agentType":"workflow-subagent","description":"map:beta","inWorkflowRun":true,"spawnedWithWorktree":true,"worktreePath":`+strconv.Quote(given)+`}`)
	f, err := os.OpenFile(filepath.Join(run, "agent-"+alphaID+".jsonl"), os.O_APPEND|os.O_WRONLY, 0)
	testcheck.NoErr(t, err)
	_, err = fmt.Fprintf(f, `{"type":"assistant","timestamp":"2026-11-16T03:07:17.000Z","message":{"role":"assistant","content":[`+
		`{"type":"tool_use","id":"toolu_x1","name":"Write","input":{"file_path":%q,"content":"x"}}]}}`+"\n"+
		`{"type":"user","timestamp":"2026-11-16T03:07:18.000Z","message":{"role":"user","content":[`+
		`{"type":"tool_result","tool_use_id":"toolu_x1","content":"ok"}]}}`+"\n", filepath.Join(export, "export.go"))
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, f.Close())

	a.send(id, "launch the workflow")
	is := func(r *nushiv1.RelatedWorktree, path, branch string) bool {
		return r.Path == path && r.Branch == branch && r.CallId == "wf1" && r.RunId == runID && r.State == "present"
	}
	both := func(list []*nushiv1.RelatedWorktree) bool {
		return len(list) == 2 && slices.ContainsFunc(list, func(r *nushiv1.RelatedWorktree) bool { return is(r, given, "worktree-"+runID+"-1") }) &&
			slices.ContainsFunc(list, func(r *nushiv1.RelatedWorktree) bool { return is(r, export, "export") })
	}
	a.waitFor("the run's related worktrees", func(e *nushiv1.EventsResponse) bool {
		r := e.GetRelatedWorktrees()
		return r != nil && e.ChatId == id && both(r.Worktrees)
	})
	if got := must(a.c.GetRelatedWorktrees(ctx, connect.NewRequest(&nushiv1.GetRelatedWorktreesRequest{ChatId: id}))).Worktrees; !both(got) {
		t.Errorf("read: %v", got)
	}
}

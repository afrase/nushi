package e2e

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// Cleaning up after a pull request, on a temporary repository: a clean
// worktree, a dirty one (refused without force), its branch in use, another
// chat in the worktree, a turn running, and a branch gone already.
func TestCleanUp(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	start := func(folder string, worktree bool) (string, *nushiv1.Worktree) {
		id := a.start(&nushiv1.StartChatRequest{Folder: folder, Worktree: worktree})
		a.send(id, "pwd")
		return id, a.settled(id).Chat.Worktree
	}
	cleanUp := func(id string) *nushiv1.GetCleanUpResponse {
		return must(a.c.GetCleanUp(ctx, connect.NewRequest(&nushiv1.GetCleanUpRequest{ChatId: id})))
	}
	remove := func(id string, force bool) error {
		_, err := a.c.RemoveChatWorktree(ctx, connect.NewRequest(&nushiv1.RemoveChatWorktreeRequest{ChatId: id, Force: force}))
		return err
	}
	deleteBranch := func(id string, force bool) error {
		_, err := a.c.DeleteChatBranch(ctx, connect.NewRequest(&nushiv1.DeleteChatBranchRequest{ChatId: id, Force: force}))
		return err
	}
	refused := func(what string, err error, says string) {
		t.Helper()
		if err == nil || !strings.Contains(err.Error(), says) {
			t.Fatalf("%s: %v, want %q", what, err, says)
		}
	}

	// A chat outside a worktree has nothing of the kind.
	plain, _ := start(repo, false)
	if u := cleanUp(plain); u.Worktree != nil {
		t.Fatalf("a chat without a worktree: %v", u)
	}
	refused("no worktree", remove(plain, false), "no worktree")

	// Clean: nothing lost.
	id, wt := start(repo, true)
	if u := cleanUp(id); u.Worktree.GetPath() != wt.Path || u.State.Changed != 0 || u.State.Commits != 0 || u.BranchElsewhere {
		t.Fatalf("clean: %v", u)
	}

	// Dirty: listed, and refused without force.
	if err := os.WriteFile(filepath.Join(wt.Path, "notes.txt"), []byte("mine\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if u := cleanUp(id); u.State.Changed != 1 || !slices.Equal(u.Changes, []string{"?? notes.txt"}) {
		t.Fatalf("dirty: %v", u)
	}
	refused("dirty", remove(id, false), "1 uncommitted changes")

	// Its branch: the worktree still has it checked out.
	refused("the branch in use", deleteBranch(id, false), "still has")

	// Another chat working in the worktree.
	other, _ := start(wt.Path, false)
	if u := cleanUp(id); len(u.Others) != 1 {
		t.Fatalf("another chat: %v", u)
	}
	if p := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id}))); len(p.Worktrees) != 1 || len(p.Worktrees[0].Others) != 1 {
		t.Fatalf("deleting, another chat: %v", p.Worktrees)
	}
	refused("another chat", remove(id, true), "works in this worktree too")
	must(a.c.ArchiveChat(ctx, connect.NewRequest(&nushiv1.ArchiveChatRequest{ChatId: other, Archived: true})))

	// A turn running.
	a.send(id, "wait")
	until(t, "the turn", func() bool {
		return a.get(id).Status.Busy
	})
	refused("mid-turn", remove(id, true), "working")
	must(a.c.CancelTurn(ctx, connect.NewRequest(&nushiv1.CancelTurnRequest{ChatId: id})))
	a.settled(id)

	// A commit on the branch, then the worktree forced away, changes and
	// all; the branch then goes only with force (a squash merge's).
	testcheck.Git(t, wt.Path, "commit", "-q", "--allow-empty", "-m", "work")
	if err := remove(id, true); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(wt.Path); !errors.Is(err, fs.ErrNotExist) {
		t.Fatalf("the worktree is still there: %v", err)
	}
	refused("commits", deleteBranch(id, false), "1 commits")
	if err := deleteBranch(id, true); err != nil || branchExists(repo, wt.Branch) {
		t.Fatalf("the branch: %v, there %v", err, branchExists(repo, wt.Branch))
	}
	// Gone already: nothing to do.
	if err := deleteBranch(id, false); err != nil {
		t.Fatal(err)
	}

	// Another worktree has the branch: refused.
	id3, wt3 := start(repo, true)
	if err := remove(id3, false); err != nil {
		t.Fatal(err)
	}
	testcheck.Git(t, repo, "worktree", "add", "-q", filepath.Join(t.TempDir(), "elsewhere"), wt3.Branch)
	if u := cleanUp(id3); !u.BranchElsewhere {
		t.Fatalf("elsewhere: %v", u)
	}
	refused("elsewhere", deleteBranch(id3, true), "another worktree")
}

// Ignored files (.env, build/) are lost with a worktree, and git's own
// status doesn't count them, so both ways of removing one refuse them
// without force, as for uncommitted changes: Delete and Clean up, each
// leaving the file where it was, then removing it once forced.
func TestIgnoredFilesNeedForce(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	testcheck.Write(t, filepath.Join(repo, ".gitignore"), ".env\n")
	testcheck.Git(t, repo, "add", ".gitignore")
	testcheck.Git(t, repo, "commit", "-q", "-m", "ignore .env")
	d := startDaemon(t, t.TempDir(), &acptest.History{})
	a := open(t, d)
	withSecret := func() (string, *nushiv1.Worktree, string) {
		id := a.start(&nushiv1.StartChatRequest{Folder: repo, Worktree: true})
		a.send(id, "pwd")
		wt := a.settled(id).Chat.Worktree
		env := filepath.Join(wt.Path, ".env")
		testcheck.Write(t, env, "TOKEN=mine\n")
		return id, wt, env
	}
	kept := func(what string, err error, env string) {
		t.Helper()
		if err == nil || !strings.Contains(err.Error(), "1 ignored") {
			t.Errorf("%s: %v, want a refusal naming the ignored file", what, err)
		}
		if _, err := os.Stat(env); err != nil {
			t.Fatalf("%s lost .env: %v", what, err)
		}
	}
	gone := func(what string, err error, wt *nushiv1.Worktree) {
		t.Helper()
		if _, serr := os.Stat(wt.Path); err != nil || !errors.Is(serr, fs.ErrNotExist) {
			t.Fatalf("%s, forced: %v, the worktree %v", what, err, serr)
		}
	}

	id, wt, env := withSecret()
	if p := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id}))); p.Worktrees[0].State.Ignored != 1 || p.Worktrees[0].State.Changed != 0 {
		t.Fatalf("plan: %v", p.Worktrees[0].State)
	}
	del := func(force bool) error {
		_, err := a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: id, Worktrees: []*nushiv1.WorktreeChoice{
			{Path: wt.Path, RemoveWorktree: true, ForceWorktree: force}}}))
		return err
	}
	kept("Delete", del(false), env)
	gone("Delete", del(true), wt)

	id, wt, env = withSecret()
	if u := must(a.c.GetCleanUp(ctx, connect.NewRequest(&nushiv1.GetCleanUpRequest{ChatId: id}))); u.State.Ignored != 1 || u.State.Changed != 0 {
		t.Fatalf("clean-up: %v", u.State)
	}
	remove := func(force bool) error {
		_, err := a.c.RemoveChatWorktree(ctx, connect.NewRequest(&nushiv1.RemoveChatWorktreeRequest{ChatId: id, Force: force}))
		return err
	}
	kept("Clean up", remove(false), env)
	gone("Clean up", remove(true), wt)
}

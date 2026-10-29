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
)

// Cleaning up after a pull request, on a temporary repository: a clean
// worktree, a dirty one (refused without force), its branch in use, another
// chat in the worktree, a turn running, and a branch gone already.
func TestCleanUp(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	start := func(folder string, worktree bool) (string, *nushiv1.Worktree) {
		id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: folder, Worktree: worktree}))).ChatId
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "pwd"})))
		return id, settled(ctx, t, a, id).Chat.Worktree
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
	refused("another chat", remove(id, true), "works in this worktree too")
	must(a.c.ArchiveChat(ctx, connect.NewRequest(&nushiv1.ArchiveChatRequest{ChatId: other, Archived: true})))

	// A turn running.
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "wait"})))
	until(t, "the turn", func() bool {
		return must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Status.Busy
	})
	refused("mid-turn", remove(id, true), "working")
	must(a.c.CancelTurn(ctx, connect.NewRequest(&nushiv1.CancelTurnRequest{ChatId: id})))
	settled(ctx, t, a, id)

	// A commit on the branch, then the worktree forced away, changes and
	// all; the branch then goes only with force (a squash merge's).
	gitIn(t, wt.Path, "commit", "-q", "--allow-empty", "-m", "work")
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
	gitIn(t, repo, "worktree", "add", "-q", filepath.Join(t.TempDir(), "elsewhere"), wt3.Branch)
	if u := cleanUp(id3); !u.BranchElsewhere {
		t.Fatalf("elsewhere: %v", u)
	}
	refused("elsewhere", deleteBranch(id3, true), "another worktree")
}

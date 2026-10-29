package git

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestWorktreeListBranchesAndSwitch(t *testing.T) {
	ctx := context.Background()
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "sub", "a.txt"), "a\n")
	testcheck.Git(t, repo, "add", ".")
	t.Setenv("GIT_COMMITTER_DATE", "2001-01-01T00:00:00")
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")
	testcheck.Git(t, repo, "branch", "old")
	t.Setenv("GIT_COMMITTER_DATE", "2030-01-01T00:00:00")
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "later")
	w := Worktrees{}
	try := filepath.Join(repo, ".worktrees", "try")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "try", try)
	locked := filepath.Join(t.TempDir(), "locked")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "kept", locked)
	testcheck.Git(t, repo, "worktree", "lock", locked)
	gone := filepath.Join(t.TempDir(), "gone")
	testcheck.Git(t, repo, "worktree", "add", "-q", "--detach", gone)
	testcheck.NoErr(t, os.RemoveAll(gone))

	// The list: the main worktree first, the one the folder is in current
	// (inside the repository's folder, a worktree is its own), a locked one
	// marked, one whose folder is gone left out.
	list, err := w.List(ctx, filepath.Join(try, "sub"))
	lockedReal, _ := filepath.EvalSymlinks(locked)
	want := []model.WorktreeEntry{
		{Path: repo, Branch: "main", Main: true},
		{Path: try, Branch: "try", Current: true},
		{Path: lockedReal, Branch: "kept", Locked: true},
	}
	for i := range list {
		list[i].Head = ""
	}
	if err != nil || !slices.Equal(list, want) {
		t.Fatalf("List = %+v, %v", list, err)
	}
	if !Same(list, repo, filepath.Join(repo, "sub")) || Same(list, repo, try) {
		t.Error("Same")
	}
	if _, err := w.List(ctx, t.TempDir()); !errors.Is(err, ErrNotRepository) {
		t.Errorf("outside git: %v", err)
	}

	// Found: a worktree that isn't the repository's own folder.
	if wt := w.Found(ctx, filepath.Join(try, "sub")); wt == nil || wt.Path != try || wt.Repo != repo || wt.Branch != "try" || !wt.Found || wt.Base != "main" {
		t.Errorf("Found = %+v", wt)
	}
	if wt := w.Found(ctx, repo); wt != nil {
		t.Errorf("Found in the repository's folder = %+v", wt)
	}

	// Branches, the newest commit first, each with its worktree.
	branches, err := Branches(ctx, repo, 10)
	if err != nil || len(branches) != 4 || branches[3].Name != "old" || branches[3].Worktree != "" {
		t.Fatalf("Branches = %+v, %v", branches, err)
	}
	at := map[string]string{}
	for _, b := range branches {
		at[b.Name] = b.Worktree
	}
	if at["main"] != repo || at["try"] != try || at["kept"] != lockedReal {
		t.Errorf("their worktrees: %v", at)
	}

	// Switch: a change to a tracked file is counted (untracked files aren't).
	write(t, filepath.Join(repo, "new.txt"), "untracked\n")
	if n, err := w.Changed(ctx, repo); n != 0 || err != nil {
		t.Errorf("Changed with an untracked file = %d, %v", n, err)
	}
	write(t, filepath.Join(repo, "sub", "a.txt"), "changed\n")
	if n, err := w.Changed(ctx, repo); n != 1 || err != nil {
		t.Errorf("Changed = %d, %v", n, err)
	}
	testcheck.Git(t, repo, "checkout", "--", "sub/a.txt")
	if err := w.Switch(ctx, repo, "old", false); err != nil || w.Branch(ctx, repo) != "old" {
		t.Fatalf("Switch = %v, on %s", err, w.Branch(ctx, repo))
	}
	if err := w.Switch(ctx, repo, "nope", false); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("a branch that isn't there: %v", err)
	}
	if err := w.Switch(ctx, repo, "main", true); !errors.Is(err, fs.ErrExist) {
		t.Errorf("a new branch whose name is taken: %v", err)
	}
	if err := w.Switch(ctx, repo, "-f", false); err == nil {
		t.Error("an option for a name")
	}
	if err := w.Switch(ctx, repo, "me/new", true); err != nil || w.Branch(ctx, repo) != "me/new" {
		t.Errorf("a new branch: %v, on %s", err, w.Branch(ctx, repo))
	}
	// Git's own refusal reads as a sentence: try is checked out elsewhere.
	if err := w.Switch(ctx, repo, "try", false); err == nil || err.Error() == "" || errors.Is(err, fs.ErrNotExist) {
		t.Errorf("a branch in another worktree: %v", err)
	}
}

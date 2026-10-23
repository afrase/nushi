package git

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

func TestWorktrees(t *testing.T) {
	ctx := context.Background()
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "sub", "a.txt"), "a\n")
	git(t, repo, "add", ".")
	git(t, repo, "commit", "-q", "-m", "init")

	wt, folder, err := Worktrees{}.Add(ctx, filepath.Join(repo, "sub"), "brave-otter")
	want := model.Worktree{Repo: repo, Path: filepath.Join(repo, ".worktrees", "brave-otter"), Branch: "nushi/brave-otter", Base: "main"}
	if err != nil || wt != want || folder != filepath.Join(want.Path, "sub") {
		t.Fatalf("Add = %+v, %q, %v; want %+v", wt, folder, err, want)
	}
	if b, err := os.ReadFile(filepath.Join(folder, "a.txt")); err != nil || string(b) != "a\n" {
		t.Errorf("the worktree's file: %q, %v", b, err)
	}
	// From inside the worktree, the next one still goes beside it, and
	// .worktrees/ is excluded once.
	if _, _, err := (Worktrees{}).Add(ctx, folder, "brave-otter"); !errors.Is(err, fs.ErrExist) {
		t.Errorf("a taken name: %v", err)
	}
	second, _, err := Worktrees{}.Add(ctx, folder, "calm-heron")
	if err != nil || second.Path != filepath.Join(repo, ".worktrees", "calm-heron") || second.Base != "nushi/brave-otter" {
		t.Fatalf("Add from the worktree = %+v, %v", second, err)
	}
	if b, _ := os.ReadFile(filepath.Join(repo, ".git", "info", "exclude")); strings.Count(string(b), "/.worktrees/") != 1 {
		t.Errorf("info/exclude:\n%s", b)
	}
	if st, _ := Status(ctx, repo, ""); st.Files != 0 {
		t.Errorf("the worktrees show as changes in the repository: %+v", st)
	}

	// Inspect counts what would be lost: changed files, and commits the
	// base doesn't have.
	write(t, filepath.Join(second.Path, "new.txt"), "work\n")
	write(t, filepath.Join(second.Path, "sub", "a.txt"), "b\n")
	git(t, second.Path, "commit", "-q", "-am", "one")
	write(t, filepath.Join(second.Path, "sub", "a.txt"), "c\n")
	if st, err := (Worktrees{}).Inspect(ctx, second); err != nil || st != (model.WorktreeState{Changed: 2, Commits: 1}) {
		t.Errorf("Inspect = %+v, %v", st, err)
	}
	if err := (Worktrees{}).Remove(ctx, second, false); err == nil {
		t.Error("a worktree with changes was removed without force")
	}
	if err := (Worktrees{}).Remove(ctx, second, true); err != nil {
		t.Fatal(err)
	}
	if st, err := (Worktrees{}).Inspect(ctx, second); err != nil || st != (model.WorktreeState{Gone: true, Commits: 1}) {
		t.Errorf("Inspect after removing = %+v, %v", st, err)
	}
	if err := (Worktrees{}).DeleteBranch(ctx, second); err != nil {
		t.Fatal(err)
	}
	if st, err := (Worktrees{}).Inspect(ctx, second); err != nil || st != (model.WorktreeState{Gone: true, BranchGone: true}) {
		t.Errorf("Inspect after deleting the branch = %+v, %v", st, err)
	}
	// A worktree whose folder went outside git: removing clears git's record.
	os.RemoveAll(wt.Path)
	if err := (Worktrees{}).Remove(ctx, wt, false); err != nil {
		t.Errorf("removing a worktree whose folder is gone: %v", err)
	}
}

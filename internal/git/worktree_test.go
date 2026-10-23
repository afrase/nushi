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
	if st, _ := Status(ctx, repo); st.Files != 0 {
		t.Errorf("the worktrees show as changes in the repository: %+v", st)
	}

	// Remove leaves a worktree with work in it.
	write(t, filepath.Join(second.Path, "new.txt"), "work\n")
	if err := (Worktrees{}).Remove(ctx, second); err == nil {
		t.Error("a worktree with an untracked file was removed")
	}
	if err := (Worktrees{}).Remove(ctx, wt); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(wt.Path); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("the worktree is still there: %v", err)
	}
	if _, err := run(ctx, repo, "rev-parse", "--verify", "-q", "refs/heads/"+wt.Branch); err == nil {
		t.Error("the branch is still there")
	}
}

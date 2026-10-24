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
	want.BaseCommit = wt.BaseCommit
	if err != nil || len(wt.BaseCommit) != 40 || wt != want || folder != filepath.Join(want.Path, "sub") {
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
	// A name is taken by its folder alone, or by its branch alone (a
	// deleted chat can leave its branch).
	os.MkdirAll(filepath.Join(repo, ".worktrees", "lone-folder"), 0o755)
	git(t, repo, "branch", "nushi/lone-branch")
	for _, name := range []string{"lone-folder", "lone-branch"} {
		if _, _, err := (Worktrees{}).Add(ctx, repo, name); !errors.Is(err, fs.ErrExist) {
			t.Errorf("%s: %v", name, err)
		}
	}
	// Through a link to the repository, the worktree keeps the link's spelling.
	link := filepath.Join(t.TempDir(), "link")
	os.Symlink(repo, link)
	if via, in, err := (Worktrees{}).Add(ctx, filepath.Join(link, "sub"), "swift-yak"); err != nil || via.Repo != link || in != filepath.Join(link, ".worktrees", "swift-yak", "sub") {
		t.Errorf("Add through a link = %+v, %q, %v", via, in, err)
	}
	second, _, err := Worktrees{}.Add(ctx, folder, "calm-heron")
	if err != nil || second.Path != filepath.Join(repo, ".worktrees", "calm-heron") || second.Base != "nushi/brave-otter" || second.BaseCommit != wt.BaseCommit {
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
	// Ignored files go with the worktree too.
	write(t, filepath.Join(second.Path, ".gitignore"), ".env\nbuild/\n")
	write(t, filepath.Join(second.Path, ".env"), "SECRET=1\n")
	write(t, filepath.Join(second.Path, "build", "out.o"), "o")
	if st, err := (Worktrees{}).Inspect(ctx, second); err != nil || st != (model.WorktreeState{Changed: 3, Ignored: 2, Commits: 1}) {
		t.Errorf("Inspect = %+v, %v", st, err)
	}
	// Its base branch deleted (merged, say): counted from where it started.
	git(t, repo, "update-ref", "-d", "refs/heads/nushi/brave-otter")
	if n, err := (Worktrees{}).Inspect(ctx, second); err != nil || n.Commits != 1 {
		t.Errorf("Inspect with its base gone = %+v, %v", n, err)
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
	// A worktree whose folder went outside git: removing clears git's record
	// of it, not of another missing one (the user's, on a volume not mounted).
	theirs := filepath.Join(t.TempDir(), "theirs")
	git(t, repo, "worktree", "add", "-q", theirs)
	os.RemoveAll(theirs)
	os.RemoveAll(wt.Path)
	for range 2 { // and again: nothing left to remove is no error
		if err := (Worktrees{}).Remove(ctx, wt, false); err != nil {
			t.Errorf("removing a worktree whose folder is gone: %v", err)
		}
	}
	if out, _ := run(ctx, repo, "worktree", "list"); strings.Contains(string(out), "brave-otter") || !strings.Contains(string(out), "theirs") {
		t.Errorf("worktrees left:\n%s", out)
	}
}

// A repository can bring links where Nushi writes: .worktrees, and its
// info/exclude or info folder. Nushi writes through none of them.
func TestNoWritesThroughARepositorysLinks(t *testing.T) {
	ctx := context.Background()
	repo, elsewhere := t.TempDir(), t.TempDir()
	git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "SKILL.md"), "evil\n")
	git(t, repo, "add", ".")
	git(t, repo, "commit", "-q", "-m", "init")
	os.Symlink(elsewhere, filepath.Join(repo, ".worktrees"))
	if _, _, err := (Worktrees{}).Add(ctx, repo, "brave-otter"); err == nil {
		t.Error("made a worktree through a linked .worktrees")
	}
	if got, _ := os.ReadDir(elsewhere); len(got) > 0 {
		t.Errorf("wrote %v where the link points", got)
	}

	target := filepath.Join(elsewhere, "settings.json")
	write(t, target, "{}")
	exclude := filepath.Join(repo, ".git", "info", "exclude")
	os.Remove(exclude)
	os.Symlink(target, exclude)
	if err := Exclude(ctx, repo, "/.worktrees/"); err == nil {
		t.Error("wrote through a linked info/exclude")
	}
	os.RemoveAll(filepath.Join(repo, ".git", "info"))
	os.Symlink(elsewhere, filepath.Join(repo, ".git", "info"))
	if err := Exclude(ctx, repo, "/.worktrees/"); err == nil {
		t.Error("wrote through a linked info folder")
	}
	if b, _ := os.ReadFile(target); string(b) != "{}" {
		t.Errorf("the link's target became %q", b)
	}
}

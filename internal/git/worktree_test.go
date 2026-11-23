package git

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"slices"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestWorktrees(t *testing.T) {
	ctx := context.Background()
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Write(t, filepath.Join(repo, "sub", "a.txt"), "a\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")

	wt, folder, err := Worktrees{}.Add(ctx, filepath.Join(repo, "sub"), "brave-otter", "", "", nil)
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
	if _, _, err := (Worktrees{}).Add(ctx, folder, "brave-otter", "", "", nil); !errors.Is(err, fs.ErrExist) {
		t.Errorf("a taken name: %v", err)
	}
	// A name is taken by its folder alone, or by its branch alone (a
	// deleted chat can leave its branch).
	testcheck.NoErr(t, os.MkdirAll(filepath.Join(repo, ".worktrees", "lone-folder"), 0o755))
	testcheck.Git(t, repo, "branch", "nushi/lone-branch")
	for _, name := range []string{"lone-folder", "lone-branch"} {
		if _, _, err := (Worktrees{}).Add(ctx, repo, name, "", "", nil); !errors.Is(err, fs.ErrExist) {
			t.Errorf("%s: %v", name, err)
		}
	}
	// A path the caller has taken, or a folder the commit doesn't have, is
	// refused before any checkout: no folder, no branch.
	taken := func(path string) bool { return filepath.Base(path) == "on-record" }
	testcheck.Write(t, filepath.Join(repo, "untracked", "b.txt"), "b\n")
	for name, add := range map[string]func() error{
		"on-record": func() error { _, _, err := (Worktrees{}).Add(ctx, repo, "on-record", "", "", taken); return err },
		"untracked": func() error {
			_, _, err := (Worktrees{}).Add(ctx, filepath.Join(repo, "untracked"), "untracked", "", "", nil)
			if !errors.Is(err, ErrNotCommitted) {
				return fmt.Errorf("not ErrNotCommitted: %w", err)
			}
			return fs.ErrExist
		},
	} {
		if err := add(); !errors.Is(err, fs.ErrExist) {
			t.Errorf("%s: %v", name, err)
		}
		_, statErr := os.Lstat(filepath.Join(repo, ".worktrees", name))
		if statErr == nil || hasBranch(ctx, repo, "nushi/"+name) {
			t.Errorf("%s: checked out", name)
		}
	}
	testcheck.NoErr(t, os.RemoveAll(filepath.Join(repo, "untracked")))
	// Through a link to the repository, the worktree keeps the link's spelling.
	link := filepath.Join(t.TempDir(), "link")
	testcheck.NoErr(t, os.Symlink(repo, link))
	if via, in, err := (Worktrees{}).Add(ctx, filepath.Join(link, "sub"), "swift-yak", "", "", nil); err != nil || via.Repo != link || in != filepath.Join(link, ".worktrees", "swift-yak", "sub") {
		t.Errorf("Add through a link = %+v, %q, %v", via, in, err)
	}
	second, _, err := Worktrees{}.Add(ctx, folder, "calm-heron", "", "", nil)
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
	testcheck.Write(t, filepath.Join(second.Path, "new.txt"), "work\n")
	testcheck.Write(t, filepath.Join(second.Path, "sub", "a.txt"), "b\n")
	testcheck.Git(t, second.Path, "commit", "-q", "-am", "one")
	testcheck.Write(t, filepath.Join(second.Path, "sub", "a.txt"), "c\n")
	// Ignored files go with the worktree too.
	testcheck.Write(t, filepath.Join(second.Path, ".gitignore"), ".env\nbuild/\n")
	testcheck.Write(t, filepath.Join(second.Path, ".env"), "SECRET=1\n")
	testcheck.Write(t, filepath.Join(second.Path, "build", "out.o"), "o")
	if st, err := (Worktrees{}).Inspect(ctx, second); err != nil || !reflect.DeepEqual(st, model.WorktreeState{Changed: 3, Ignored: 2, Commits: 1,
		Changes: []string{"M sub/a.txt", "?? .gitignore", "?? new.txt"}}) {
		t.Errorf("Inspect = %+v, %v", st, err)
	}
	// Its base branch deleted (merged, say): counted from where it started.
	testcheck.Git(t, repo, "update-ref", "-d", "refs/heads/nushi/brave-otter")
	if n, err := (Worktrees{}).Inspect(ctx, second); err != nil || n.Commits != 1 {
		t.Errorf("Inspect with its base gone = %+v, %v", n, err)
	}
	if err := (Worktrees{}).Remove(ctx, second, false); err == nil {
		t.Error("a worktree with changes was removed without force")
	}
	if err := (Worktrees{}).Remove(ctx, second, true); err != nil {
		t.Fatal(err)
	}
	if st, err := (Worktrees{}).Inspect(ctx, second); err != nil || !reflect.DeepEqual(st, model.WorktreeState{Gone: true, Commits: 1}) {
		t.Errorf("Inspect after removing = %+v, %v", st, err)
	}
	if err := (Worktrees{}).DeleteBranch(ctx, second); err != nil {
		t.Fatal(err)
	}
	if st, err := (Worktrees{}).Inspect(ctx, second); err != nil || !reflect.DeepEqual(st, model.WorktreeState{Gone: true, BranchGone: true}) {
		t.Errorf("Inspect after deleting the branch = %+v, %v", st, err)
	}
	// A worktree whose folder went outside git: removing clears git's record
	// of it, not of another missing one (the user's, on a volume not mounted).
	theirs := filepath.Join(t.TempDir(), "theirs")
	testcheck.Git(t, repo, "worktree", "add", "-q", theirs)
	testcheck.NoErr(t, os.RemoveAll(theirs))
	testcheck.NoErr(t, os.RemoveAll(wt.Path))
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
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Write(t, filepath.Join(repo, "SKILL.md"), "evil\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")
	testcheck.NoErr(t, os.Symlink(elsewhere, filepath.Join(repo, ".worktrees")))
	if _, _, err := (Worktrees{}).Add(ctx, repo, "brave-otter", "", "", nil); err == nil {
		t.Error("made a worktree through a linked .worktrees")
	}
	if got, _ := os.ReadDir(elsewhere); len(got) > 0 {
		t.Errorf("wrote %v where the link points", got)
	}

	target := filepath.Join(elsewhere, "settings.json")
	testcheck.Write(t, target, "{}")
	exclude := filepath.Join(repo, ".git", "info", "exclude")
	testcheck.NoErr(t, os.Remove(exclude))
	testcheck.NoErr(t, os.Symlink(target, exclude))
	if err := Exclude(ctx, repo, "/.worktrees/"); err == nil {
		t.Error("wrote through a linked info/exclude")
	}
	testcheck.NoErr(t, os.RemoveAll(filepath.Join(repo, ".git", "info")))
	testcheck.NoErr(t, os.Symlink(elsewhere, filepath.Join(repo, ".git", "info")))
	if err := Exclude(ctx, repo, "/.worktrees/"); err == nil {
		t.Error("wrote through a linked info folder")
	}
	if b, _ := os.ReadFile(target); string(b) != "{}" {
		t.Errorf("the link's target became %q", b)
	}
}

// Excludes at once each add their line once: one line asked for by many,
// and each of many lines, are all there, none twice (excludeMu).
func TestExcludesAtOnce(t *testing.T) {
	repo := RealPath(t.TempDir())
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	var wg sync.WaitGroup
	errs := make(chan error, 40)
	for i := range 20 {
		wg.Go(func() { errs <- Exclude(t.Context(), repo, "/.worktrees/") })
		wg.Go(func() { errs <- Exclude(t.Context(), repo, fmt.Sprintf("/line-%d/", i)) })
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		testcheck.NoErr(t, err)
	}
	b, err := os.ReadFile(filepath.Join(repo, ".git", "info", "exclude"))
	testcheck.NoErr(t, err)
	seen := map[string]int{}
	for l := range strings.Lines(string(b)) {
		seen[strings.TrimSpace(l)]++
	}
	for i := range 20 {
		if n := seen[fmt.Sprintf("/line-%d/", i)]; n != 1 {
			t.Errorf("/line-%d/ %d times", i, n)
		}
	}
	if n := seen["/.worktrees/"]; n != 1 {
		t.Errorf("/.worktrees/ %d times", n)
	}
}

func TestCheckBranch(t *testing.T) {
	for _, name := range []string{
		"SCRUM-5-fix-the-login", "feature/SCRUM-5", "a.b", "ünïcode", "x@y", "v1.0",
		"", "a b", "a..b", "a//b", "/a", "a/", "a.", "a/.b", ".a", "a.lock", "a/b.lock/c", "a@{1}",
		"a~1", "a^", "a:b", "a?", "a*", "a[b", `a\b`, "a\tb", "a\x7fb",
	} {
		// git's verdict (git check-ref-format --branch), against ours.
		gitOK := exec.Command("git", "check-ref-format", "--branch", name).Run() == nil
		if ours := CheckBranch(name) == nil; ours != gitOK {
			t.Errorf("%q: CheckBranch says %v, git %v", name, ours, gitOK)
		}
	}
	// What git takes but means something else: HEAD's branch, an option.
	for _, name := range []string{"@", "-x", "--force", strings.Repeat("a", 201)} {
		if CheckBranch(name) == nil {
			t.Errorf("%q taken", name)
		}
	}
}

// A rename is one change to Inspect, as to Changed: git
// status gives its old path as a field of its own.
func TestInspectCountsARenameOnce(t *testing.T) {
	ctx := context.Background()
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Write(t, filepath.Join(repo, "a.txt"), "a\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")
	wt, _, err := Worktrees{}.Add(ctx, repo, "calm-heron", "", "", nil)
	testcheck.NoErr(t, err)
	testcheck.Git(t, wt.Path, "mv", "a.txt", "b.txt")
	changed, err := Worktrees{}.Changed(ctx, wt.Path)
	testcheck.NoErr(t, err)
	st, err := Worktrees{}.Inspect(ctx, wt)
	if err != nil || !slices.Equal(st.Changes, []string{"R b.txt"}) || changed != 1 || st.Changed != 1 {
		t.Errorf("Changed %d, Inspect %+v %v", changed, st, err)
	}
}

// Inspect's status stays out of submodules (ADR 0023), so it can't see
// what changed in one; a checked-out submodule is a change to Inspect,
// named among its Changes, as to git worktree remove, so removing the worktree asks for
// force rather than losing its work for an ignored file's force.
func TestInspectCountsACheckedOutSubmodule(t *testing.T) {
	ctx := context.Background()
	root, _ := filepath.EvalSymlinks(t.TempDir())
	lib, repo := filepath.Join(root, "lib"), filepath.Join(root, "repo")
	for _, dir := range []string{lib, repo} {
		testcheck.Git(t, root, "init", "-q", "-b", "main", dir)
		testcheck.Write(t, filepath.Join(dir, "a.txt"), "a\n")
		testcheck.Write(t, filepath.Join(dir, ".gitignore"), "out/\n")
		testcheck.Git(t, dir, "add", ".")
		testcheck.Git(t, dir, "commit", "-q", "-m", "init")
	}
	testcheck.Git(t, repo, "-c", "protocol.file.allow=always", "submodule", "add", "-q", lib, "vendor/lib")
	testcheck.Git(t, repo, "commit", "-q", "-m", "lib")
	wt, _, err := Worktrees{}.Add(ctx, repo, "calm-heron", "", "", nil)
	testcheck.NoErr(t, err)
	st, err := Worktrees{}.Inspect(ctx, wt)
	if err != nil || st.Changed != 0 {
		t.Fatalf("Inspect before the submodule's checkout = %+v, %v", st, err)
	}
	testcheck.Git(t, wt.Path, "-c", "protocol.file.allow=always", "submodule", "update", "-q", "--init")
	testcheck.Write(t, filepath.Join(wt.Path, "vendor", "lib", "a.txt"), "edited\n")
	testcheck.Write(t, filepath.Join(wt.Path, "out", "bin"), "built\n")
	st, err = Worktrees{}.Inspect(ctx, wt)
	if err != nil || st.Changed != 1 || st.Ignored != 1 || !slices.Equal(st.Changes, []string{"submodule vendor/lib"}) {
		t.Errorf("Inspect = %+v, %v", st, err)
	}
}

// A bare repository has no main worktree: List marks none of its linked
// ones Main, and Add makes no worktree of it from one of them.
func TestListOfABareRepository(t *testing.T) {
	ctx := context.Background()
	dir, _ := filepath.EvalSymlinks(t.TempDir())
	src, bare := filepath.Join(dir, "src"), filepath.Join(dir, "bare.git")
	testcheck.NoErr(t, os.MkdirAll(src, 0o700))
	testcheck.Git(t, src, "init", "-q", "-b", "main")
	testcheck.Git(t, src, "commit", "-q", "--allow-empty", "-m", "init")
	testcheck.Git(t, dir, "clone", "-q", "--bare", src, bare)
	one, two := filepath.Join(dir, "one"), filepath.Join(dir, "two")
	testcheck.Git(t, bare, "worktree", "add", "-q", "-b", "one", one)
	testcheck.Git(t, bare, "worktree", "add", "-q", "-b", "two", two)
	list, err := Worktrees{}.List(ctx, two)
	if err != nil || len(list) != 2 || list[0].Path != one || list[0].Main || list[1].Main || !list[1].Current {
		t.Errorf("List = %+v, %v", list, err)
	}
	if wt, _, err := (Worktrees{}).Add(ctx, two, "brave-otter", "", "", nil); err == nil || !strings.Contains(err.Error(), "bare") {
		t.Errorf("Add in a bare repository's worktree: %+v, %v", wt, err)
	}
}

// A worktree whose folder went outside Nushi is removed in any language:
// git speaks C to Nushi, whose own runs read its messages, whatever the
// user's locale.
func TestRemovingAGoneWorktreeInAnotherLanguage(t *testing.T) {
	ctx := context.Background()
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "init")
	wt, _, err := Worktrees{}.Add(ctx, repo, "brave-otter", "", "", nil)
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, os.RemoveAll(wt.Path))
	testcheck.Git(t, repo, "worktree", "prune")
	for _, lang := range []string{"de_DE.UTF-8", "fr_FR.UTF-8"} {
		t.Setenv("LANG", lang)
		t.Setenv("LC_ALL", lang)
		t.Setenv("LANGUAGE", "de:fr")
		t.Setenv("LC_MESSAGES", lang)
		if err := (Worktrees{}).Remove(ctx, wt, false); err != nil {
			t.Errorf("%s: %v", lang, err)
		}
	}
}

// Inspect counts every change but names only the first few: the clean-up
// dialog shows those, and a worktree can hold thousands of new files.
func TestInspectNamesTheFirstChanges(t *testing.T) {
	ctx := context.Background()
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "init")
	wt, _, err := Worktrees{}.Add(ctx, repo, "calm-heron", "", "", nil)
	testcheck.NoErr(t, err)
	for i := range shownChanges + 3 {
		testcheck.Write(t, filepath.Join(wt.Path, "f"+strconv.Itoa(i+10)+".txt"), "new\n")
	}
	st, err := Worktrees{}.Inspect(ctx, wt)
	if err != nil || st.Changed != shownChanges+3 || len(st.Changes) != shownChanges || st.Changes[0] != "?? f10.txt" {
		t.Errorf("Inspect = %+v, %v", st, err)
	}
}

package git

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

func git(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"}, args...)...)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
}

func write(t *testing.T, path, text string) {
	t.Helper()
	os.MkdirAll(filepath.Dir(path), 0o755)
	if err := os.WriteFile(path, []byte(text), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestChanges(t *testing.T) {
	ctx := context.Background()
	repo := t.TempDir()
	if _, err := Changes(ctx, repo, Span{}); err == nil {
		t.Error("a folder outside git had changes")
	}
	git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "sub", "kept.txt"), "one\n")
	if got, err := Changes(ctx, repo, Span{}); err != nil || len(got) != 1 || got[0].Status != "added" {
		t.Errorf("before the first commit: %+v, %v", got, err) // no HEAD yet
	}
	write(t, filepath.Join(repo, "sub", "gone.txt"), "bye\n")
	write(t, filepath.Join(repo, "sub", "bin"), "a\x00b")
	write(t, filepath.Join(repo, "top.txt"), "top\n")
	git(t, repo, "add", ".")
	git(t, repo, "commit", "-q", "-m", "init")

	write(t, filepath.Join(repo, "sub", "kept.txt"), "one\ntwo\n")
	os.Remove(filepath.Join(repo, "sub", "gone.txt"))
	write(t, filepath.Join(repo, "sub", "new.txt"), "new\n")
	write(t, filepath.Join(repo, "sub", "bin"), "c\x00d")
	os.Symlink("/etc/hosts", filepath.Join(repo, "sub", "link"))
	write(t, filepath.Join(repo, "top.txt"), "changed\n") // outside the folder asked for

	got, err := Changes(ctx, filepath.Join(repo, "sub"), Span{})
	if err != nil {
		t.Fatal(err)
	}
	want := []model.FileChange{
		{Path: "bin", Status: "modified", Skipped: "binary"},
		{Path: "gone.txt", Status: "deleted", Old: "bye\n", Removed: 1},
		{Path: "kept.txt", Status: "modified", Old: "one\n", New: "one\ntwo\n", Added: 1},
		{Path: "link", Status: "untracked", New: "/etc/hosts", Added: 1},
		{Path: "new.txt", Status: "untracked", New: "new\n", Added: 1},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("changes =\n%+v\nwant\n%+v", got, want)
	}
	st, err := Status(ctx, filepath.Join(repo, "sub"), "")
	if want := (model.FolderStatus{Branch: "main", Files: 5, Added: 3, Removed: 1}); err != nil || st != want {
		t.Errorf("status = %+v, %v; want %+v", st, err, want)
	}

	// A rename, counted under its new path.
	git(t, repo, "add", ".")
	git(t, repo, "commit", "-q", "-m", "more")
	git(t, repo, "mv", "sub/kept.txt", "sub/moved.txt")
	write(t, filepath.Join(repo, "sub", "moved.txt"), "one\ntwo\nthree\n")
	got, err = Changes(ctx, filepath.Join(repo, "sub"), Span{})
	want = []model.FileChange{{Path: "moved.txt", OldPath: "kept.txt", Status: "renamed", Old: "one\ntwo\n", New: "one\ntwo\nthree\n", Added: 1}}
	if err != nil || !reflect.DeepEqual(got, want) {
		t.Errorf("renamed: %+v, %v", got, err)
	}
}

func TestBranchChanges(t *testing.T) {
	ctx := context.Background()
	repo := t.TempDir()
	git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "a.txt"), "a\n")
	write(t, filepath.Join(repo, "b.txt"), "b\n")
	git(t, repo, "add", ".")
	git(t, repo, "commit", "-q", "-m", "init")
	git(t, repo, "switch", "-q", "-c", "feature")
	write(t, filepath.Join(repo, "a.txt"), "a\nmore\n")
	git(t, repo, "commit", "-q", "-am", "feature")
	// main moves on: its new commit isn't the branch's change.
	git(t, repo, "switch", "-q", "main")
	write(t, filepath.Join(repo, "c.txt"), "c\n")
	git(t, repo, "add", ".")
	git(t, repo, "commit", "-q", "-m", "main")
	git(t, repo, "switch", "-q", "feature")
	write(t, filepath.Join(repo, "b.txt"), "b2\n")

	paths := func(span Span) string {
		changes, err := Changes(ctx, repo, span)
		if err != nil {
			t.Fatal(err)
		}
		var out []string
		for _, c := range changes {
			out = append(out, c.Path+":"+c.Old+">"+c.New)
		}
		return strings.Join(out, " ")
	}
	if got, want := paths(Span{Base: "main"}), "a.txt:a\n>a\nmore\n b.txt:b\n>b2\n"; got != want {
		t.Errorf("branch changes = %q, want %q", got, want)
	}
	if got, want := paths(Span{}), "b.txt:b\n>b2\n"; got != want {
		t.Errorf("uncommitted changes = %q, want %q", got, want)
	}
	if st, err := Status(ctx, repo, "main"); err != nil || st.Files != 2 || st.Added != 2 || st.Removed != 1 {
		t.Errorf("branch status = %+v, %v", st, err)
	}
	if _, err := Changes(ctx, repo, Span{Base: "--output=x"}); err == nil {
		t.Error("an option as the base")
	}

	// The branch's commits, and what each made.
	if b := DefaultBase(ctx, repo); b != "main" {
		t.Errorf("default base = %q", b)
	}
	git(t, repo, "commit", "-q", "-am", "second")
	if n, err := Ahead(ctx, repo, "main"); n != 2 || err != nil {
		t.Errorf("ahead = %d, %v", n, err)
	}
	commits, err := Commits(ctx, repo, "main", 50)
	if err != nil || len(commits) != 2 || commits[0].Subject != "second" || commits[1].Added != 1 {
		t.Fatalf("commits = %+v, %v", commits, err)
	}
	if got, want := paths(Span{Commit: commits[0].Hash}), "b.txt:b\n>b2\n"; got != want {
		t.Errorf("a commit's changes = %q, want %q", got, want)
	}
	if got, want := paths(Span{Commit: commits[0].Hash, Since: commits[1].Hash}), "a.txt:a\n>a\nmore\n b.txt:b\n>b2\n"; got != want {
		t.Errorf("two commits' changes = %q, want %q", got, want)
	}
	if all, err := Commits(ctx, repo, "", 50); err != nil || len(all) != 3 {
		t.Errorf("the last commits = %+v, %v", all, err)
	}
	first, _ := Commits(ctx, repo, "", 50)
	if got, want := paths(Span{Commit: first[2].Hash}), "a.txt:>a\n b.txt:>b\n"; got != want {
		t.Errorf("the first commit's changes = %q, want %q", got, want)
	}
}

// A downloaded folder's .git/config can name hooks and filters: Nushi's own
// status runs neither, and its worktrees run no hooks.
func TestARepositorysOwnConfigRunsNothing(t *testing.T) {
	ctx := context.Background()
	repo, marks := t.TempDir(), t.TempDir()
	git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "a.txt"), "one\n")
	write(t, filepath.Join(repo, "b.md"), "one\n")
	git(t, repo, "add", ".")
	git(t, repo, "commit", "-q", "-m", "first")
	git(t, repo, "config", "filter.evil.clean", "touch "+filepath.Join(marks, "filter")+"; cat")
	// A driver whose name has a dot in it.
	write(t, filepath.Join(repo, ".git", "info", "attributes"), "*.txt filter=evil\n*.md filter=a.b\n")
	git(t, repo, "config", "filter.a.b.clean", "touch "+filepath.Join(marks, "dotted")+"; cat")
	write(t, filepath.Join(repo, "b.md"), "one\ntwo\n")
	write(t, filepath.Join(repo, ".git", "hooks", "post-checkout"), "#!/bin/sh\ntouch "+filepath.Join(marks, "hook")+"\n")
	os.Chmod(filepath.Join(repo, ".git", "hooks", "post-checkout"), 0o755)
	write(t, filepath.Join(repo, "a.txt"), "one\ntwo\n")

	if st, err := Status(ctx, repo, ""); err != nil || st.Added != 2 {
		t.Errorf("status = %+v, %v", st, err)
	}
	if _, _, err := (Worktrees{}).Add(ctx, repo, "wt"); err != nil {
		t.Fatal(err)
	}
	if ran, _ := filepath.Glob(filepath.Join(marks, "*")); len(ran) > 0 {
		t.Errorf("ran %v", ran)
	}
}

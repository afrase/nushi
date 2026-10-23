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
	if _, err := Changes(ctx, repo, ""); err == nil {
		t.Error("a folder outside git had changes")
	}
	git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "sub", "kept.txt"), "one\n")
	if got, err := Changes(ctx, repo, ""); err != nil || len(got) != 1 || got[0].Status != "added" {
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

	got, err := Changes(ctx, filepath.Join(repo, "sub"), "")
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
	got, err = Changes(ctx, filepath.Join(repo, "sub"), "")
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

	paths := func(base string) string {
		changes, err := Changes(ctx, repo, base)
		if err != nil {
			t.Fatal(err)
		}
		var out []string
		for _, c := range changes {
			out = append(out, c.Path+":"+c.Old+">"+c.New)
		}
		return strings.Join(out, " ")
	}
	if got, want := paths("main"), "a.txt:a\n>a\nmore\n b.txt:b\n>b2\n"; got != want {
		t.Errorf("branch changes = %q, want %q", got, want)
	}
	if got, want := paths(""), "b.txt:b\n>b2\n"; got != want {
		t.Errorf("uncommitted changes = %q, want %q", got, want)
	}
	if st, err := Status(ctx, repo, "main"); err != nil || st.Files != 2 || st.Added != 2 || st.Removed != 1 {
		t.Errorf("branch status = %+v, %v", st, err)
	}
	if _, err := Changes(ctx, repo, "--output=x"); err == nil {
		t.Error("an option as the base")
	}
}

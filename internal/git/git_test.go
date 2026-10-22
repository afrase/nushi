package git

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
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
	if _, err := Changes(ctx, repo); err == nil {
		t.Error("a folder outside git had changes")
	}
	git(t, repo, "init", "-q")
	write(t, filepath.Join(repo, "sub", "kept.txt"), "one\n")
	if got, err := Changes(ctx, repo); err != nil || len(got) != 1 || got[0].Status != "added" {
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

	got, err := Changes(ctx, filepath.Join(repo, "sub"))
	if err != nil {
		t.Fatal(err)
	}
	want := []model.FileChange{
		{Path: "bin", Status: "modified", Skipped: "binary"},
		{Path: "gone.txt", Status: "deleted", Old: "bye\n"},
		{Path: "kept.txt", Status: "modified", Old: "one\n", New: "one\ntwo\n"},
		{Path: "link", Status: "added", New: "/etc/hosts"},
		{Path: "new.txt", Status: "added", New: "new\n"},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("changes =\n%+v\nwant\n%+v", got, want)
	}
}

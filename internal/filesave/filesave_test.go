package filesave

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

func read(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	testcheck.NoErr(t, err)
	return string(b)
}

func TestSaveWritesOnlyOverTheBase(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "a.go")
	testcheck.Write(t, path, "one\n")
	var s Saver
	r, err := s.Save(dir, "a.go", []byte("two\n"), Sum([]byte("one\n")), false)
	if err != nil || !r.Saved || r.Sum != Sum([]byte("two\n")) || read(t, path) != "two\n" {
		t.Fatalf("over the base: %+v, %v; disk %q", r, err, read(t, path))
	}
	// The base is the old file: stale, with the file as it is now.
	r, err = s.Save(dir, "a.go", []byte("three\n"), Sum([]byte("one\n")), false)
	if err != nil || r.Saved || string(r.Data) != "two\n" || r.Sum != Sum([]byte("two\n")) || r.Missing {
		t.Fatalf("stale: %+v, %v", r, err)
	}
	if read(t, path) != "two\n" {
		t.Fatalf("a stale save wrote %q", read(t, path))
	}
	// What the disk holds already: saved, whatever the base.
	r, err = s.Save(dir, "a.go", []byte("two\n"), "not a sum", false)
	if err != nil || !r.Saved {
		t.Fatalf("the same bytes: %+v, %v", r, err)
	}
}

func TestSaveKeepsTheMode(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "run.sh")
	testcheck.Write(t, path, "echo\n")
	testcheck.NoErr(t, os.Chmod(path, 0o751))
	var s Saver
	if _, err := s.Save(dir, "run.sh", []byte("echo hi\n"), Sum([]byte("echo\n")), false); err != nil {
		t.Fatal(err)
	}
	fi, err := os.Stat(path)
	testcheck.NoErr(t, err)
	if fi.Mode().Perm() != 0o751 {
		t.Errorf("mode %v, want 0751", fi.Mode().Perm())
	}
}

func TestSaveMustNotExist(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "gone.md")
	var s Saver
	// Gone, saved over its old base: missing, nothing written.
	r, err := s.Save(dir, "gone.md", []byte("mine"), Sum([]byte("old")), false)
	if err != nil || r.Saved || !r.Missing {
		t.Fatalf("gone: %+v, %v", r, err)
	}
	if _, err := os.Stat(path); err == nil {
		t.Fatal("a save over a gone file wrote it")
	}
	r, err = s.Save(dir, "gone.md", []byte("mine"), "", true)
	if err != nil || !r.Saved || read(t, path) != "mine" {
		t.Fatalf("must not exist: %+v, %v", r, err)
	}
	// Back meanwhile: stale, with what came back.
	r, err = s.Save(dir, "gone.md", []byte("again"), "", true)
	if err != nil || r.Saved || string(r.Data) != "mine" {
		t.Fatalf("there again: %+v, %v", r, err)
	}
	// Its folder must be there: no folders are made.
	if _, err := s.Save(dir, "new/x.md", []byte("x"), "", true); err == nil {
		t.Error("a file in a missing folder was written")
	}
}

func TestSaveRefuses(t *testing.T) {
	dir := t.TempDir()
	folder, outside := filepath.Join(dir, "folder"), filepath.Join(dir, "secret.md")
	testcheck.Write(t, outside, "secret")
	testcheck.Write(t, filepath.Join(folder, "real.md"), "real")
	testcheck.Write(t, filepath.Join(folder, "big.txt"), string(bytes.Repeat([]byte{'x'}, MaxSize+1)))
	testcheck.Write(t, filepath.Join(folder, "one.txt"), "one")
	testcheck.NoErr(t, os.Link(filepath.Join(folder, "one.txt"), filepath.Join(folder, "two.txt")))
	testcheck.NoErr(t, os.Symlink(outside, filepath.Join(folder, "out.md")))
	testcheck.NoErr(t, os.Symlink("../secret.md", filepath.Join(folder, "rel.md")))
	testcheck.NoErr(t, os.Symlink("nowhere.md", filepath.Join(folder, "dangling.md")))
	testcheck.NoErr(t, os.Symlink(dir, filepath.Join(folder, "up")))
	testcheck.NoErr(t, os.MkdirAll(filepath.Join(folder, "sub"), 0o700))
	testcheck.NoErr(t, syscall.Mkfifo(filepath.Join(folder, "fifo"), 0o600))
	var s Saver
	for _, c := range []struct {
		rel  string
		data []byte
		want error
	}{
		{"out.md", []byte("x"), ErrOutside},
		{"rel.md", []byte("x"), ErrOutside},
		{"up/secret.md", []byte("x"), ErrOutside},
		{"dangling.md", []byte("x"), ErrNotRegular},
		{"sub", []byte("x"), ErrNotRegular},
		{"fifo", []byte("x"), ErrNotRegular},
		{"two.txt", []byte("x"), ErrLinked},
		{"big.txt", []byte("x"), ErrTooLarge},
		{"real.md", bytes.Repeat([]byte{'x'}, MaxSize+1), ErrTooLarge},
	} {
		if _, err := s.Save(folder, c.rel, c.data, "", true); !errors.Is(err, c.want) {
			t.Errorf("%s: %v, want %v", c.rel, err, c.want)
		}
		if _, err := s.Save(folder, c.rel, c.data, Sum([]byte("real")), false); !errors.Is(err, c.want) {
			t.Errorf("%s over a base: %v, want %v", c.rel, err, c.want)
		}
	}
	if read(t, outside) != "secret" || read(t, filepath.Join(folder, "one.txt")) != "one" {
		t.Error("a refused save wrote")
	}
}

// A link that stays inside the folder is followed: its target is written,
// the link kept.
func TestSaveFollowsALinkInside(t *testing.T) {
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "AGENTS.md"), "rules")
	testcheck.NoErr(t, os.Symlink("AGENTS.md", filepath.Join(dir, "CLAUDE.md")))
	var s Saver
	r, err := s.Save(dir, "CLAUDE.md", []byte("new rules"), Sum([]byte("rules")), false)
	if err != nil || !r.Saved || r.Path != filepath.Join(mustReal(t, dir), "AGENTS.md") {
		t.Fatalf("%+v, %v", r, err)
	}
	if read(t, filepath.Join(dir, "AGENTS.md")) != "new rules" {
		t.Error("the target wasn't written")
	}
	fi, err := os.Lstat(filepath.Join(dir, "CLAUDE.md"))
	if err != nil || fi.Mode()&os.ModeSymlink == 0 {
		t.Error("the link went")
	}
}

func mustReal(t *testing.T, p string) string {
	t.Helper()
	r, err := filepath.EvalSymlinks(p)
	testcheck.NoErr(t, err)
	return r
}

// Saves of one file wait for each other: of two over the same base, one
// writes and the other is stale.
func TestSavesOfAFileTakeTurns(t *testing.T) {
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "a.txt"), "base")
	var s Saver
	var wg sync.WaitGroup
	results := make([]Result, 8)
	for i := range results {
		wg.Go(func() {
			r, err := s.Save(dir, "a.txt", []byte(strconv.Itoa(i)), Sum([]byte("base")), false)
			if err != nil {
				t.Error(err)
			}
			results[i] = r
		})
	}
	wg.Wait()
	saved := 0
	for _, r := range results {
		if r.Saved {
			saved++
		}
	}
	if saved != 1 {
		t.Errorf("%d saves wrote", saved)
	}
	if len(s.locks) != 0 {
		t.Errorf("%d locks kept", len(s.locks))
	}
}

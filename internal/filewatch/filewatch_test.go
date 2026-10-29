package filewatch

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

func TestLocate(t *testing.T) {
	dir := t.TempDir()
	folder, wt := filepath.Join(dir, "repo", "app"), filepath.Join(dir, "wt")
	roots := []string{folder, wt}
	for _, c := range []struct {
		path, root, rel string
	}{
		{"docs/a.md", folder, "docs/a.md"},
		{filepath.Join(folder, "b.md"), folder, "b.md"},
		{filepath.Join(wt, "c.png"), wt, "c.png"},
		{"docs/../d.md", folder, "d.md"},
	} {
		root, rel, err := Locate(roots, c.path)
		if err != nil || root != c.root || rel != c.rel {
			t.Errorf("Locate(%q) = %q, %q, %v; want %q, %q", c.path, root, rel, err, c.root, c.rel)
		}
	}
	for _, path := range []string{"../x.md", "../../etc/passwd", "/etc/passwd", filepath.Join(dir, "repo", "x.md"), folder} {
		if root, rel, err := Locate(roots, path); err == nil {
			t.Errorf("Locate(%q) = %q, %q; want refused", path, root, rel)
		}
	}
}

func TestReadRefusesLinksOut(t *testing.T) {
	dir := t.TempDir()
	folder, outside := filepath.Join(dir, "folder"), filepath.Join(dir, "secret.md")
	testcheck.Write(t, outside, "secret")
	testcheck.Write(t, filepath.Join(folder, "real.md"), "# real")
	for name, target := range map[string]string{
		"out.md":    outside,
		"rel.md":    "../secret.md",
		"inside.md": "real.md",
	} {
		if err := os.Symlink(target, filepath.Join(folder, name)); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.Symlink(dir, filepath.Join(folder, "up")); err != nil {
		t.Fatal(err)
	}
	for _, rel := range []string{"out.md", "rel.md", "up/secret.md"} {
		if f, err := Read(folder, rel); err == nil {
			t.Errorf("Read(%q) = %q; want refused", rel, f.Data)
		}
	}
	// A link that stays inside reads its target.
	if f, err := Read(folder, "inside.md"); err != nil || string(f.Data) != "# real" {
		t.Errorf("Read(inside.md) = %q, %v", f.Data, err)
	}
	if f, err := Read(folder, "gone.md"); err != nil || !f.Missing {
		t.Errorf("Read(gone.md) = %+v, %v; want missing", f, err)
	}
	if f, err := Read(dir, "folder"); err != nil || !f.Missing {
		t.Errorf("Read(a folder) = %+v, %v; want missing", f, err)
	}
}

func TestReadCapsSize(t *testing.T) {
	dir := t.TempDir()
	testcheck.Write(t, filepath.Join(dir, "big.png"), string(bytes.Repeat([]byte{'x'}, MaxSize+1)))
	testcheck.Write(t, filepath.Join(dir, "ok.png"), string(bytes.Repeat([]byte{'x'}, MaxSize)))
	f, err := Read(dir, "big.png")
	if err != nil || !f.TooLarge || f.Data != nil || f.Size != MaxSize+1 {
		t.Errorf("big: TooLarge %v, %d bytes, size %d, %v", f.TooLarge, len(f.Data), f.Size, err)
	}
	f, err = Read(dir, "ok.png")
	if err != nil || f.TooLarge || len(f.Data) != MaxSize {
		t.Errorf("at the cap: TooLarge %v, %d bytes, %v", f.TooLarge, len(f.Data), err)
	}
}

func TestWatchSendsChanges(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "report.md")
	got := make(chan File, 10)
	ctx, cancel := context.WithCancel(t.Context())
	done := make(chan error, 1)
	go func() {
		done <- Watch(ctx, dir, "report.md", 10*time.Millisecond, func(f File) error {
			got <- f
			return nil
		})
	}()
	next := func() File {
		t.Helper()
		select {
		case f := <-got:
			return f
		case <-time.After(5 * time.Second):
			t.Fatal("nothing sent")
			return File{}
		}
	}
	if f := next(); !f.Missing || f.Path != path {
		t.Fatalf("first = %+v; want missing %s", f, path)
	}
	testcheck.Write(t, path, "# one")
	if f := next(); string(f.Data) != "# one" {
		t.Fatalf("after writing: %q", f.Data)
	}
	// A rewrite (as an agent's Write: a new file renamed over it).
	testcheck.Write(t, path+".tmp", "# two, longer")
	if err := os.Rename(path+".tmp", path); err != nil {
		t.Fatal(err)
	}
	if f := next(); string(f.Data) != "# two, longer" {
		t.Fatalf("after the rewrite: %q", f.Data)
	}
	// Turned into a link out of the folder: refused, and the watch ends.
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("/etc/hosts", path); err != nil {
		t.Fatal(err)
	}
	select {
	case err := <-done:
		if err == nil {
			t.Fatal("a link out ended the watch without an error")
		}
	case f := <-got:
		if !f.Missing { // the removal may be seen first
			t.Fatalf("sent %+v through a link out", f)
		}
		if err := <-done; err == nil {
			t.Fatal("a link out ended the watch without an error")
		}
	}
	cancel()
}

package atomicfile

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// Rewrite keeps a file's mode, makes a new one private, and changes the
// file a link points at, not the link.
func TestRewrite(t *testing.T) {
	dir := t.TempDir()
	kept := filepath.Join(dir, "kept.json")
	noErr(t, os.WriteFile(kept, []byte("old"), 0o640))
	noErr(t, os.Chmod(kept, 0o640))
	target := filepath.Join(dir, "dotfiles", "settings.json")
	noErr(t, os.MkdirAll(filepath.Dir(target), 0o755))
	noErr(t, os.WriteFile(target, []byte("old"), 0o644))
	link := filepath.Join(dir, "link.json")
	noErr(t, os.Symlink(target, link))
	dangling := filepath.Join(dir, "dangling.json")
	noErr(t, os.Symlink(filepath.Join(dir, "nowhere"), dangling))
	for _, c := range []struct {
		name, path, file string // file: where the data lands
		mode             os.FileMode
	}{
		{"new, its folder too", filepath.Join(dir, "new", "settings.json"), "", 0o600},
		{"kept mode", kept, "", 0o640},
		{"through a link", link, target, 0o644},
		{"a link to nothing", dangling, "", 0o600},
	} {
		noErr(t, Rewrite(c.path, []byte("new")))
		file := c.path
		if c.file != "" {
			file = c.file
		}
		fi, err := os.Lstat(file)
		noErr(t, err)
		if b, _ := os.ReadFile(file); string(b) != "new" || fi.Mode() != c.mode {
			t.Errorf("%s: %q, %v", c.name, b, fi.Mode())
		}
		if c.file != "" {
			if fi, err := os.Lstat(c.path); err != nil || fi.Mode()&os.ModeSymlink == 0 {
				t.Errorf("%s: the link went: %v", c.name, err)
			}
		}
	}
	if fi, _ := os.Stat(filepath.Join(dir, "new")); fi.Mode().Perm() != 0o700 {
		t.Errorf("a new folder is %v", fi.Mode())
	}
	leftovers(t, dir, filepath.Join(dir, "dotfiles"))
}

// A write that fails leaves the old file and no temporary file.
func TestFailedWriteLeavesNothing(t *testing.T) {
	dir := t.TempDir()
	busy := filepath.Join(dir, "busy") // a folder with a file in it: nothing renames over it
	noErr(t, os.MkdirAll(filepath.Join(busy, "x"), 0o700))
	if err := Replace(busy, []byte("new"), 0o600); err == nil {
		t.Error("Replace over a folder worked")
	}
	root, err := os.OpenRoot(dir)
	noErr(t, err)
	defer root.Close() //nolint:errcheck // a test's
	if err := ReplaceIn(root, "busy", []byte("new"), 0o600); err == nil {
		t.Error("ReplaceIn over a folder worked")
	}
	leftovers(t, dir)
}

// ReplaceIn writes name with mode inside root, and nothing through a link
// that leads out of it.
func TestReplaceIn(t *testing.T) {
	dir := t.TempDir()
	outside := t.TempDir()
	noErr(t, os.MkdirAll(filepath.Join(dir, "in"), 0o700))
	noErr(t, os.Symlink(outside, filepath.Join(dir, "out")))
	root, err := os.OpenRoot(dir)
	noErr(t, err)
	defer root.Close() //nolint:errcheck // a test's
	noErr(t, ReplaceIn(root, "in/settings.json", []byte("new"), 0o644))
	fi, err := os.Stat(filepath.Join(dir, "in", "settings.json"))
	noErr(t, err)
	if b, _ := os.ReadFile(filepath.Join(dir, "in", "settings.json")); string(b) != "new" || fi.Mode().Perm() != 0o644 {
		t.Errorf("%q, %v", b, fi.Mode())
	}
	if err := ReplaceIn(root, "out/settings.json", []byte("new"), 0o644); err == nil {
		t.Error("wrote through a link out of the root")
	}
	if files, _ := os.ReadDir(outside); len(files) != 0 {
		t.Errorf("wrote outside: %v", files)
	}
	leftovers(t, dir, filepath.Join(dir, "in"))
}

// leftovers fails if a temporary file is left in dirs.
func leftovers(t *testing.T, dirs ...string) {
	t.Helper()
	for _, d := range dirs {
		files, err := os.ReadDir(d)
		noErr(t, err)
		for _, f := range files {
			if strings.HasPrefix(f.Name(), ".nushi-") {
				t.Errorf("%s left in %s", f.Name(), d)
			}
		}
	}
}

func noErr(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

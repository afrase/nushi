package claudehistory

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

func TestDirNameIsClaudes(t *testing.T) {
	// Expected names from Claude's own function, run in node.
	long := "/nushi-test/" + strings.Repeat("a-very-long-folder-name/", 9) + "café"
	for folder, want := range map[string]string{
		"/Users/me/my.repo é": "-Users-me-my-repo--",
		long:                  "-nushi-test" + strings.Repeat("-a-very-long-folder-name", 7) + "-a-very-long-folder-n-ytjik2",
	} {
		if got := dirName(folder); got != want {
			t.Errorf("dirName(%q) = %q, want %q", folder, got, want)
		}
	}
}

// claudeName is Claude's name for a short folder's history, worked out
// apart from dirName: its real path (/var is /private/var on macOS), each
// character but a letter or digit a "-".
func claudeName(t *testing.T, folder string) string {
	t.Helper()
	resolved, err := filepath.EvalSymlinks(folder)
	if err != nil {
		t.Fatal(err)
	}
	return regexp.MustCompile(`[^A-Za-z0-9]`).ReplaceAllString(resolved, "-")
}

func TestCopyKeepsTheOriginal(t *testing.T) {
	projects, from, to := t.TempDir(), t.TempDir(), t.TempDir()
	src, dst := filepath.Join(projects, claudeName(t, from)), filepath.Join(projects, claudeName(t, to))
	link := filepath.Join(t.TempDir(), "link") // a chat moved to a folder reached through a link
	noErr(t, os.Symlink(to, link))
	to = link
	if err := os.MkdirAll(src, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(src, "s1.jsonl"), []byte("transcript"), 0o600); err != nil {
		t.Fatal(err)
	}

	remove, err := Copy(projects, "s1", from, to)
	if err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{filepath.Join(dst, "s1.jsonl"), filepath.Join(src, "s1.jsonl")} {
		if b, err := os.ReadFile(path); err != nil || string(b) != "transcript" {
			t.Errorf("%s = %q, %v", path, b, err)
		}
	}
	if _, err := Copy(projects, "s1", from, to); err != nil {
		t.Errorf("a copy a move left (the start of this one) wasn't replaced: %v", err)
	}
	noErr(t, os.WriteFile(filepath.Join(dst, "s1.jsonl"), []byte("another"), 0o600))
	if _, err := Copy(projects, "s1", from, to); err == nil {
		t.Error("another transcript already there was replaced")
	}
	if err := remove(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(src, "s1.jsonl")); err != nil {
		t.Errorf("the original went with the copy: %v", err)
	}
	if _, err := Copy(projects, "missing", from, to); err == nil {
		t.Error("copying a session that isn't there worked")
	}
	if _, err := Copy(projects, "../s1", from, to); err == nil {
		t.Error("a session id with a path in it was taken")
	}
}

// Gone is true only when the folder's history folder can be read and the
// transcript isn't in it.
func TestGone(t *testing.T) {
	projects, folder := t.TempDir(), t.TempDir()
	if Gone(projects, "s1", folder) {
		t.Error("gone with no history folder")
	}
	dir := filepath.Join(projects, dirName(folder))
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if !Gone(projects, "s1", folder) {
		t.Error("not gone from an empty history folder")
	}
	if err := os.WriteFile(filepath.Join(dir, "s1.jsonl"), []byte("{}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if Gone(projects, "s1", folder) || !Gone(projects, "s2", folder) {
		t.Error("s1 is there, s2 isn't")
	}
	if Gone(projects, "../s2", folder) || Gone(projects, "", folder) {
		t.Error("gone for a bad id")
	}
	if err := os.Chmod(dir, 0); err != nil {
		t.Fatal(err)
	}
	defer os.Chmod(dir, 0o700) //nolint:errcheck // for the cleanup
	if Gone(projects, "s2", folder) {
		t.Error("gone from a history folder that can't be read")
	}
}

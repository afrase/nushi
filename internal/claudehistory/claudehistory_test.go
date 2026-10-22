package claudehistory

import (
	"os"
	"path/filepath"
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

func TestCopyKeepsTheOriginal(t *testing.T) {
	projects, from, to := t.TempDir(), t.TempDir(), t.TempDir()
	src, dst := filepath.Join(projects, dirName(from)), filepath.Join(projects, dirName(to))
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
	if _, err := Copy(projects, "s1", from, to); err == nil {
		t.Error("a copy already there was replaced")
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

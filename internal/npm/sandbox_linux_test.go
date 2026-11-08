package npm

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// Without bwrap on PATH, nothing runs, and the reason is the fixed one the
// app shows.
func TestNoBubblewrap(t *testing.T) {
	t.Setenv("PATH", t.TempDir())
	if _, err := writingOnlyIn(context.Background(), t.TempDir(), "npm", "ci"); !errors.Is(err, ErrNoBubblewrap) {
		t.Errorf("%v", err)
	}
}

// A bwrap that can't make its sandbox (here a stand-in failing as Ubuntu's
// AppArmor makes it fail) refuses before npm runs, with bwrap's reason.
func TestBubblewrapFails(t *testing.T) {
	bin := t.TempDir()
	testcheck.NoErr(t, os.WriteFile(filepath.Join(bin, "bwrap"), []byte("#!/bin/sh\necho 'bwrap: setting up uid map: Permission denied' >&2\nexit 1\n"), 0o700))
	t.Setenv("PATH", bin+":/usr/bin:/bin")
	_, err := writingOnlyIn(context.Background(), t.TempDir(), "npm", "ci")
	if err == nil || errors.Is(err, ErrNoBubblewrap) || !strings.Contains(err.Error(), "uid map: Permission denied") {
		t.Errorf("%v", err)
	}
}

// Under the real bubblewrap a command reads and writes in dir; a folder
// beside it stays readable and unwritten, and so does one outside /tmp.
func TestWritingOnlyIn(t *testing.T) {
	if _, err := exec.LookPath("bwrap"); err != nil {
		t.Skip("no bwrap")
	}
	dir, beside := t.TempDir(), t.TempDir()
	testcheck.NoErr(t, os.WriteFile(filepath.Join(beside, "settings"), []byte("x"), 0o600))
	outside, err := os.MkdirTemp("/var/tmp", "nushi-npm-test-") //nolint:usetesting // a folder outside /tmp, where t.TempDir's are
	if err != nil {
		t.Skipf("no folder outside /tmp: %v", err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(outside) })
	cmd, err := writingOnlyIn(context.Background(), dir, "sh", "-c",
		`touch "$1/in" && cat "$2/settings" >/dev/null && ! touch "$2/out" 2>/dev/null && ! touch "$3/out" 2>/dev/null`, "sh", dir, beside, outside)
	if err != nil {
		t.Skipf("bubblewrap doesn't run here: %v", err)
	}
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("%v: %s", err, out)
	}
	if _, err := os.Stat(filepath.Join(dir, "in")); err != nil {
		t.Errorf("dir unwritten: %v", err)
	}
	for _, p := range []string{filepath.Join(beside, "out"), filepath.Join(outside, "out")} {
		if _, err := os.Stat(p); err == nil {
			_ = os.Remove(p)
			t.Errorf("%s written", p)
		}
	}
}

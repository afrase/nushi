package npm

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// Without bwrap on the PATH npm runs from, nothing runs, and the reason is
// the fixed one the app shows, though the daemon's own PATH has one.
func TestNoBubblewrap(t *testing.T) {
	bin := t.TempDir()
	testcheck.NoErr(t, os.WriteFile(filepath.Join(bin, "bwrap"), []byte("#!/bin/sh\nexit 0\n"), 0o700))
	t.Setenv("PATH", bin)
	if _, err := writingOnlyIn(context.Background(), []string{"PATH=" + t.TempDir()}, t.TempDir(), "npm", "ci"); !errors.Is(err, ErrNoBubblewrap) {
		t.Errorf("%v", err)
	}
}

// bwrap is found on the PATH npm runs from (the login shell's), though the
// daemon's own has none, and the command runs in that environment.
func TestBubblewrapOnAgentsPath(t *testing.T) {
	bin := t.TempDir()
	testcheck.NoErr(t, os.WriteFile(filepath.Join(bin, "bwrap"), []byte("#!/bin/sh\nexit 0\n"), 0o700))
	t.Setenv("PATH", t.TempDir())
	env := []string{"PATH=" + bin + ":/usr/bin:/bin", "npm_config_x=1"}
	cmd, err := writingOnlyIn(context.Background(), env, t.TempDir(), "npm", "ci")
	if err != nil {
		t.Fatal(err)
	}
	if cmd.Path != filepath.Join(bin, "bwrap") || !slices.Equal(cmd.Env, env) {
		t.Errorf("%s in %q", cmd.Path, cmd.Env)
	}
}

// A bwrap that can't make its sandbox (here a stand-in failing as Ubuntu's
// AppArmor makes it fail) refuses before npm runs, with bwrap's reason.
func TestBubblewrapFails(t *testing.T) {
	bin := t.TempDir()
	testcheck.NoErr(t, os.WriteFile(filepath.Join(bin, "bwrap"), []byte("#!/bin/sh\necho 'bwrap: setting up uid map: Permission denied' >&2\nexit 1\n"), 0o700))
	_, err := writingOnlyIn(context.Background(), []string{"PATH=" + bin + ":/usr/bin:/bin"}, t.TempDir(), "npm", "ci")
	if err == nil || errors.Is(err, ErrNoBubblewrap) || !strings.Contains(err.Error(), "uid map: Permission denied") {
		t.Errorf("%v", err)
	}
}

// Under the real bubblewrap a command reads and writes in dir; a folder
// beside it stays readable and unwritten, and so does one outside /tmp.
func TestWritingOnlyIn(t *testing.T) {
	sandboxRuns(t)
	dir, beside := t.TempDir(), t.TempDir()
	testcheck.NoErr(t, os.WriteFile(filepath.Join(beside, "settings"), []byte("x"), 0o600))
	outside, err := os.MkdirTemp("/var/tmp", "nushi-npm-test-") //nolint:usetesting // a folder outside /tmp, where t.TempDir's are
	if err != nil {
		t.Skipf("no folder outside /tmp: %v", err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(outside) })
	cmd, err := writingOnlyIn(context.Background(), os.Environ(), dir, "sh", "-c",
		`touch "$1/in" && cat "$2/settings" >/dev/null && ! touch "$2/out" 2>/dev/null && ! touch "$3/out" 2>/dev/null`, "sh", dir, beside, outside)
	if err != nil {
		t.Fatal(err)
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

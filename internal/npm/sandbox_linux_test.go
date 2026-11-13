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

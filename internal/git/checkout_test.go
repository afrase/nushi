package git

import (
	"os"
	"path/filepath"
	"syscall"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

// A downloaded folder's .git, or the gitdir record a .git file names,
// that is a link to /dev/zero or a fifo keys on the folder itself: the
// read neither grows without end nor waits.
func TestTrustRootOnGitFilesThatAreNotFiles(t *testing.T) {
	for _, c := range []struct {
		name string
		make func(t *testing.T, dir string)
	}{
		{".git to /dev/zero", func(t *testing.T, dir string) {
			t.Helper()
			testcheck.NoErr(t, os.Symlink("/dev/zero", filepath.Join(dir, ".git")))
		}},
		{"a .git fifo", func(t *testing.T, dir string) {
			t.Helper()
			testcheck.NoErr(t, syscall.Mkfifo(filepath.Join(dir, ".git"), 0o600))
		}},
		{"a gitdir record to /dev/zero", func(t *testing.T, dir string) {
			t.Helper()
			rec := filepath.Join(dir, "sub", ".git", "worktrees", "w")
			testcheck.NoErr(t, os.MkdirAll(rec, 0o700))
			testcheck.NoErr(t, os.Symlink("/dev/zero", filepath.Join(rec, "gitdir")))
			testcheck.Write(t, filepath.Join(dir, ".git"), "gitdir: sub/.git/worktrees/w\n")
		}},
		{"a gitdir record fifo", func(t *testing.T, dir string) {
			t.Helper()
			rec := filepath.Join(dir, "sub", ".git", "worktrees", "w")
			testcheck.NoErr(t, os.MkdirAll(rec, 0o700))
			testcheck.NoErr(t, syscall.Mkfifo(filepath.Join(rec, "gitdir"), 0o600))
			testcheck.Write(t, filepath.Join(dir, ".git"), "gitdir: sub/.git/worktrees/w\n")
		}},
	} {
		t.Run(c.name, func(t *testing.T) {
			dir := RealPath(t.TempDir())
			c.make(t, dir)
			type root struct{ top, key string }
			done := make(chan root, 1)
			go func() {
				top, key := TrustRoot(dir)
				done <- root{top, key}
			}()
			select {
			case r := <-done:
				if r.top != dir || r.key != dir {
					t.Errorf("TrustRoot = %q, %q; want the folder itself", r.top, r.key)
				}
			case <-time.After(5 * time.Second):
				t.Fatal("TrustRoot still reading after 5 s")
			}
		})
	}
}

// worktreeSet leaves out git's environment but GIT_CONFIG_GLOBAL and
// GIT_CONFIG_NOSYSTEM, which say which of the user's own config files git
// reads: make test-go points them at nothing so no test reads the
// owner's config. Here HOME's config doesn't parse, so git fails if it
// reads it.
func TestWorktreeSetKeepsTheConfigChoice(t *testing.T) {
	home := t.TempDir()
	testcheck.Write(t, filepath.Join(home, ".gitconfig"), "[not config\n")
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	t.Setenv("GIT_CONFIG_GLOBAL", "/dev/null")
	t.Setenv("GIT_CONFIG_NOSYSTEM", "1")
	t.Setenv("GIT_DIR", t.TempDir()) // the rest still goes
	config := filepath.Join(t.TempDir(), "config")
	testcheck.Write(t, config, "[core]\n\tworktree = /elsewhere\n")
	if !worktreeSet(config) {
		t.Error("core.worktree not read: git read HOME's config, or GIT_DIR's")
	}
}

package filelock

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"golang.org/x/sys/unix"

	"github.com/afrase/nushi/internal/testcheck"
)

// Held sees each kind of Linux lock: a POSIX one taken by this process,
// which F_GETLK doesn't report to it, and a flock one another process
// holds, which F_GETLK never sees; both only through /proc/locks. An open
// file description's lock F_GETLK does see, even this process's, since
// Held opens a description of its own: "ofd" is a regression check that
// reading /proc/locks hasn't lost what F_GETLK finds.
func TestHeldEveryKind(t *testing.T) {
	for name, take := range map[string]func(t *testing.T, path string){
		"posix": func(t *testing.T, path string) { t.Helper(); fcntlLock(t, path, unix.F_SETLK) },
		"ofd":   func(t *testing.T, path string) { t.Helper(); fcntlLock(t, path, unix.F_OFD_SETLK) },
		"flock elsewhere": func(t *testing.T, path string) {
			t.Helper()
			if _, err := exec.LookPath("flock"); err != nil {
				t.Skip("no flock(1) to hold a lock from another process")
			}
			cmd := exec.CommandContext(t.Context(), "flock", path, "sleep", "30")
			if err := cmd.Start(); err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { _ = cmd.Process.Kill(); _ = cmd.Wait() })
			testcheck.Eventually(func() bool { return Held(path) }) // once flock(1) has it
		},
	} {
		t.Run(name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "x.lock")
			if err := os.WriteFile(path, nil, 0o644); err != nil {
				t.Fatal(err)
			}
			take(t, path)
			if !Held(path) {
				t.Error("the lock wasn't seen")
			}
		})
	}
}

// fcntlLock takes a write lock on the whole file with cmd (F_SETLK or
// F_OFD_SETLK), let go when the test ends.
func fcntlLock(t *testing.T, path string, cmd int) {
	t.Helper()
	f, err := os.OpenFile(path, os.O_RDWR, 0)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = f.Close() })
	lk := unix.Flock_t{Type: unix.F_WRLCK}
	if err := unix.FcntlFlock(f.Fd(), cmd, &lk); err != nil {
		t.Fatal(err)
	}
}

package main

import (
	"path/filepath"
	"syscall"
	"testing"

	"golang.org/x/sys/unix"

	"github.com/afrase/nushi/internal/testcheck"
)

// The data folder is nushi in the XDG data folder.
func TestTheLogGoesToTheDataFolder(t *testing.T) {
	home := t.TempDir()
	t.Setenv("NUSHID_DATA", "")
	t.Setenv("NUSHI_DATA", "")
	t.Setenv("XDG_DATA_HOME", "")
	if got := dataFolder(home); got != filepath.Join(home, ".local", "share", "nushi") {
		t.Errorf("no folder yet: %s", got)
	}
	t.Setenv("XDG_DATA_HOME", "/x/data")
	if got := dataFolder(home); got != "/x/data/nushi" {
		t.Errorf("XDG_DATA_HOME: %s", got)
	}
	t.Setenv("XDG_DATA_HOME", "relative") // ignored, as the spec says
	if got := dataFolder(home); got != filepath.Join(home, ".local", "share", "nushi") {
		t.Errorf("a relative XDG_DATA_HOME: %s", got)
	}
}

// -login leaves the login shell only stdio: a descriptor the app handed
// down without O_CLOEXEC is closed at the exec, by close_range and by the
// /proc walk older kernels get, and 0-2 stay as they were.
func TestLoginKeepsOnlyStdio(t *testing.T) {
	for name, mark := range map[string]func(){"close_range": keepOnlyStdio, "/proc": markProcFDs} {
		t.Run(name, func(t *testing.T) {
			fd, err := syscall.Open(t.TempDir(), syscall.O_RDONLY, 0) // no O_CLOEXEC, as the app's
			testcheck.NoErr(t, err)
			t.Cleanup(func() { _ = syscall.Close(fd) })
			stderr := fdFlags(t, 2)
			if fdFlags(t, fd)&unix.FD_CLOEXEC != 0 {
				t.Fatal("the descriptor is close-on-exec already")
			}
			mark()
			if fdFlags(t, fd)&unix.FD_CLOEXEC == 0 {
				t.Error("the inherited descriptor would reach the login shell")
			}
			if got := fdFlags(t, 2); got != stderr {
				t.Errorf("stderr's flags %#x, were %#x", got, stderr)
			}
		})
	}
}

// fdFlags is fd's descriptor flags.
func fdFlags(t *testing.T, fd int) int {
	t.Helper()
	flags, err := unix.FcntlInt(uintptr(fd), unix.F_GETFD, 0)
	testcheck.NoErr(t, err)
	return flags
}

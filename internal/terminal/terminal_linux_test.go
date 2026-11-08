package terminal

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/procfs"
	"github.com/afrase/nushi/internal/testcheck"
)

// No process started after a terminal holds its master: it could type
// into the terminal. A later child's descriptors are compared with the
// master by the file they are, not by number: under Rosetta every
// process holds descriptors of its own from 10 up (its binaries), so the
// master's number may be one of them.
func TestLaterProcessesDontGetTheTerminal(t *testing.T) {
	term, _ := shell(t)
	master, err := term.pty.Stat()
	testcheck.NoErr(t, err)
	child := exec.Command("sleep", "30")
	testcheck.NoErr(t, child.Start())
	t.Cleanup(func() { _ = child.Process.Kill(); _ = child.Wait() })
	dir := fmt.Sprintf("/proc/%d/fd", child.Process.Pid)
	fds, err := os.ReadDir(dir)
	testcheck.NoErr(t, err)
	if len(fds) == 0 {
		t.Fatal("the child has no descriptors to look at")
	}
	for _, fd := range fds {
		if fi, err := os.Stat(filepath.Join(dir, fd.Name())); err == nil && os.SameFile(fi, master) {
			t.Errorf("a later process has the master as its fd %s", fd.Name())
		}
	}
}

// The terminal's device is what the processes on it have as tty_nr.
func TestDeviceIsTheShellsTTY(t *testing.T) {
	term, _ := shell(t)
	s, err := procfs.ReadStat(term.Pid())
	testcheck.NoErr(t, err)
	if s.TTY == 0 || int32(s.TTY) != term.tty { //nolint:gosec // tty_nr is a 32-bit field of the kernel's
		t.Fatalf("shell's tty_nr %d, terminal's device %d", s.TTY, term.tty)
	}
}

// ttyNr lays a device number out as the kernel's new_encode_dev does.
func TestTTYNr(t *testing.T) {
	for _, tc := range []struct {
		major, minor uint32
		want         int32
	}{
		{136, 0, 34816},                 // /dev/pts/0
		{136, 1, 34817},                 // /dev/pts/1
		{4, 1, 1025},                    // /dev/tty1
		{136, 300, 1<<20 | 136<<8 | 44}, // a minor past 255: its high bits (256) above the major
		{0, 0, 0},
	} {
		if got := ttyNr(tc.major, tc.minor); got != tc.want {
			t.Errorf("ttyNr(%d, %d) = %d, want %d", tc.major, tc.minor, got, tc.want)
		}
	}
}

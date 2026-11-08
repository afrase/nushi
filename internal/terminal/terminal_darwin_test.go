package terminal

import (
	"os/exec"
	"slices"
	"strconv"
	"strings"
	"testing"
)

// No process started after a terminal holds its master: it could type
// into the terminal.
func TestLaterProcessesDontGetTheTerminal(t *testing.T) {
	term, _ := shell(t)
	out, err := exec.Command("/bin/ls", "/dev/fd").Output()
	if err != nil {
		t.Fatal(err)
	}
	if fd := strconv.Itoa(int(term.pty.Fd())); slices.Contains(strings.Fields(string(out)), fd) {
		t.Errorf("a later process has the master (fd %s): %s", fd, out)
	}
}

package footprint

import (
	"os"
	"syscall"
	"testing"
)

// Another user's process isn't read: init's (root's), whose status any
// user can read but whose smaps_rollup only its user (or root) can.
func TestOfAnotherUsers(t *testing.T) {
	fi, err := os.Stat("/proc/1")
	if err != nil {
		t.Skipf("no init to look at: %v", err)
	}
	if st, ok := fi.Sys().(*syscall.Stat_t); os.Getuid() == 0 || ok && int(st.Uid) == os.Getuid() {
		t.Skip("init is readable here: the tests run as root, or as init's user (a container)")
	}
	if Of(1) != 0 {
		t.Error("read init's footprint")
	}
}

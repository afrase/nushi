//go:build unix

package servers

import (
	"os"
	"path/filepath"
	"strconv"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/testcheck"
)

// gone says whether pid has ended (or is a zombie no one waits for).
func gone(pid int) bool {
	if syscall.Kill(pid, 0) != nil {
		return true
	}
	p, err := proctree.Tree{}.Get(pid)
	return err != nil || p.Pid == 0
}

// A child that setsid out of the server's terminal ends with it.
func TestStopEndsAChildThatLeftTheTerminal(t *testing.T) {
	pidFile := filepath.Join(t.TempDir(), "child")
	s, _, _ := setup(t, entry("web", freePort(t), "-child", pidFile))
	_, err := s.Start(t.Context(), "c", Pick{Name: "web"})
	testcheck.NoErr(t, err)
	r := row(t, s, "web", Running)
	b, err := os.ReadFile(pidFile)
	testcheck.NoErr(t, err)
	child, _ := strconv.Atoi(string(b))
	defer syscall.Kill(child, syscall.SIGKILL) //nolint:errcheck // in case the test fails
	if gone(child) {
		t.Fatal("the child didn't start")
	}
	testcheck.NoErr(t, s.Stop("c", r.ServerID))
	if !testcheck.Eventually(func() bool { return gone(child) }) {
		t.Error("the child that left the terminal still runs")
	}
}

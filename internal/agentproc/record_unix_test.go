//go:build unix

package agentproc

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"syscall"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/testcheck"
)

// What a clean stop would end is what is recorded, so a sweep of the
// record after a crash ends the agent's group and leaves a background
// command, which leads a group of its own as Claude's and Ante's do and
// outlives a stop (ADR 0032, 0130).
func TestARecordedSweepLeavesABackgroundCommand(t *testing.T) {
	defer func(d time.Duration) { proctree.Grace = d }(proctree.Grace)
	proctree.Grace = 100 * time.Millisecond
	exe, err := os.Executable()
	testcheck.NoErr(t, err)
	// $0 is this test binary, which leaves the group and becomes sleep 102.
	a, err := Start(exec.Command("/bin/sh", "-c", `sleep 101 & `+ownGroupEnv+`=102 "$0" & wait`, exe), quiet{}, nil)
	testcheck.NoErr(t, err)
	t.Cleanup(func() { _ = a.Close() })
	var member, command model.Process
	testcheck.Wait(t, "the agent's two sleeps", func() bool {
		below, err := proctree.Tree{}.Under(a.Pid())
		testcheck.NoErr(t, err)
		for _, p := range below {
			switch {
			case slices.Equal(p.Args, []string{"sleep", "101"}):
				member = p
			case slices.Equal(p.Args, []string{"sleep", "102"}):
				command = p
			}
		}
		return member.Pid != 0 && command.Pid != 0
	})
	t.Cleanup(func() {
		if command.Pid > 1 { // its own group, which only this test made
			_ = syscall.Kill(-command.Pid, syscall.SIGKILL)
		}
	})
	self, err := proctree.Tree{}.Get(a.Pid())
	testcheck.NoErr(t, err)
	var ends []model.Process
	for _, p := range []model.Process{self, member, command} {
		if a.StopEnds(p) {
			ends = append(ends, p)
		}
	}
	if len(ends) != 2 || ends[1].Pid != member.Pid {
		t.Fatalf("a stop ends %+v, want the agent and sleep 101", ends)
	}
	path := filepath.Join(t.TempDir(), "processes.json")
	proctree.NewRecord(path).Put("agent", ends)
	proctree.Sweep(path) // as the next daemon does after a crash
	<-a.Done()
	testcheck.Wait(t, "sleep 101 to end with the agent's group", func() bool { return errors.Is(syscall.Kill(member.Pid, 0), syscall.ESRCH) })
	if err := syscall.Kill(command.Pid, 0); err != nil {
		t.Errorf("the background command was ended: %v", err)
	}
}

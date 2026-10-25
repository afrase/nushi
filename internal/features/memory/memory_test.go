package memory

import (
	"os/exec"
	"testing"
	"time"
)

type chats map[string]int

func (c chats) AgentPids() map[string]int { return c }

// The test is the daemon: one child is a chat's agent, the other a
// terminal.
func TestReport(t *testing.T) {
	var pids []int
	for range 2 {
		cmd := exec.Command("sleep", "5")
		if err := cmd.Start(); err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { _ = cmd.Process.Kill() })
		pids = append(pids, cmd.Process.Pid)
	}
	// A process just started still grows as it loads: read until the two
	// readings of the second (as the app, and as another child) agree.
	var r Report
	for range 50 {
		var err error
		if r, err = New(chats{"c1": pids[0]}).Report(pids[1]); err != nil {
			t.Fatal(err)
		}
		if r.App == r.Other {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if r.Daemon == 0 || r.Chats["c1"] == 0 || r.Other == 0 || r.App != r.Other {
		t.Errorf("%+v", r)
	}
}

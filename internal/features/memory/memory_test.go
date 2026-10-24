package memory

import (
	"os/exec"
	"testing"
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
		defer cmd.Process.Kill()
		pids = append(pids, cmd.Process.Pid)
	}
	r, err := New(chats{"c1": pids[0]}).Report(pids[1])
	if err != nil {
		t.Fatal(err)
	}
	if r.Daemon == 0 || r.Chats["c1"] == 0 || r.Other == 0 || r.App != r.Other {
		t.Errorf("%+v", r)
	}
}

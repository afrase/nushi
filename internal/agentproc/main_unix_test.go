//go:build unix

package agentproc

import (
	"os"
	"os/exec"
	"syscall"
	"testing"
)

// ownGroupEnv, set to a number of seconds, makes this test binary lead a
// process group of its own and become `sleep <seconds>`: a background
// command as Claude's and Ante's start theirs. A shell's job control
// (`set -m`) can't be counted on for that: dash without a terminal, CI's
// /bin/sh on Linux, turns it off and leaves the job in the shell's group.
const ownGroupEnv = "NUSHI_TEST_OWN_GROUP_SLEEP"

func TestMain(m *testing.M) {
	if n := os.Getenv(ownGroupEnv); n != "" {
		sleep, err := exec.LookPath("sleep")
		if err != nil || syscall.Setpgid(0, 0) != nil {
			os.Exit(2)
		}
		_ = syscall.Exec(sleep, []string{"sleep", n}, nil)
		os.Exit(2)
	}
	m.Run()
}

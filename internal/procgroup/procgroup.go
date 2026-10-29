// Package procgroup bounds a command run under a context to its process
// group: when the context ends, what the command started goes with it,
// and a process left holding its output can't keep the run waiting.
package procgroup

import (
	"os/exec"
	"syscall"
	"time"
)

// Bound has cmd, made by exec.CommandContext, start in a process group of
// its own (or in the session it asked for with Setsid, whose group is its
// own too), killed whole when its context ends; Wait then gives what it
// left running a second to let go of its stdout and stderr.
func Bound(cmd *exec.Cmd) {
	if cmd.SysProcAttr == nil {
		cmd.SysProcAttr = &syscall.SysProcAttr{}
	}
	if !cmd.SysProcAttr.Setsid {
		cmd.SysProcAttr.Setpgid = true
	}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	cmd.WaitDelay = time.Second
}

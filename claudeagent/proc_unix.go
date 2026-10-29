//go:build unix

package claudeagent

import (
	"os"
	"os/exec"
	"syscall"
)

// ownGroup has cmd run in a process group of its own.
func ownGroup(cmd *exec.Cmd) {
	if cmd.SysProcAttr == nil {
		cmd.SysProcAttr = &syscall.SysProcAttr{}
	}
	cmd.SysProcAttr.Setpgid = true
}

// signalGroup sends sig to cmd's process group.
func signalGroup(cmd *exec.Cmd, sig os.Signal) error {
	s, ok := sig.(syscall.Signal)
	if !ok {
		return cmd.Process.Signal(sig)
	}
	return syscall.Kill(-cmd.Process.Pid, s)
}

// killGroup kills cmd's process group.
func killGroup(cmd *exec.Cmd) error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }

// exitSignal is the signal that killed the process, or nil.
func exitSignal(ee *exec.ExitError) os.Signal {
	if ws, ok := ee.Sys().(syscall.WaitStatus); ok && ws.Signaled() {
		return ws.Signal()
	}
	return nil
}

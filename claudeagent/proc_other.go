//go:build !unix

package claudeagent

import (
	"os"
	"os/exec"
)

// ownGroup does nothing: process groups are Unix's.
func ownGroup(*exec.Cmd) {}

// signalGroup sends sig to cmd's process; the processes it started are left.
func signalGroup(cmd *exec.Cmd, sig os.Signal) error { return cmd.Process.Signal(sig) }

// killGroup does nothing: without a group, what claude left can't be found.
func killGroup(*exec.Cmd) error { return nil }

// exitSignal is nil: only Unix says which signal ended a process.
func exitSignal(*exec.ExitError) os.Signal { return nil }

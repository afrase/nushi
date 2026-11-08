//go:build !darwin && !linux

package terminal

import "os"

// On another OS (ADR 0097) what runs on a terminal isn't read: Close hangs
// up only the program it started, and no process has a name.

// device isn't read on this OS.
func device(*os.File) (int32, error) { return 0, nil }

// name is "" on this OS.
func name(int) string { return "" }

// onTerminal is only the terminal's own program on this OS.
func (t *Terminal) onTerminal() []int { return []int{t.cmd.Process.Pid} }

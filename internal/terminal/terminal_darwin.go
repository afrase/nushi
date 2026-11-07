package terminal

import (
	"os"

	"golang.org/x/sys/unix"
)

// device is the terminal's device number, which what runs on it has as
// its tty.
func device(tty *os.File) (int32, error) {
	var st unix.Stat_t
	err := unix.Fstat(int(tty.Fd()), &st)
	return st.Rdev, err
}

// name returns a process's name, or "".
func name(pid int) string {
	if p, err := unix.SysctlKinfoProc("kern.proc.pid", pid); err == nil {
		return unix.ByteSliceToString(p.Proc.P_comm[:])
	}
	return ""
}

// onTerminal lists the processes on t's terminal (sysctl's kern.proc.tty).
func (t *Terminal) onTerminal() []int {
	var pids []int
	if procs, err := unix.SysctlKinfoProcSlice("kern.proc.tty", int(t.tty)); err == nil {
		for _, p := range procs {
			pids = append(pids, int(p.Proc.P_pid))
		}
	}
	return pids
}

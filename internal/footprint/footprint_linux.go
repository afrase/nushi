package footprint

import (
	"errors"
	"io/fs"

	"github.com/afrase/nushi/internal/procfs"
)

// Of returns the memory process pid takes in bytes: its proportional set
// size and its swapped-out share (smaps_rollup's Pss and SwapPss). Pss
// splits each shared page among the processes mapping it, so Tree's sum
// over a tree counts a page its processes share once. A kernel without
// smaps_rollup (before 4.14) gives the resident and swapped sizes
// instead (status's VmRSS and VmSwap). 0 when it can't be read: gone, or
// another user's (smaps_rollup needs the right to trace the process,
// which only its user has; status is open to all, so it isn't read then).
func Of(pid int) uint64 {
	b, err := procfs.ReadFile(pid, "smaps_rollup")
	if err == nil {
		n, _ := sumKB(b, "Pss", "SwapPss")
		return n
	}
	if !errors.Is(err, fs.ErrNotExist) {
		return 0
	}
	if b, err = procfs.ReadFile(pid, "status"); err != nil {
		return 0
	}
	n, _ := sumKB(b, "VmRSS", "VmSwap")
	return n
}

// Snapshot lists the running processes, from each one's stat in /proc.
func Snapshot() (Processes, error) {
	ss := procfs.All()
	if len(ss) == 0 {
		return nil, errors.New("listing processes: /proc can't be read")
	}
	p := Processes{}
	for _, s := range ss {
		p[s.Ppid] = append(p[s.Ppid], s.Pid)
	}
	return p, nil
}

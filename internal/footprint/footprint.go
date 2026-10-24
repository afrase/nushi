// Package footprint reads how much memory processes take on macOS: their
// physical footprint (phys_footprint), what Activity Monitor shows as
// Memory. It needs no cgo: proc_pid_rusage is the proc_info system call,
// and the process list is sysctl's kern.proc.all.
package footprint

import (
	"unsafe"

	"golang.org/x/sys/unix"
)

const (
	procInfoCallPidRusage = 9 // PROC_INFO_CALL_PIDRUSAGE
	rusageInfoV0          = 0 // RUSAGE_INFO_V0
	physFootprint         = 9 // ri_phys_footprint's place in rusage_info_v0, in uint64s
)

// Of returns the footprint of the process pid in bytes, or 0 when it can't
// be read (gone, or another user's).
func Of(pid int) uint64 {
	var info [12]uint64 // rusage_info_v0: a 16-byte uuid, then ten counters
	_, _, errno := unix.Syscall6(unix.SYS_PROC_INFO, procInfoCallPidRusage, uintptr(pid), rusageInfoV0, 0, uintptr(unsafe.Pointer(&info)), 0)
	if errno != 0 {
		return 0
	}
	return info[physFootprint]
}

// Processes is a snapshot of which process started which.
type Processes map[int][]int // children by parent

// Snapshot lists the running processes.
func Snapshot() (Processes, error) {
	all, err := unix.SysctlKinfoProcSlice("kern.proc.all")
	if err != nil {
		return nil, err
	}
	p := Processes{}
	for _, k := range all {
		p[int(k.Eproc.Ppid)] = append(p[int(k.Eproc.Ppid)], int(k.Proc.P_pid))
	}
	return p, nil
}

// Tree returns the footprint of pid and every process under it.
func (p Processes) Tree(pid int) uint64 {
	n := Of(pid)
	for _, child := range p[pid] {
		if child != pid { // the kernel's own process 0 is its own parent
			n += p.Tree(child)
		}
	}
	return n
}

// Children returns the processes pid started.
func (p Processes) Children(pid int) []int { return p[pid] }

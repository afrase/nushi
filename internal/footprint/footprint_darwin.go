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
	var info [12]uint64                                                                                                                       // rusage_info_v0: a 16-byte uuid, then ten counters
	_, _, errno := unix.Syscall6(unix.SYS_PROC_INFO, procInfoCallPidRusage, uintptr(pid), rusageInfoV0, 0, uintptr(unsafe.Pointer(&info)), 0) //nolint:staticcheck,gosec // proc_pid_rusage without cgo: libSystem's wrapper needs it
	if errno != 0 {
		return 0
	}
	return info[physFootprint]
}

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

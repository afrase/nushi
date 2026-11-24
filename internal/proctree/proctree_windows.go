package proctree

import (
	"errors"
	"fmt"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

// On Windows (ADR 0132) who started whom, and when, is the system's
// process list, read whole in one call (NtQuerySystemInformation's
// SystemProcessInformation): no process is opened to list it, so it is
// cheap enough for a terminal's look at its foreground after each input
// or output, and tells the start of every process, another user's
// included. A command line is the system's own
// copy (NtQueryInformationProcess), readable for the user's own
// processes. Windows has no process groups: Pgid is 0, so StopGroup stops
// none (signal_windows.go).

// all is every process, with its parent and its start time. Windows keeps
// a process's parent id after the parent has ended, and may give the id
// to another: a parent that started after its child isn't its parent, and
// the child is left with none.
func all() ([]proc, error) {
	buf, err := processList()
	if err != nil {
		return nil, fmt.Errorf("listing processes: %w", err)
	}
	var ps []proc
	for off := uintptr(0); ; {
		e := (*windows.SYSTEM_PROCESS_INFORMATION)(unsafe.Add(unsafe.Pointer(&buf[0]), off)) //nolint:gosec // an entry the system wrote at this offset
		ps = append(ps, proc{Pid: int(e.UniqueProcessID), Started: fileTime(e.CreateTime), ppid: int(e.InheritedFromUniqueProcessID)})
		if e.NextEntryOffset == 0 {
			break
		}
		off += uintptr(e.NextEntryOffset)
	}
	return parented(ps), nil
}

// processList is SystemProcessInformation's entries, in a buffer grown
// while the list outgrows it (it can grow between the calls).
func processList() ([]uint64, error) {
	size := uint32(512 << 10)
	for range 5 {
		buf := make([]uint64, size/8+1)                                                                              // aligned for the entries' 64-bit fields
		n := uint32(len(buf) * 8)                                                                                    //nolint:gosec // a few megabytes at most
		err := windows.NtQuerySystemInformation(windows.SystemProcessInformation, unsafe.Pointer(&buf[0]), n, &size) //nolint:gosec // the system fills buf, n bytes
		if err == nil {
			return buf, nil
		}
		if !errors.Is(err, windows.STATUS_INFO_LENGTH_MISMATCH) {
			return nil, err
		}
		size += 64 << 10 // room for processes started meanwhile
	}
	return nil, errors.New("the process list kept growing")
}

// fileTime is a FILETIME count (100 ns since 1601) as a time, the zero
// time for none (the idle process's).
func fileTime(t int64) time.Time {
	if t == 0 {
		return time.Time{}
	}
	ft := windows.Filetime{LowDateTime: uint32(t), HighDateTime: uint32(t >> 32)} //nolint:gosec // its two halves
	return time.Unix(0, ft.Nanoseconds())
}

// parented drops each parent id that names a process started after its
// child: an id used again.
func parented(ps []proc) []proc {
	start := make(map[int]time.Time, len(ps))
	for _, p := range ps {
		start[p.Pid] = p.Started
	}
	for i, p := range ps {
		if s, ok := start[p.ppid]; ok && !s.IsZero() && !p.Started.IsZero() && s.After(p.Started) {
			ps[i].ppid = -1
		}
	}
	return ps
}

// Args reads a process's command line as Windows split it for the
// program's C runtime, nil when it can't be read (it ended, or it isn't
// the user's).
func Args(pid int) []string {
	if pid <= 0 {
		return nil
	}
	h, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, uint32(pid)) //nolint:gosec // a pid fits
	if err != nil {
		return nil
	}
	defer windows.CloseHandle(h) //nolint:errcheck // read only
	var n uint32
	_ = windows.NtQueryInformationProcess(h, windows.ProcessCommandLineInformation, nil, 0, &n) // its size
	if n < uint32(unsafe.Sizeof(windows.NTUnicodeString{})) {
		return nil
	}
	buf := make([]uint64, (n+7)/8)                                                                                          // aligned for the UNICODE_STRING it starts with
	if windows.NtQueryInformationProcess(h, windows.ProcessCommandLineInformation, unsafe.Pointer(&buf[0]), n, &n) != nil { //nolint:gosec // the system fills buf, n bytes
		return nil
	}
	line := (*windows.NTUnicodeString)(unsafe.Pointer(&buf[0])).String() //nolint:gosec // buf starts with the UNICODE_STRING the system wrote
	if line == "" {
		return []string{}
	}
	args, err := windows.DecomposeCommandLine(line)
	if err != nil {
		return nil
	}
	return args
}

// now is the time in Started's terms, the wall clock's.
func now() time.Time { return time.Now() }

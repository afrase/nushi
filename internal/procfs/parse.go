package procfs

import (
	"bytes"
	"errors"
	"fmt"
	"strconv"
	"time"
)

// Stat is what /proc/<pid>/stat says of a process (proc_pid_stat(5)).
type Stat struct {
	Pid, Ppid int
	Pgid      int // its process group (pgrp)
	Session   int
	TTY       int // its controlling terminal's device number (tty_nr), 0 for none
	State     byte
	Comm      string // the executable's name, at most 15 bytes, any of them
	Started   time.Time
}

// userHZ is the unit of stat's times. It is fixed at 100 in the Linux
// ABI whatever the kernel's own tick rate, and without cgo there is no
// sysconf(_SC_CLK_TCK) to ask.
const userHZ = 100

// parseStat reads a stat line. comm runs from the first '(' to the last
// ')': it may hold spaces and parentheses itself, the fields after it
// never do. Started is boot plus the start time's ticks, as procps
// computes ps's lstart, so the same process always gets the same time.
func parseStat(b []byte, boot time.Time) (Stat, error) {
	open, end := bytes.IndexByte(b, '('), bytes.LastIndexByte(b, ')')
	if open < 0 || end < open {
		return Stat{}, errors.New("stat: no (comm)")
	}
	pid, err := strconv.Atoi(string(bytes.TrimSpace(b[:open])))
	if err != nil {
		return Stat{}, fmt.Errorf("stat: pid: %w", err)
	}
	// After comm: state(3) ppid(4) pgrp(5) session(6) tty_nr(7) … starttime(22).
	f := bytes.Fields(b[end+1:])
	if len(f) < 20 || len(f[0]) != 1 {
		return Stat{}, fmt.Errorf("stat of %d: %d fields after comm", pid, len(f))
	}
	var n [4]int
	for i := range n {
		if n[i], err = strconv.Atoi(string(f[1+i])); err != nil {
			return Stat{}, fmt.Errorf("stat of %d: field %d: %w", pid, 4+i, err)
		}
	}
	ticks, err := strconv.ParseUint(string(f[19]), 10, 63)
	if err != nil {
		return Stat{}, fmt.Errorf("stat of %d: starttime: %w", pid, err)
	}
	return Stat{
		Pid: pid, Ppid: n[0], Pgid: n[1], Session: n[2], TTY: n[3],
		State: f[0][0], Comm: string(b[open+1 : end]),
		Started: boot.Add(time.Duration(ticks) * (time.Second / userHZ)),
	}, nil
}

// parseBootTime reads btime, when the system booted in seconds since the
// epoch, from /proc/stat.
func parseBootTime(b []byte) (time.Time, error) {
	for line := range bytes.Lines(b) {
		v, ok := bytes.CutPrefix(line, []byte("btime "))
		if !ok {
			continue
		}
		s, err := strconv.ParseInt(string(bytes.TrimSpace(v)), 10, 64)
		if err != nil {
			return time.Time{}, fmt.Errorf("/proc/stat: btime: %w", err)
		}
		return time.Unix(s, 0), nil
	}
	return time.Time{}, errors.New("/proc/stat: no btime")
}

// splitCmdline splits /proc/<pid>/cmdline: each argument ends with a NUL,
// so an empty first argument is a leading NUL and is kept. A process
// that rewrote its arguments (setproctitle) may leave no NUL at the end;
// the last argument then runs to the end.
func splitCmdline(b []byte) []string {
	if len(b) == 0 {
		return []string{}
	}
	b = bytes.TrimSuffix(b, []byte{0})
	args := bytes.Split(b, []byte{0})
	out := make([]string, len(args))
	for i, a := range args {
		out[i] = string(a)
	}
	return out
}

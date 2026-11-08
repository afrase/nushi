package proctree

import (
	"errors"

	"github.com/afrase/nushi/internal/procfs"
)

// all lists every process /proc lets the user read, from each one's stat.
// A zombie is left out: it has ended, only its parent hasn't reaped it
// yet, so it can't be stopped and must not count as what is left of a
// group (killRest) or as a process still running (Stop, Get). A list
// without even this process means /proc couldn't be read: an error, so
// nothing reads as ended because of it.
func all() ([]proc, error) {
	ss := procfs.All()
	if len(ss) == 0 {
		return nil, errors.New("listing processes: /proc can't be read")
	}
	ps := make([]proc, 0, len(ss))
	for _, s := range ss {
		if s.State == 'Z' || s.State == 'X' {
			continue
		}
		ps = append(ps, proc{ppid: s.Ppid, Pid: s.Pid, Pgid: s.Pgid, Started: s.Started})
	}
	return ps, nil
}

// Args reads a process's command line from /proc/<pid>/cmdline, nil when
// it can't be read (it ended, or the system hides it), empty for a
// kernel thread's.
func Args(pid int) []string {
	args, _ := procfs.Cmdline(pid)
	return args
}

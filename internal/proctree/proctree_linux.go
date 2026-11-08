package proctree

import (
	"errors"
	"sync"
	"time"

	"golang.org/x/sys/unix"

	"github.com/afrase/nushi/internal/procfs"
)

// readBoot reads the boot time; a test puts a moving clock in its place.
var readBoot = procfs.BootTime

// booted is the boot time this process counts every Started from, read
// once and kept: btime is the wall clock less the time since boot, so a
// step of the clock (timesyncd after a resume, a VM's time sync,
// settimeofday) moves it, and a Started read from it anew would change
// for every process, which then no longer reads as "the same" to Stop,
// StopGroup and servers' tree (ADR 0098). Kept, a process's Started
// stays put for the daemon's life, as P_starttime does on the Mac. A
// reboot, which would make it wrong, ends the daemon first.
var booted struct {
	sync.Mutex
	at time.Time
}

func boot() (time.Time, error) {
	booted.Lock()
	defer booted.Unlock()
	if booted.at.IsZero() {
		at, err := readBoot()
		if err != nil {
			return time.Time{}, err
		}
		booted.at = at
	}
	return booted.at, nil
}

// now is the time in Started's terms: the kept boot time plus the boot
// clock (CLOCK_BOOTTIME, which stat's start times count on), so killRest
// compares a Started with the moment of its SIGTERM on one clock, which
// no step moves between them. time.Now when either can't be read.
func now() time.Time {
	at, err := boot()
	var ts unix.Timespec
	if err != nil || unix.ClockGettime(unix.CLOCK_BOOTTIME, &ts) != nil {
		return time.Now()
	}
	return at.Add(time.Duration(ts.Nano()))
}

// all lists every process /proc lets the user read, from each one's stat,
// each Started counted from the kept boot time. A zombie is left out: it
// has ended, only its parent hasn't reaped it yet, so it can't be stopped
// and must not count as what is left of a group (killRest) or as a
// process still running (Stop, Get). A list without even this process
// means /proc couldn't be read: an error, so nothing reads as ended
// because of it.
func all() ([]proc, error) {
	at, err := boot()
	if err != nil {
		return nil, err
	}
	ss := procfs.AllFrom(at)
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
// kernel thread's or a zombie's. A live process of the user's reads empty
// too for a moment in the middle of an exec, before the kernel has set up
// the new program's arguments (some hundred microseconds under Rosetta),
// and terminal's Foreground would take that for its prompt, so such a
// read is tried again for up to execWait.
func Args(pid int) []string {
	for end := time.Now().Add(execWait); ; {
		args, ok := procfs.Cmdline(pid)
		if !ok || len(args) > 0 || !execing(pid) || time.Now().After(end) {
			return args
		}
		time.Sleep(execWait / 50)
	}
}

// execWait is how long Args waits for an exec's arguments.
const execWait = 20 * time.Millisecond

// execing says whether a process with no arguments could be in an exec:
// not a zombie and not a kernel thread (kthreadd, pid 2, and its
// children).
func execing(pid int) bool {
	s, err := procfs.ReadStat(pid)
	return err == nil && s.State != 'Z' && s.State != 'X' && s.Pid != 2 && s.Ppid != 2
}

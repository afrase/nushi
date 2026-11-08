package claudehistory

import (
	"time"

	"github.com/afrase/nushi/internal/procfs"
)

// started is when process pid started, from its stat in /proc: boot time
// plus its start, as ps's lstart (a record's procStart) computes it.
func started(pid int) (time.Time, bool) {
	s, err := procfs.ReadStat(pid)
	if err != nil {
		return time.Time{}, false
	}
	return s.Started, true
}

// domain is the pidDomain Claude Code writes on Linux: "darwin:", the
// machine id, ":" and its pid namespace (/proc/self/ns/pid's link), each
// empty when it can't be read (docs/facts/claude.md). A record's pid
// names a process here only when its domain is this one.
func domain() string {
	return "darwin:" + procfs.MachineID() + ":" + procfs.PidNamespace()
}

// stepSlack is how far a record's procStart may be from the process's
// start and still be it. Both are btime plus the start on the boot clock,
// but each with btime as it was at its read, and a step of the wall clock
// in between (timesyncd after a resume, a VM's or WSL's time sync after
// the host slept, which can be minutes) moves btime by the step: equal to
// the second, a live Claude would read as another process holding its
// pid, and its session could be resumed here while it still writes the
// transcript (docs/facts/claude.md). A pid used again within minutes of
// the first one's start, after it crashed and left its record, is far
// rarer: Linux hands pids out in order up to pid_max.
const stepSlack = 5 * time.Minute

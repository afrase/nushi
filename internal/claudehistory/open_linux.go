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

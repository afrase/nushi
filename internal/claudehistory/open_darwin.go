package claudehistory

import (
	"time"

	"golang.org/x/sys/unix"
)

// started is when process pid started, from sysctl's kern.proc.pid.
func started(pid int) (time.Time, bool) {
	p, err := unix.SysctlKinfoProc("kern.proc.pid", pid)
	if err != nil || p.Proc.P_pid != int32(pid) { //nolint:gosec // a pid
		return time.Time{}, false
	}
	t := p.Proc.P_starttime
	return time.Unix(t.Sec, int64(t.Usec)*1000), true
}

// domain is the pidDomain Claude Code writes on macOS
// (docs/facts/claude.md).
func domain() string { return "darwin" }

// stepSlack is how far a record's procStart may be from the process's
// start and still be it: none, since P_starttime is fixed at fork, so ps
// gives Claude the same second Nushi reads.
const stepSlack time.Duration = 0

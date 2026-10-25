package claudehistory

import (
	"cmp"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"

	"golang.org/x/sys/unix"
)

// Open returns the sessions a running Claude Code holds open (any, not
// only ids), by session id: "a terminal" for the CLI run by hand, "another
// app" for one a client such as another ACP client started. Each running
// CLI writes <config>/sessions/<pid>.json (its session id, entrypoint, the
// process's start time); claude-agent-acp's own session list reads them
// too, by the same rules: the process is alive, and started when the record
// says, so a pid used again doesn't count; a record without a start time
// counts for a day.
func Open(_ []string) map[string]string {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil
	}
	return open(filepath.Join(cmp.Or(os.Getenv("CLAUDE_CONFIG_DIR"), filepath.Join(home, ".claude")), "sessions"), started)
}

var record = regexp.MustCompile(`^(\d+)\.json$`)

func open(dir string, startedAt func(pid int) (time.Time, bool)) map[string]string {
	names, _ := os.ReadDir(dir)
	out := map[string]string{}
	for _, n := range names {
		m := record.FindStringSubmatch(n.Name())
		if m == nil || !n.Type().IsRegular() {
			continue
		}
		pid, _ := strconv.Atoi(m[1])
		var r struct {
			Pid        int    `json:"pid"`
			SessionID  string `json:"sessionId"`
			ProcStart  string `json:"procStart"`
			Entrypoint string `json:"entrypoint"`
			Domain     string `json:"pidDomain"`
			Updated    int64  `json:"updatedAt"`
			Started    int64  `json:"startedAt"`
			StatusTime int64  `json:"statusUpdatedAt"`
		}
		b, err := os.ReadFile(filepath.Join(dir, n.Name()))
		if err != nil || json.Unmarshal(b, &r) != nil || r.Pid != pid || r.SessionID == "" || r.Domain != "" && r.Domain != "darwin" || !alive(pid) {
			continue
		}
		start, known := startedAt(pid)
		recorded, err := time.ParseInLocation("Mon Jan 2 15:04:05 2006", strings.Join(strings.Fields(r.ProcStart), " "), time.UTC)
		switch {
		case err == nil && known && !recorded.Equal(start.Truncate(time.Second)):
			continue // another process has the pid now
		case err != nil && time.Since(time.UnixMilli(max(r.Updated, r.Started, r.StatusTime))) > 24*time.Hour:
			continue
		}
		out[r.SessionID] = "another app"
		if r.Entrypoint == "cli" { // an ACP client's CLI says "sdk-cli" (its kind is "interactive" too)
			out[r.SessionID] = "a terminal"
		}
	}
	return out
}

// alive says whether a process runs with pid (one of another user's
// counts).
func alive(pid int) bool {
	err := syscall.Kill(pid, 0)
	return err == nil || errors.Is(err, syscall.EPERM)
}

// started is when process pid started, from sysctl's kern.proc.pid.
func started(pid int) (time.Time, bool) {
	p, err := unix.SysctlKinfoProc("kern.proc.pid", pid)
	if err != nil || p.Proc.P_pid != int32(pid) { //nolint:gosec // a pid
		return time.Time{}, false
	}
	t := p.Proc.P_starttime
	return time.Unix(t.Sec, int64(t.Usec)*1000), true
}

package omp

import (
	"bufio"
	"cmp"
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/afrase/nushi/internal/filelock"
)

// Forked says which of sessions ids are forks of another session: the
// session record near a session file's start names parentSession. Files
// are <agent dir>/sessions/<folder>/<time>_<id>.jsonl, the agent dir being
// $PI_CODING_AGENT_DIR or ~/.omp/agent.
func Forked(ids []string) map[string]bool {
	home, _ := os.UserHomeDir()
	return forked(filepath.Join(cmp.Or(os.Getenv("PI_CODING_AGENT_DIR"), filepath.Join(home, ".omp", "agent")), "sessions"), ids)
}

func forked(sessions string, ids []string) map[string]bool {
	out := map[string]bool{}
	dirs, _ := os.ReadDir(sessions)
	for _, d := range dirs {
		files, _ := os.ReadDir(filepath.Join(sessions, d.Name()))
		for _, f := range files {
			for _, id := range ids {
				if f.Type().IsRegular() && strings.HasSuffix(f.Name(), "_"+id+".jsonl") && hasParent(filepath.Join(sessions, d.Name(), f.Name())) {
					out[id] = true
				}
			}
		}
	}
	return out
}

// hasParent reads a session file's first records for its header.
func hasParent(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	sc.Buffer(nil, 4<<20)
	for i := 0; i < 4 && sc.Scan(); i++ {
		var h struct{ Type, ParentSession string }
		if json.Unmarshal(sc.Bytes(), &h) == nil && h.Type == "session" {
			return h.ParentSession != ""
		}
	}
	return false
}

// OpenElsewhere says which of sessions ids an omp holds: omp lets one
// process at a time own a session, holding a lock on
// ~/.omp/run/session-owners/<id>.lock; another that writes to it moves to
// a new session of its own (a terminal's says so). The lock is looked at,
// never taken. With omp's XDG layout the folder is elsewhere, and this
// sees nothing.
func OpenElsewhere(ids []string) map[string]string {
	home, _ := os.UserHomeDir()
	return held(filepath.Join(home, ".omp", "run", "session-owners"), ids)
}

var sessionID = regexp.MustCompile(`^[A-Za-z0-9_-]{1,128}$`)

func held(dir string, ids []string) map[string]string {
	out := map[string]string{}
	for _, id := range ids {
		if sessionID.MatchString(id) && filelock.Held(filepath.Join(dir, id+".lock")) {
			out[id] = "another app"
		}
	}
	return out
}

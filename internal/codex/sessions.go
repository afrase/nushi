package codex

import (
	"bufio"
	"cmp"
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/afrase/nushi/internal/filelock"
)

// OpenElsewhere says which of sessions ids a Codex holds open: Codex lets
// one app at a time write to a thread, holding a lock on
// $CODEX_HOME/thread-writer-locks/<id>.lock while it has the thread; a
// second app gets the thread read-only (the CLI) or refused (codex-acp's
// session/load: "in use by another Codex client"). The lock is looked at
// (F_GETLK), never taken.
func OpenElsewhere(ids []string) map[string]string {
	home, _ := os.UserHomeDir()
	return held(filepath.Join(cmp.Or(os.Getenv("CODEX_HOME"), filepath.Join(home, ".codex")), "thread-writer-locks"), ids)
}

var threadID = regexp.MustCompile(`^[0-9A-Za-z-]+$`)

func held(dir string, ids []string) map[string]string {
	out := map[string]string{}
	for _, id := range ids {
		if threadID.MatchString(id) && filelock.Held(filepath.Join(dir, id+".lock")) {
			out[id] = "another app"
		}
	}
	return out
}

// Forked says which of sessions ids are forks of another thread: a
// rollout's first record (session_meta) names forked_from_id. Rollouts are
// $CODEX_HOME/sessions/YYYY/MM/DD/rollout-<time>-<id>.jsonl.
func Forked(ids []string) map[string]bool {
	home, _ := os.UserHomeDir()
	return forked(filepath.Join(cmp.Or(os.Getenv("CODEX_HOME"), filepath.Join(home, ".codex")), "sessions"), ids)
}

func forked(sessions string, ids []string) map[string]bool {
	want := map[string]bool{}
	for _, id := range ids {
		want[id] = true
	}
	out := map[string]bool{}
	filepath.WalkDir(sessions, func(path string, d fs.DirEntry, err error) error {
		if err != nil { // d is nil when sessions can't be read
			return nil //nolint:nilerr // what can't be read is skipped; the walk goes on
		}
		name := d.Name()
		if !d.Type().IsRegular() || !strings.HasPrefix(name, "rollout-") || !strings.HasSuffix(name, ".jsonl") {
			return nil
		}
		id := strings.TrimSuffix(name, ".jsonl")
		if len(id) < 36 || !want[id[len(id)-36:]] {
			return nil
		}
		var meta struct {
			Payload struct {
				ForkedFrom string `json:"forked_from_id"`
			} `json:"payload"`
		}
		if json.Unmarshal(firstLine(path), &meta) == nil && meta.Payload.ForkedFrom != "" {
			out[id[len(id)-36:]] = true
		}
		return nil
	})
	return out
}

// firstLine is a file's first line (Codex's session_meta holds the whole
// system prompt: tens of KB).
func firstLine(path string) []byte {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	sc.Buffer(nil, 4<<20)
	sc.Scan()
	return sc.Bytes()
}

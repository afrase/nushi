package ante

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// OpenElsewhere says which of sessions ids an Ante holds open: Ante takes
// no lock, but keeps a session's events.jsonl open for writing while it
// has the session (its TUI, or a host of another bridge), so lsof finds
// it, in about a tenth of a second. Two Antes on one session both append
// to it.
func OpenElsewhere(ids []string) map[string]string {
	var files []string
	for _, id := range ids {
		if isSessionID(id) {
			if f := filepath.Join(Home(), "sessions", id, "events.jsonl"); fileExists(f) {
				files = append(files, f)
			}
		}
	}
	return openFiles(files, func(f string) string { return filepath.Base(filepath.Dir(f)) })
}

// openFiles runs lsof on files and returns the id (of) of each one some
// process has open.
func openFiles(files []string, of func(file string) string) map[string]string {
	out := map[string]string{}
	if len(files) == 0 {
		return out
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	// -F n prints a line "n<path>" per open file; lsof exits 1 when one of
	// the files isn't open, so the output counts, not the status.
	b, _ := exec.CommandContext(ctx, "/usr/sbin/lsof", append([]string{"-w", "-F", "n", "--"}, files...)...).Output()
	for line := range strings.Lines(string(b)) {
		if name, ok := strings.CutPrefix(strings.TrimSpace(line), "n"); ok {
			for _, f := range files {
				if real, _ := filepath.EvalSymlinks(f); name == f || name == real {
					out[of(f)] = "another app"
				}
			}
		}
	}
	return out
}

func fileExists(path string) bool {
	fi, err := os.Stat(path)
	return err == nil && fi.Mode().IsRegular()
}

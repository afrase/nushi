package ante

import (
	"os"
	"path/filepath"
)

// OpenElsewhere says which of sessions ids an Ante holds open: Ante takes
// no lock, but keeps a session's events.jsonl open for writing while it
// has the session (its TUI, or a host of another bridge), so lsof finds
// it on the Mac, in about a tenth of a second, as do the links of its
// open files in /proc on Linux. Two Antes on one session both append to
// it.
func (Local) OpenElsewhere(ids []string) map[string]string {
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

func fileExists(path string) bool {
	fi, err := os.Stat(path)
	return err == nil && fi.Mode().IsRegular()
}

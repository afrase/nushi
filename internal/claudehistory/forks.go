package claudehistory

import (
	"bufio"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
)

// Forked says which of sessions ids are forks of another session (their
// first records carry forkedFrom, as Claude writes it for --fork-session
// and an ACP session/fork), looking for each transcript in every folder's
// history.
func Forked(projects string, ids []string) map[string]bool {
	want := map[string]bool{}
	for _, id := range ids {
		want[id+".jsonl"] = true
	}
	out := map[string]bool{}
	dirs, _ := os.ReadDir(projects)
	for _, d := range dirs {
		if !d.IsDir() {
			continue
		}
		files, _ := os.ReadDir(filepath.Join(projects, d.Name()))
		for _, f := range files {
			if want[f.Name()] && f.Type().IsRegular() && forked(filepath.Join(projects, d.Name(), f.Name())) {
				out[strings.TrimSuffix(f.Name(), ".jsonl")] = true
			}
		}
	}
	return out
}

// forked reads a transcript's first records for forkedFrom.
func forked(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	sc.Buffer(nil, 4<<20)
	for i := 0; i < 8 && sc.Scan(); i++ {
		var r struct {
			ForkedFrom json.RawMessage `json:"forkedFrom"`
		}
		if json.Unmarshal(sc.Bytes(), &r) == nil && len(r.ForkedFrom) > 0 && string(r.ForkedFrom) != "null" {
			return true
		}
	}
	return false
}

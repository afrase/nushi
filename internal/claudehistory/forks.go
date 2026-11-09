package claudehistory

import (
	"bufio"
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
)

// Forked says which of sessions ids are forks of another session (their
// first records carry forkedFrom, as Claude writes it for --fork-session
// and an ACP session/fork), looking for each transcript in every folder's
// history.
func (l Local) Forked(ids []string) map[string]bool {
	want := map[string]bool{}
	for _, id := range ids {
		want[id+".jsonl"] = true
	}
	out := map[string]bool{}
	dirs, _ := os.ReadDir(l.Projects)
	for _, d := range dirs {
		if !d.IsDir() {
			continue
		}
		files, _ := os.ReadDir(filepath.Join(l.Projects, d.Name()))
		for _, f := range files {
			if want[f.Name()] && f.Type().IsRegular() && forked(filepath.Join(l.Projects, d.Name(), f.Name())) {
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
	defer f.Close() //nolint:errcheck // read-only
	sc := bufio.NewScanner(f)
	sc.Buffer(nil, 4<<20)
	for i := 0; i < forkLines && sc.Scan(); i++ {
		if forkRecord(sc.Bytes()) {
			return true
		}
	}
	return false
}

// forkLines is how many of a transcript's first records may say it's a
// fork.
const forkLines = 8

// forkRecord says a transcript's record names the session it was forked
// from.
func forkRecord(line []byte) bool {
	if !bytes.Contains(line, []byte(`"forkedFrom"`)) {
		return false
	}
	var r struct {
		ForkedFrom json.RawMessage `json:"forkedFrom"`
	}
	return json.Unmarshal(line, &r) == nil && len(r.ForkedFrom) > 0 && string(r.ForkedFrom) != "null"
}

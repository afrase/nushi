package claudehistory

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/afrase/claude-acp-go/claudeagent/sessions"
)

// Forked says which of sessions ids are forks of another session (their
// first records carry forkedFrom, as Claude writes it for --fork-session
// and an ACP session/fork), looking for each transcript in every folder's
// history: Claude's list's own reading of it (sessions.Info.ForkedFrom).
func (l Local) Forked(ids []string) map[string]bool {
	want := map[string]bool{}
	for _, id := range ids {
		want[id+".jsonl"] = true
	}
	out := map[string]bool{}
	projects := l.projects()
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

// forked says the transcript at path is a fork's.
func forked(path string) bool {
	info, err := sessions.ReadInfo(path)
	return err == nil && info.ForkedFrom != nil
}

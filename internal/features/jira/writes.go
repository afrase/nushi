package jira

import (
	"log/slog"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// keptWrites is how many of the agents' writes are kept.
const keptWrites = 2000

// wrote keeps a write an agent made, for the issue view to say whose it
// was; failing to keep it is logged, not the agent's problem. The store
// orders the file's writes (AppendJiraWrite), so s.mu, which every list
// and issue takes, isn't held across the rewrite.
func (s *Service) wrote(w model.JiraWrite) {
	w.At = time.Now()
	if err := s.store.AppendJiraWrite(w, keptWrites); err != nil {
		slog.Error("keeping an agent's Jira write", "err", err)
	}
}

// Writes are the writes agents made to an issue, the latest last.
func (s *Service) Writes(id, key string) []model.JiraWrite {
	all, err := s.store.JiraWrites()
	if err != nil {
		slog.Error("reading the agents' Jira writes", "err", err)
	}
	var out []model.JiraWrite
	for _, w := range all {
		if w.Site == id && w.Key == key {
			out = append(out, w)
		}
	}
	return out
}

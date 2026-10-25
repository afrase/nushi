package jira

import (
	"log/slog"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// keptWrites is how many of the agents' writes are kept.
const keptWrites = 2000

// wrote keeps a write an agent made, for the issue view to say whose it
// was; failing to keep it is logged, not the agent's problem.
func (s *Service) wrote(w model.JiraWrite) {
	w.At = time.Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	all, err := s.store.JiraWrites()
	if err == nil {
		all = append(all, w)
		err = s.store.SaveJiraWrites(all[max(0, len(all)-keptWrites):])
	}
	if err != nil {
		slog.Error("keeping an agent's Jira write", "err", err)
	}
}

// Writes are the writes agents made to an issue, the latest last.
func (s *Service) Writes(id, key string) []model.JiraWrite {
	s.mu.Lock()
	defer s.mu.Unlock()
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

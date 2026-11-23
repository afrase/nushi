package store

import (
	"path/filepath"

	"github.com/afrase/nushi/internal/model"
)

// JiraSites are the Jira sites added, in jira.json (0600; the tokens are
// in the keychain).
func (s *Store) JiraSites() ([]model.JiraSite, error) {
	var sites []model.JiraSite
	_, err := s.read("jira.json", &sites)
	return sites, err
}

func (s *Store) SaveJiraSites(sites []model.JiraSite) error { return s.write("jira.json", sites) }

// JiraWrites are the writes agents made to Jira through their tools, in
// jira-writes.json, the latest last.
func (s *Store) JiraWrites() ([]model.JiraWrite, error) {
	s.jiraWritesMu.Lock()
	defer s.jiraWritesMu.Unlock()
	var w []model.JiraWrite
	_, err := readJSON(filepath.Join(s.dir, "jira-writes.json"), &w)
	return w, err
}

// AppendJiraWrite adds w to jira-writes.json, keeping the latest keep, in
// one read-modify-write under its own lock (jiraWritesMu), so two writes at
// once both land and the rewrite holds up no other file. A file that can't
// be read isn't written over.
func (s *Store) AppendJiraWrite(w model.JiraWrite, keep int) error {
	s.jiraWritesMu.Lock()
	defer s.jiraWritesMu.Unlock()
	path := filepath.Join(s.dir, "jira-writes.json")
	var all []model.JiraWrite
	if _, err := readJSON(path, &all); err != nil {
		return err
	}
	all = append(all, w)
	return writeJSON(path, all[max(0, len(all)-keep):])
}

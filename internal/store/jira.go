package store

import "github.com/afrase/nushi/internal/model"

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
	var w []model.JiraWrite
	_, err := s.read("jira-writes.json", &w)
	return w, err
}

func (s *Store) SaveJiraWrites(w []model.JiraWrite) error { return s.write("jira-writes.json", w) }

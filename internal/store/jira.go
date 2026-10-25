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

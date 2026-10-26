package store

// GitHubTokenHosts are the hosts given a token in Settings › GitHub, in
// github.json (0600; the tokens are in the keychain).
func (s *Store) GitHubTokenHosts() ([]string, error) {
	var hosts []string
	_, err := s.read("github.json", &hosts)
	return hosts, err
}

func (s *Store) SaveGitHubTokenHosts(hosts []string) error { return s.write("github.json", hosts) }

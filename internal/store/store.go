// Package store keeps the daemon's small state on disk, as JSON files.
package store

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"sync"
)

// Store keeps its files in one folder.
type Store struct {
	dir string
	mu  sync.Mutex
}

func New(dir string) *Store { return &Store{dir: dir} }

type agentPrefs struct {
	Mode string `json:"mode,omitempty"`
}

// Mode returns the mode last picked for agent, or "" for the agent's default.
func (s *Store) Mode(agent string) string {
	s.mu.Lock()
	defer s.mu.Unlock()
	prefs, _ := s.agents()
	return prefs[agent].Mode
}

// SetMode remembers mode as the one last picked for agent.
func (s *Store) SetMode(agent, mode string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	prefs, err := s.agents()
	if err != nil {
		return err
	}
	prefs[agent] = agentPrefs{Mode: mode}
	return writeJSON(filepath.Join(s.dir, "agents.json"), prefs)
}

func (s *Store) agents() (map[string]agentPrefs, error) {
	prefs := map[string]agentPrefs{}
	b, err := os.ReadFile(filepath.Join(s.dir, "agents.json"))
	if errors.Is(err, fs.ErrNotExist) {
		return prefs, nil
	}
	if err != nil {
		return prefs, err
	}
	return prefs, json.Unmarshal(b, &prefs)
}

// writeJSON replaces path with v, atomically.
func writeJSON(path string, v any) error {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

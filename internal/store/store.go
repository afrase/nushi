// Package store keeps the daemon's small state on disk, as JSON files.
package store

import (
	"encoding/json"
	"errors"
	"io/fs"
	"log"
	"net/url"
	"os"
	"path/filepath"
	"sync"

	"github.com/afrase/nushi/internal/model"
)

// Store keeps its files in one folder.
type Store struct {
	dir string
	mu  sync.Mutex
	// HadMessages says whether the agent's history of a session stored
	// before sessions said so has messages.
	HadMessages func(model.Session) bool
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

// SaveSession writes a session's file, replacing any earlier one.
func (s *Store) SaveSession(sess model.Session) error {
	dir := filepath.Join(s.dir, "sessions")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	return writeJSON(filepath.Join(dir, url.PathEscape(sess.ID)+".json"), sess)
}

// DeleteSession removes a session's file.
func (s *Store) DeleteSession(id string) error {
	return os.Remove(filepath.Join(s.dir, "sessions", url.PathEscape(id)+".json"))
}

// Sessions reads every stored session.
func (s *Store) Sessions() ([]model.Session, error) {
	files, err := filepath.Glob(filepath.Join(s.dir, "sessions", "*.json"))
	if err != nil {
		return nil, err
	}
	var out []model.Session
	for _, f := range files {
		var sess model.Session
		var flags struct{ HasMessages *bool }
		b, err := os.ReadFile(f)
		if err == nil {
			err = json.Unmarshal(b, &sess)
		}
		if err == nil {
			err = json.Unmarshal(b, &flags)
		}
		if err != nil { // one bad file doesn't hide the other chats
			log.Printf("skipping session file %s: %v", f, err)
			continue
		}
		if sess.SessionID == "" { // stored before step 22, when the ids were one
			sess.SessionID = sess.ID
		}
		if flags.HasMessages == nil { // stored before step 59
			sess.HasMessages = sess.Title != "" || s.HadMessages != nil && s.HadMessages(sess)
		}
		out = append(out, sess)
	}
	return out, nil
}

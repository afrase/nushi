// Package store keeps the daemon's small state on disk, as JSON files.
package store

import (
	"encoding/json"
	"errors"
	"io/fs"
	"log/slog"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"

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

// TrustedFolders returns the folders the user started chats in anyway.
func (s *Store) TrustedFolders() ([]string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.trusted()
}

// TrustFolder remembers a folder the user started chats in anyway.
func (s *Store) TrustFolder(folder string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	folders, err := s.trusted()
	if err != nil || slices.Contains(folders, folder) {
		return err
	}
	return writeJSON(filepath.Join(s.dir, "trusted.json"), append(folders, folder))
}

func (s *Store) trusted() ([]string, error) {
	var folders []string
	b, err := os.ReadFile(filepath.Join(s.dir, "trusted.json"))
	if errors.Is(err, fs.ErrNotExist) {
		return nil, nil
	}
	if err == nil {
		err = json.Unmarshal(b, &folders)
	}
	return folders, err
}

// writeJSON replaces path with v, atomically, and durably: the new file's
// data is on disk before it takes path's place (a crash right after a
// rename can otherwise leave an empty file), and so is the rename.
func writeJSON(path string, v any) error {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	f, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	_, err = f.Write(b)
	if err == nil {
		err = f.Sync() // F_FULLFSYNC on macOS
	}
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		err = os.Rename(tmp, path)
	}
	if err != nil {
		os.Remove(tmp)
		return err
	}
	if dir, err := os.Open(filepath.Dir(path)); err == nil {
		dir.Sync()
		dir.Close()
	}
	return nil
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
	entries, err := os.ReadDir(filepath.Join(s.dir, "sessions")) // not a glob: the folder may hold a pattern's characters
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, err
	}
	var out []model.Session
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		f := filepath.Join(s.dir, "sessions", e.Name())
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
			slog.Warn("skipping a chat file", "file", f, "err", err)
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

// settings are the daemon's own settings (settings.json).
type settings struct {
	SleepAfterMinutes *int `json:"sleepAfterMinutes,omitempty"`
}

// defaultSleepAfter is how long chats idle before they sleep, until the
// user picks another time.
const defaultSleepAfter = 30 * time.Minute

// SleepAfter returns how long a chat idles before its agent sleeps; 0:
// never.
func (s *Store) SleepAfter() time.Duration {
	s.mu.Lock()
	defer s.mu.Unlock()
	var set settings
	b, err := os.ReadFile(filepath.Join(s.dir, "settings.json"))
	if err == nil {
		err = json.Unmarshal(b, &set)
	}
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		slog.Warn("reading settings.json", "err", err)
	}
	if set.SleepAfterMinutes == nil {
		return defaultSleepAfter
	}
	return time.Duration(*set.SleepAfterMinutes) * time.Minute
}

// SetSleepAfter remembers how long a chat idles before its agent sleeps.
func (s *Store) SetSleepAfter(d time.Duration) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	m := int(d / time.Minute)
	return writeJSON(filepath.Join(s.dir, "settings.json"), settings{SleepAfterMinutes: &m})
}

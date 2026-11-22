// Package store keeps the daemon's small state on disk, as JSON files.
package store

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"sync"

	"github.com/afrase/nushi/internal/atomicfile"
	"github.com/afrase/nushi/internal/model"
)

// Store keeps its files in one folder.
type Store struct {
	dir string
	mu  sync.Mutex
	set *settings // settings.json as read or last written; nil until read
	// setErr is why settings.json last couldn't be read (EACCES, EIO),
	// kept only so the log says it once; such a read is never kept in set.
	setErr error
	// cacheMu keeps the cache's files apart from mu: a cache file's rewrite
	// doesn't hold up the settings, which chats read under their lock.
	cacheMu sync.Mutex
	// sessMu keeps the sessions apart from mu too: reading them all the
	// first time doesn't hold up the settings.
	sessMu   sync.Mutex
	sessions map[string]model.ChatRecord // by file name; nil until read
	// unreadable are the ids of the chats whose files didn't read, as the
	// folder was read (Unreadable).
	unreadable []string
	// asides are the remote access files set aside as they were read, by
	// name, as the name each was set aside as (SetAside).
	asides map[string]string
}

func New(dir string) *Store { return &Store{dir: dir} }

type agentPrefs struct {
	Mode  string            `json:"mode,omitempty"`
	Picks map[string]string `json:"picks,omitempty"` // the model, the effort, ... by option ID
	// Commands is the slash commands the agent last listed.
	Commands []model.Command `json:"commands,omitempty"`
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
	return s.changeAgent(agent, func(p *agentPrefs) { p.Mode = mode })
}

// Picks returns the other options last picked for agent (the model, the
// effort, ...), by option ID.
func (s *Store) Picks(agent string) map[string]string {
	s.mu.Lock()
	defer s.mu.Unlock()
	prefs, _ := s.agents()
	return prefs[agent].Picks
}

// SetPick remembers value as the one last picked for agent's option id.
func (s *Store) SetPick(agent, id, value string) error {
	return s.changeAgent(agent, func(p *agentPrefs) {
		if p.Picks == nil {
			p.Picks = map[string]string{}
		}
		p.Picks[id] = value
	})
}

// Commands returns the slash commands agent last listed.
func (s *Store) Commands(agent string) []model.Command {
	s.mu.Lock()
	defer s.mu.Unlock()
	prefs, _ := s.agents()
	return prefs[agent].Commands
}

// SetCommands remembers commands as the ones agent listed last.
func (s *Store) SetCommands(agent string, commands []model.Command) error {
	return s.changeAgent(agent, func(p *agentPrefs) { p.Commands = commands })
}

func (s *Store) changeAgent(agent string, change func(*agentPrefs)) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	path := filepath.Join(s.dir, "agents.json")
	prefs, err := s.agents()
	if err != nil {
		return fmt.Errorf("agents.json can't be read, so it isn't written over: %w", err)
	}
	p := prefs[agent]
	change(&p)
	prefs[agent] = p
	return writeJSON(path, prefs)
}

// agents reads agents.json; never a nil map, so a change can be made in
// it even when the file holds null.
func (s *Store) agents() (map[string]agentPrefs, error) {
	var prefs map[string]agentPrefs
	_, err := readJSON(filepath.Join(s.dir, "agents.json"), &prefs)
	if prefs == nil {
		prefs = map[string]agentPrefs{}
	}
	return prefs, err
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
	_, err := readJSON(filepath.Join(s.dir, "trusted.json"), &folders)
	return folders, err
}

// writeJSON replaces path with v, 0600, at once and durably (atomicfile).
func writeJSON(path string, v any) error {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	return atomicfile.Replace(path, b, 0o600)
}

// readJSON reads path into v; false when there's no file, which is no
// error: a file not written yet is the empty state. A file that doesn't
// parse, or whose whole value is of another shape, is set aside
// (setAside) and reads as the empty state too, so a later write replaces
// nothing unread; a value of another shape inside it (a newer build's,
// read going back: ADR 0108) reads as not set, and the rest is kept
// (decodeKeeping). A file that can't be read at all is an error.
func readJSON(path string, v any) (bool, error) {
	b, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	dropped, err := decodeKeeping(b, v) // v is left as it was when set aside
	if err != nil {
		_, err := setAside(path, err)
		return false, err
	}
	if len(dropped) > 0 {
		slog.Warn("values of another shape read as not set", "file", filepath.Base(path), "fields", dropped)
	}
	return true, nil
}

// readWhole reads path into v as readJSON does, but a value of another
// shape anywhere sets the file aside too: a key or a pairing missing a
// field would half work. It returns the name the file was set aside as,
// or "". A file that can't be read at all (permissions, I/O) is an error,
// as in readJSON, and stays where it is: setting aside a file that may be
// fine would cost every phone its pairing for a passing fault.
func readWhole(path string, v any) (ok bool, aside string, err error) {
	b, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return false, "", nil
	}
	if err != nil {
		return false, "", err
	}
	dropped, err := decodeKeeping(b, v)
	if err == nil && len(dropped) > 0 {
		reflect.ValueOf(v).Elem().SetZero()
		err = fmt.Errorf("values of another shape: %v", dropped)
	}
	if err != nil {
		aside, err := setAside(path, err)
		return false, aside, err
	}
	return true, "", nil
}

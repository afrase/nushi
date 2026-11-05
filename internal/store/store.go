// Package store keeps the daemon's small state on disk, as JSON files.
package store

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
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
	// cacheMu keeps the cache's files apart from mu: a cache file's rewrite
	// doesn't hold up the settings, which chats read under their lock.
	cacheMu sync.Mutex
	// sessMu keeps the sessions apart from mu too: reading them all the
	// first time doesn't hold up the settings.
	sessMu   sync.Mutex
	sessions map[string]model.ChatRecord // by file name; nil until read
	// HadMessages says whether the agent's history of a session stored
	// before sessions said so has messages.
	HadMessages func(model.ChatRecord) bool
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
	prefs, err := s.agents()
	if err != nil {
		return err
	}
	p := prefs[agent]
	change(&p)
	prefs[agent] = p
	return writeJSON(filepath.Join(s.dir, "agents.json"), prefs)
}

func (s *Store) agents() (map[string]agentPrefs, error) {
	prefs := map[string]agentPrefs{}
	_, err := readJSON(filepath.Join(s.dir, "agents.json"), &prefs)
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
// error: a file not written yet is the empty state.
func readJSON(path string, v any) (bool, error) {
	b, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, json.Unmarshal(b, v)
}

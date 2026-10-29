// Package store keeps the daemon's small state on disk, as JSON files.
package store

import (
	"encoding/json"
	"errors"
	"io/fs"
	"log/slog"
	"maps"
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
	set *settings // settings.json as read or last written; nil until read
	// cacheMu keeps the cache's files apart from mu: a cache file's rewrite
	// doesn't hold up the settings, which chats read under their lock.
	cacheMu sync.Mutex
	// sessMu keeps the sessions apart from mu too: reading them all the
	// first time doesn't hold up the settings.
	sessMu   sync.Mutex
	sessions map[string]model.Session // by file name; nil until read
	// HadMessages says whether the agent's history of a session stored
	// before sessions said so has messages.
	HadMessages func(model.Session) bool
}

func New(dir string) *Store { return &Store{dir: dir} }

type agentPrefs struct {
	Mode  string            `json:"mode,omitempty"`
	Picks map[string]string `json:"picks,omitempty"` // the model, the effort, ... by option ID
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
	b, err := os.ReadFile(filepath.Join(s.dir, "agents.json"))
	if errors.Is(err, fs.ErrNotExist) {
		return prefs, nil
	}
	if err != nil {
		return prefs, err
	}
	err = json.Unmarshal(b, &prefs)
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
		_ = os.Remove(tmp) // the write's error is the one to return
		return err
	}
	if dir, err := os.Open(filepath.Dir(path)); err == nil {
		_ = dir.Sync() // best effort: the rename is done
		_ = dir.Close()
	}
	return nil
}

// SaveSession writes a session's file, replacing any earlier one, and
// keeps it once written. A chat's saves come one at a time (under its
// lock), so what's kept is what its file has.
func (s *Store) SaveSession(sess model.Session) error {
	dir := filepath.Join(s.dir, "sessions")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	name := sessionFile(sess.ID)
	if err := writeJSON(filepath.Join(dir, name), sess); err != nil {
		return err
	}
	s.sessMu.Lock()
	defer s.sessMu.Unlock()
	if s.sessions != nil {
		s.sessions[name] = clone(sess)
	}
	return nil
}

// DeleteSession removes a session's file.
func (s *Store) DeleteSession(id string) error {
	name := sessionFile(id)
	err := os.Remove(filepath.Join(s.dir, "sessions", name))
	if err == nil || errors.Is(err, fs.ErrNotExist) {
		s.sessMu.Lock()
		delete(s.sessions, name)
		s.sessMu.Unlock()
	}
	return err
}

// sessionFile is the name of the file a session is kept in.
func sessionFile(id string) string { return url.PathEscape(id) + ".json" }

// Sessions returns every stored session, in their files' order. The
// folder is read the first time; after, the sessions are kept as they're
// saved (nothing else writes it while the daemon runs).
func (s *Store) Sessions() ([]model.Session, error) {
	s.sessMu.Lock()
	defer s.sessMu.Unlock()
	if s.sessions == nil {
		read, err := s.readSessions()
		if err != nil {
			return nil, err
		}
		s.sessions = read
	}
	var out []model.Session
	for _, name := range slices.Sorted(maps.Keys(s.sessions)) {
		out = append(out, clone(s.sessions[name]))
	}
	return out, nil
}

// readSessions reads every session's file, by its name.
func (s *Store) readSessions() (map[string]model.Session, error) {
	entries, err := os.ReadDir(filepath.Join(s.dir, "sessions")) // not a glob: the folder may hold a pattern's characters
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, err
	}
	read := map[string]model.Session{}
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		f := filepath.Join(s.dir, "sessions", e.Name())
		// HasMessages of its own, shallower, takes the file's in place of
		// the session's: nil says the file has none.
		var file struct {
			model.Session
			HasMessages *bool `json:"HasMessages"`
		}
		b, err := os.ReadFile(f)
		if err == nil {
			err = json.Unmarshal(b, &file)
		}
		if err != nil { // one bad file doesn't hide the other chats
			slog.Warn("skipping a chat file", "file", f, "err", err)
			continue
		}
		sess := file.Session
		if sess.SessionID == "" { // stored before step 22, when the ids were one
			sess.SessionID = sess.ID
		}
		if file.HasMessages != nil {
			sess.HasMessages = *file.HasMessages
		} else { // stored before step 59
			sess.HasMessages = sess.Title != "" || s.HadMessages != nil && s.HadMessages(sess)
		}
		read[e.Name()] = sess
	}
	return read, nil
}

// clone is sess sharing nothing with it: a session kept, or handed out,
// can't be changed through another copy's slice, map or pointer.
func clone(sess model.Session) model.Session {
	sess.Earlier = slices.Clone(sess.Earlier)
	sess.Worktree = copyOf(sess.Worktree)
	sess.EarlierWorktrees = slices.Clone(sess.EarlierWorktrees)
	sess.Throwaway = slices.Clone(sess.Throwaway)
	sess.Issue = copyOf(sess.Issue)
	sess.GitHub = copyOf(sess.GitHub)
	sess.Pull = copyOf(sess.Pull)
	sess.Picks = maps.Clone(sess.Picks)
	return sess
}

func copyOf[T any](p *T) *T {
	if p == nil {
		return nil
	}
	v := *p
	return &v
}

// settings are the daemon's own settings (settings.json).
type settings struct {
	SleepAfterMinutes *int  `json:"sleepAfterMinutes,omitempty"`
	DebugLog          bool  `json:"debugLog,omitempty"`
	KeepTranscripts   *bool `json:"keepTranscripts,omitempty"`
	TranscriptDays    int   `json:"transcriptDays,omitempty"`
	CheckUpdates      *bool `json:"checkUpdates,omitempty"`
}

// defaultSleepAfter is how long chats idle before they sleep, until the
// user picks another time.
const defaultSleepAfter = 30 * time.Minute

// settingsLocked is settings.json, read once and then kept (a hand edit
// while the daemon runs is seen at its next start); one that can't be
// read is as if empty.
func (s *Store) settingsLocked() settings {
	if s.set != nil {
		return *s.set
	}
	var set settings
	b, err := os.ReadFile(filepath.Join(s.dir, "settings.json"))
	if err == nil {
		err = json.Unmarshal(b, &set)
	}
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		slog.Warn("reading settings.json", "err", err)
	}
	s.set = &set
	return set
}

// changeSettings applies change to settings.json, and keeps the result
// once it's written.
func (s *Store) changeSettings(change func(*settings)) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	set := s.settingsLocked()
	change(&set)
	if err := writeJSON(filepath.Join(s.dir, "settings.json"), set); err != nil {
		return err
	}
	s.set = &set
	return nil
}

// SleepAfter returns how long a chat idles before its agent sleeps; 0:
// never.
func (s *Store) SleepAfter() time.Duration {
	s.mu.Lock()
	defer s.mu.Unlock()
	if m := s.settingsLocked().SleepAfterMinutes; m != nil {
		return time.Duration(*m) * time.Minute
	}
	return defaultSleepAfter
}

// SetSleepAfter remembers how long a chat idles before its agent sleeps.
func (s *Store) SetSleepAfter(d time.Duration) error {
	m := int(d / time.Minute)
	return s.changeSettings(func(set *settings) { set.SleepAfterMinutes = &m })
}

// DebugLog says whether the log has DEBUG lines (ADR 0038).
func (s *Store) DebugLog() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.settingsLocked().DebugLog
}

// SetDebugLog remembers whether the log has DEBUG lines.
func (s *Store) SetDebugLog(on bool) error {
	return s.changeSettings(func(set *settings) { set.DebugLog = on })
}

// KeepTranscripts says whether Nushi keeps its own copy of chats'
// transcripts (ADR 0047); on until turned off.
func (s *Store) KeepTranscripts() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	keep := s.settingsLocked().KeepTranscripts
	return keep == nil || *keep
}

// SetKeepTranscripts remembers whether Nushi keeps copies of transcripts.
func (s *Store) SetKeepTranscripts(on bool) error {
	return s.changeSettings(func(set *settings) { set.KeepTranscripts = &on })
}

// TranscriptDays is how many days a transcript's copy is kept after it
// was last written; 0: for good.
func (s *Store) TranscriptDays() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.settingsLocked().TranscriptDays
}

// SetTranscriptDays remembers how many days copies are kept; 0: for good.
func (s *Store) SetTranscriptDays(days int) error {
	return s.changeSettings(func(set *settings) { set.TranscriptDays = days })
}

// CheckUpdates says whether the daemon asks GitHub for a newer release;
// on until turned off.
func (s *Store) CheckUpdates() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	on := s.settingsLocked().CheckUpdates
	return on == nil || *on
}

// SetCheckUpdates remembers whether the daemon checks for a newer release.
func (s *Store) SetCheckUpdates(on bool) error {
	return s.changeSettings(func(set *settings) { set.CheckUpdates = &on })
}

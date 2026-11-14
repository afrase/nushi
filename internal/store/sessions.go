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

	"github.com/afrase/nushi/internal/model"
)

// SaveSession writes a session's file, replacing any earlier one, and
// keeps it once written. A chat's saves come one at a time (under its
// lock), so what's kept is what its file has.
func (s *Store) SaveSession(sess model.ChatRecord) error {
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
func (s *Store) Sessions() ([]model.ChatRecord, error) {
	s.sessMu.Lock()
	defer s.sessMu.Unlock()
	if s.sessions == nil {
		read, err := s.readSessions()
		if err != nil {
			return nil, err
		}
		s.sessions = read
	}
	var out []model.ChatRecord
	for _, name := range slices.Sorted(maps.Keys(s.sessions)) {
		out = append(out, clone(s.sessions[name]))
	}
	return out, nil
}

// readSessions reads every session's file, by its name.
func (s *Store) readSessions() (map[string]model.ChatRecord, error) {
	entries, err := os.ReadDir(filepath.Join(s.dir, "sessions")) // not a glob: the folder may hold a pattern's characters
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, err
	}
	read := map[string]model.ChatRecord{}
	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		f := filepath.Join(s.dir, "sessions", e.Name())
		// HasMessages of its own, shallower, takes the file's in place of
		// the session's: nil says the file has none.
		var file struct {
			model.ChatRecord
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
		sess := file.ChatRecord
		if sess.SessionID == "" { // stored when the chat's and its session's ids were one
			sess.SessionID = sess.ID
		}
		if file.HasMessages != nil {
			sess.HasMessages = *file.HasMessages
		} else { // stored before HasMessages was kept
			sess.HasMessages = sess.Title != "" || s.HadMessages != nil && s.HadMessages(sess)
		}
		// Pinned while the user's messages could be: only the agent's are
		// (ADR 0085's amendment). Saved so with the record's next change.
		sess.Pins = slices.DeleteFunc(sess.Pins, func(p model.MessagePin) bool { return p.Kind != model.AgentMessage })
		if len(sess.Pins) == 0 {
			sess.Pins = nil
		}
		read[e.Name()] = sess
	}
	return read, nil
}

// clone is sess sharing nothing with it: a session kept, or handed out,
// can't be changed through another copy's slice, map or pointer.
func clone(sess model.ChatRecord) model.ChatRecord {
	sess.Earlier = slices.Clone(sess.Earlier)
	sess.Worktree = copyOf(sess.Worktree)
	sess.EarlierWorktrees = slices.Clone(sess.EarlierWorktrees)
	sess.RelatedWorktrees = slices.Clone(sess.RelatedWorktrees)
	sess.Throwaway = slices.Clone(sess.Throwaway)
	sess.Issue = copyOf(sess.Issue)
	sess.GitHub = copyOf(sess.GitHub)
	sess.Pull = copyOf(sess.Pull)
	sess.Picks = maps.Clone(sess.Picks)
	sess.Pins = slices.Clone(sess.Pins)
	sess.SideOf = copyOf(sess.SideOf)
	return sess
}

func copyOf[T any](p *T) *T {
	if p == nil {
		return nil
	}
	v := *p
	return &v
}

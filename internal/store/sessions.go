package store

import (
	"encoding/json"
	"errors"
	"fmt"
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
	s.unreadable = slices.DeleteFunc(s.unreadable, func(id string) bool { return id == sess.ID })
	return nil
}

// DeleteSession removes a session's file.
func (s *Store) DeleteSession(id string) error {
	name := sessionFile(id)
	err := os.Remove(filepath.Join(s.dir, "sessions", name))
	if err == nil || errors.Is(err, fs.ErrNotExist) {
		s.sessMu.Lock()
		delete(s.sessions, name)
		s.unreadable = slices.DeleteFunc(s.unreadable, func(u string) bool { return u == id })
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
	if err := s.loadSessionsLocked(); err != nil {
		return nil, err
	}
	var out []model.ChatRecord
	for _, name := range slices.Sorted(maps.Keys(s.sessions)) {
		out = append(out, clone(s.sessions[name]))
	}
	return out, nil
}

// Unreadable returns the ids of the chats whose files couldn't be read or
// don't parse, sorted. Their files are left as they are (nothing writes
// over a chat it doesn't list), and the app keeps what it holds for them
// (ListChatsResponse.unreadable) until the file reads again.
func (s *Store) Unreadable() []string {
	s.sessMu.Lock()
	defer s.sessMu.Unlock()
	if s.loadSessionsLocked() != nil {
		return nil
	}
	return slices.Clone(s.unreadable)
}

// loadSessionsLocked reads the folder, the first time.
func (s *Store) loadSessionsLocked() error {
	if s.sessions != nil {
		return nil
	}
	read, unreadable, err := s.readSessions()
	if err != nil {
		return err
	}
	s.sessions, s.unreadable = read, unreadable
	return nil
}

// readSessions reads every session's file, by its name, and the ids of
// those that couldn't be read or don't parse. A record whose only fault is
// a field of another shape (a newer build's, read going back: ADR 0108)
// keeps its other fields.
func (s *Store) readSessions() (map[string]model.ChatRecord, []string, error) {
	entries, err := os.ReadDir(filepath.Join(s.dir, "sessions")) // not a glob: the folder may hold a pattern's characters
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, nil, err
	}
	read := map[string]model.ChatRecord{}
	var unreadable []string
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
		if shape := (*json.UnmarshalTypeError)(nil); errors.As(err, &shape) {
			slog.Warn("a chat file's field of another shape left out", "file", e.Name(), "field", shape.Field)
		} else if err != nil { // one bad file doesn't hide the other chats, nor gets them forgotten
			slog.Warn("a chat file that doesn't read", "file", e.Name(), "err", readFault(err))
			unreadable = append(unreadable, fileID(e.Name()))
			continue
		}
		sess := file.ChatRecord
		if sess.SessionID == "" { // stored when the chat's and its session's ids were one
			sess.SessionID = sess.ID
		}
		if file.HasMessages != nil {
			sess.HasMessages = *file.HasMessages
		} else { // stored before HasMessages was kept: a title says it had one
			sess.HasMessages = sess.Title != ""
		}
		// Pinned while the user's messages could be: only the agent's are
		// (ADR 0085's amendment). Saved so with the record's next change.
		sess.Pins = slices.DeleteFunc(sess.Pins, func(p model.MessagePin) bool { return p.Kind != model.AgentMessage })
		if len(sess.Pins) == 0 {
			sess.Pins = nil
		}
		read[e.Name()] = sess
	}
	slices.Sort(unreadable)
	return read, unreadable, nil
}

// fileID is the chat id a session's file is named for (sessionFile).
func fileID(name string) string {
	stem := strings.TrimSuffix(name, ".json")
	if id, err := url.PathUnescape(stem); err == nil {
		return id
	}
	return stem
}

// readFault is what the log says of a chat file that doesn't read: the
// read's error, or only where a parse failed, never the file's bytes.
func readFault(err error) any {
	if syntax := (*json.SyntaxError)(nil); errors.As(err, &syntax) {
		return fmt.Sprintf("doesn't parse at byte %d", syntax.Offset)
	}
	if path := (*fs.PathError)(nil); errors.As(err, &path) {
		return err // the read's: its path and why, no bytes
	}
	return "doesn't parse"
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
	sess.Pulls = slices.Clone(sess.Pulls)
	sess.NoPulls = slices.Clone(sess.NoPulls)
	sess.Pushed = slices.Clone(sess.Pushed)
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

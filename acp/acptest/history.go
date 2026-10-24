package acptest

import (
	"encoding/json"
	"fmt"
	"sync"
)

// History holds every session's updates by folder, for session/load, and
// the sessions deleted.
type History struct {
	mu       sync.Mutex
	sessions map[key][]json.RawMessage
	deleted  map[string]bool
}

// key is a session in one folder's history.
type key struct{ cwd, session string }

// Deleted reports whether session/delete was asked for session (one never
// kept, without a message, included).
func (h *History) Deleted(session string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.deleted[session]
}

func (h *History) add(cwd, session string, update any) {
	b, _ := json.Marshal(update)
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.sessions == nil {
		h.sessions = map[key][]json.RawMessage{}
	}
	k := key{cwd, session}
	h.sessions[k] = append(h.sessions[k], b)
}

// fork gives session to, in folder cwd, a copy of session from's history
// there; it fails when cwd's history has no from.
func (h *History) fork(cwd, from, to string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	u, ok := h.sessions[key{cwd, from}]
	if ok {
		h.sessions[key{cwd, to}] = append([]json.RawMessage(nil), u...)
	}
	return ok
}

// Copy copies session's history in folder from into folder to's, as the
// daemon does before forking a session in another folder (a
// chats.CopyHistory), and returns a function that removes the copy.
func (h *History) Copy(session, from, to string) (remove func() error, err error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	u, ok := h.sessions[key{from, session}]
	if !ok {
		return nil, fmt.Errorf("no session %s in %s", session, from)
	}
	if _, ok := h.sessions[key{to, session}]; ok {
		return nil, fmt.Errorf("session %s is in %s already", session, to)
	}
	h.sessions[key{to, session}] = append([]json.RawMessage(nil), u...)
	return func() error {
		h.mu.Lock()
		defer h.mu.Unlock()
		delete(h.sessions, key{to, session})
		return nil
	}, nil
}

// Has reports whether session is in the history, in any folder.
func (h *History) Has(session string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	for k := range h.sessions {
		if k.session == session {
			return true
		}
	}
	return false
}

// In reports whether session is in folder cwd's history.
func (h *History) In(cwd, session string) bool {
	_, ok := h.get(cwd, session)
	return ok
}

func (h *History) get(cwd, session string) ([]json.RawMessage, bool) {
	h.mu.Lock()
	defer h.mu.Unlock()
	u, ok := h.sessions[key{cwd, session}]
	return append([]json.RawMessage(nil), u...), ok
}

func (h *History) delete(session string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for k := range h.sessions {
		if k.session == session {
			delete(h.sessions, k)
		}
	}
	if h.deleted == nil {
		h.deleted = map[string]bool{}
	}
	h.deleted[session] = true
}

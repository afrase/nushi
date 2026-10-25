package acptest

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"
)

// History holds every session's updates by folder, for session/load, and
// the sessions deleted.
type History struct {
	mu       sync.Mutex
	sessions map[key][]json.RawMessage
	deleted  map[string]bool
	last     map[key]int // each session's last update, in order
	n        int
}

// key is a session in one folder's history, the folder by its real path,
// as Claude keeps it.
type key struct{ cwd, session string }

func keyOf(cwd, session string) key {
	if resolved, err := filepath.EvalSymlinks(cwd); err == nil {
		cwd = resolved
	}
	return key{cwd, session}
}

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
	k := keyOf(cwd, session)
	h.sessions[k] = append(h.sessions[k], b)
	if h.last == nil {
		h.last = map[key]int{}
	}
	h.n++
	h.last[k] = h.n
}

// list is session/list's answer from the history: the sessions in cwd
// (every folder's for ""), newest first, each titled with its first
// prompt, its last update one second after the one before it.
func (h *History) list(cwd string) []map[string]any {
	h.mu.Lock()
	defer h.mu.Unlock()
	var keys []key
	for k := range h.sessions {
		if cwd == "" || k.cwd == keyOf(cwd, "").cwd {
			keys = append(keys, k)
		}
	}
	slices.SortFunc(keys, func(a, b key) int { return h.last[b] - h.last[a] })
	var out []map[string]any
	for _, k := range keys {
		var first struct {
			Content struct{ Text string } `json:"content"`
		}
		for _, u := range h.sessions[k] {
			if strings.Contains(string(u), `"user_message_chunk"`) {
				json.Unmarshal(u, &first)
				break
			}
		}
		out = append(out, map[string]any{"sessionId": k.session, "cwd": k.cwd, "title": first.Content.Text,
			"updatedAt": time.Unix(1_800_000_000+int64(h.last[k]), 0).UTC().Format(time.RFC3339)})
	}
	return out
}

// fork gives session to, in folder cwd, a copy of session from's history
// there; it fails when cwd's history has no from.
func (h *History) fork(cwd, from, to string) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	u, ok := h.sessions[keyOf(cwd, from)]
	if ok {
		h.sessions[keyOf(cwd, to)] = append([]json.RawMessage(nil), u...)
	}
	return ok
}

// Copy copies session's history in folder from into folder to's, as the
// daemon does before forking a session in another folder (a
// chats.CopyHistory), and returns a function that removes the copy.
func (h *History) Copy(session, from, to string) (remove func() error, err error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	u, ok := h.sessions[keyOf(from, session)]
	if !ok {
		return nil, fmt.Errorf("no session %s in %s", session, from)
	}
	if _, ok := h.sessions[keyOf(to, session)]; ok {
		return nil, fmt.Errorf("session %s is in %s already", session, to)
	}
	h.sessions[keyOf(to, session)] = append([]json.RawMessage(nil), u...)
	return func() error {
		h.mu.Lock()
		defer h.mu.Unlock()
		delete(h.sessions, keyOf(to, session))
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
	u, ok := h.sessions[keyOf(cwd, session)]
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

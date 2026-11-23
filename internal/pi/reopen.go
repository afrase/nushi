package pi

import (
	"context"
	"fmt"
	"os"
	"sync"

	acp "github.com/afrase/acp-go/unstable"
)

// deadSession is a session whose pi died, to be opened again: where, and
// its file. mu is held while it opens, so it opens once.
type deadSession struct {
	mu        sync.Mutex
	cwd, file string
}

// died forgets a session whose pi died (not stopped by the bridge), and
// says whether the bridge ends with it. Another session still open keeps
// the bridge for it, and this one opens again on its file at its next
// prompt (live): the client still has it, and would otherwise get "no
// open session" for good. With none left, or no file to open, the bridge
// ends: the client then sees the agent quit and opens the chat again,
// through session/load, on a new bridge. It runs before the session's
// turn ends, so a prompt the client sends on that answer finds the
// session to open again.
func (b *bridge) died(s *session) (end bool) {
	s.mu.Lock()
	file := s.file
	s.mu.Unlock()
	saved := regular(file) // before the lock: it reads the disk
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.sessions[s.id] == s {
		delete(b.sessions, s.id)
	}
	if len(b.sessions) == 0 || !saved {
		return true
	}
	b.dead[s.id] = &deadSession{cwd: s.cwd, file: file}
	warnf("the program stopped; its session opens again at its next prompt")
	return false
}

// end ends the client's connection once a pi died, as died said. Serve
// stops what is left once the connection is done.
func (b *bridge) end() {
	warnf("the program stopped and no other session is open, so the bridge ends")
	_ = b.client.Close() // it says nothing that matters: the connection ends either way
}

// regular says file is a regular file (a session pi has saved).
func regular(file string) bool {
	fi, err := os.Stat(file)
	return file != "" && err == nil && fi.Mode().IsRegular()
}

// live is the open session id, opened again first if its pi died (died).
func (b *bridge) live(ctx context.Context, id acp.SessionID) (*session, error) {
	b.mu.Lock()
	d := b.dead[string(id)]
	b.mu.Unlock()
	if d == nil {
		return b.session(id)
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	b.mu.Lock()
	s, current := b.sessions[string(id)], b.dead[string(id)] == d
	b.mu.Unlock()
	if s != nil || !current { // opened meanwhile, or closed
		return b.session(id)
	}
	s, _, err := b.open(ctx, d.cwd, d.file, reopened)
	if err != nil {
		return nil, err
	}
	if s.id != string(id) {
		s.stop()
		return nil, fmt.Errorf("session %s opened again as %s", id, s.id)
	}
	b.mu.Lock()
	if b.dead[string(id)] == d {
		delete(b.dead, string(id))
	}
	b.mu.Unlock()
	return s, nil
}

// bury forgets a dead session the client closed or deleted, or loads.
func (b *bridge) bury(id acp.SessionID) {
	b.mu.Lock()
	defer b.mu.Unlock()
	delete(b.dead, string(id))
}

// isDead says the session's pi died, and its next prompt opens it again.
func (b *bridge) isDead(id acp.SessionID) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.dead[string(id)] != nil
}

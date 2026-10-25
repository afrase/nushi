package chats

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// lookup returns a chat, open or stored, without reopening it.
func (s *Service) lookup(id string) (*chat, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if c := s.chats[id]; c != nil {
		return c, nil
	}
	stored, err := s.sessions.Sessions()
	if err != nil {
		return nil, err
	}
	i := slices.IndexFunc(stored, func(sess model.Session) bool { return sess.ID == id })
	if i < 0 {
		return nil, fmt.Errorf("no chat %q", id)
	}
	k, err := s.kindOf(stored[i].Agent)
	if err != nil {
		return nil, err
	}
	c := s.newChat(k)
	c.id, c.sid, c.session, c.issue = id, stored[i].SessionID, stored[i], stored[i].Issue
	c.session.Scratch = s.isScratch(c.session.Folder)
	s.chats[id] = c
	return c, nil
}

// open returns a chat. A stored chat whose agent isn't running (the daemon
// restarted, or the chat was unarchived) is reopened in the background
// through session/load; it is busy until its history has been replayed.
// An archived chat stays as it is.
func (s *Service) open(id string) (*chat, error) {
	c, err := s.lookup(id)
	if err != nil {
		return nil, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	s.reopenLocked(c)
	return c, nil
}

// reopenLocked reopens a chat whose agent isn't running (never reopened,
// the last try failed, or the agent quit), unless it is archived, going or
// asleep.
func (s *Service) reopenLocked(c *chat) {
	if c.agent == nil && !c.busy && !c.session.Archived && !c.halting && c.parent == nil && !c.reopenFailed && !c.asleep {
		c.busy, c.woke = true, make(chan struct{})
		c.statusChangedLocked()
		go s.resume(c)
	}
}

// chat returns an open chat to work with: not an archived one.
func (s *Service) chat(id string) (*chat, error) {
	c, err := s.open(id)
	if err != nil {
		return nil, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.session.Archived || c.halting {
		return nil, c.closedLocked()
	}
	return c, nil
}

// reopenTimeout bounds a reopen: an agent that never answers (a stalled
// npx, an MCP server that hangs) mustn't leave the chat reopening for good.
var reopenTimeout = 2 * time.Minute

//nolint:contextcheck // a reopen runs on its own: every request waiting on the chat waits for it
func (s *Service) resume(c *chat) {
	ctx, cancel := context.WithTimeout(context.Background(), reopenTimeout)
	defer cancel()
	start := time.Now()
	err := s.load(ctx, c)
	c.mu.Lock()
	defer c.mu.Unlock()
	if log := c.logLocked().With("took", time.Since(start).Round(time.Millisecond)); err != nil {
		log.Warn("chat not reopened", "err", err)
	} else {
		log.Info("chat reopened")
	}
	c.busy = false
	if c.woke != nil {
		close(c.woke)
		c.woke = nil
	}
	if err != nil {
		c.reopenFailed = true // not again until a message, a reload or a move
		c.noticeLocked("error", "Couldn't reopen the chat: "+err.Error())
	}
	c.statusChangedLocked()
	c.deliverLocked()
}

// load starts the chat's agent and has it replay the session, then puts the
// session back in the mode it was last in. A chat that never had a message
// may have nothing to replay (Claude keeps a session only once it has one):
// it gets a new session instead.
func (s *Service) load(ctx context.Context, c *chat) error {
	c.mu.Lock()
	sid, folder, fresh, gone := c.sid, c.session.Folder, !c.session.HasMessages, folderGone(c.session)
	retired, before := c.retired, c.before
	c.retired, c.before = nil, nil
	c.mu.Unlock()
	if gone != nil {
		return gone
	}
	if retired != nil { // the agent it slept from may still be ending the session
		select {
		case <-retired:
		case <-time.After(2 * stopGrace):
		}
	}
	o, err := c.openSession(ctx, sid, folder, false)
	if err != nil && fresh {
		o, err = c.openSession(ctx, "", folder, false)
	}
	if err != nil {
		return err
	}
	c.mu.Lock()
	held := c.held // a queue held before (an archived chat's) stays held
	s.useLocked(c, o)
	c.held = held
	c.orphanLocked() // replayed calls whose agent died before their results
	if o.sid != sid {
		c.saveLocked(func(s *model.Session) { s.SessionID = o.sid })
	}
	mode, throwaway := c.session.Mode, slices.Clone(c.session.Throwaway)
	c.mu.Unlock()
	go s.discard(c, throwaway) //nolint:gosec // discarding outlives the request; left by an agent that stopped before it could
	c.restoreConfig(ctx, o.agent, o.sid, before)
	return c.startMode(ctx, o.agent, o.sid, mode)
}

// folderGone says why a chat can't run when its folder no longer exists
// (removed outside Nushi), or returns nil.
func folderGone(sess model.Session) error {
	if _, err := os.Stat(sess.Folder); !errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if wt := sess.Worktree; wt != nil {
		return fmt.Errorf("its worktree %s was removed outside Nushi; deleting the chat cleans up its branch %s", wt.Path, wt.Branch)
	}
	return fmt.Errorf("its folder %s is gone", sess.Folder)
}

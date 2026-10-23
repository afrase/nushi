package chats

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"slices"

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
	c := s.newChat()
	c.id, c.sid, c.session = id, stored[i].SessionID, stored[i]
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
// the last try failed, or the agent quit), unless it is archived or going.
func (s *Service) reopenLocked(c *chat) {
	if c.agent == nil && !c.busy && !c.session.Archived && !c.halting && c.parent == nil {
		c.busy = true
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

func (s *Service) resume(c *chat) {
	err := s.load(context.Background(), c)
	c.mu.Lock()
	defer c.mu.Unlock()
	c.busy = false
	if err != nil {
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
	c.mu.Unlock()
	if gone != nil {
		return gone
	}
	o, err := c.openSession(ctx, s.launch, sid, folder, false)
	if err != nil && fresh {
		o, err = c.openSession(ctx, s.launch, "", folder, false)
	}
	if err != nil {
		return err
	}
	c.mu.Lock()
	s.useLocked(c, o)
	c.kept = false
	if o.sid != sid {
		c.saveLocked(func(s *model.Session) { s.SessionID = o.sid })
	}
	mode := c.session.Mode
	c.mu.Unlock()
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

package chats

import (
	"context"
	"errors"
	"log"
	"slices"

	"github.com/afrase/nushi/internal/model"
)

// Move moves a chat to another folder. A chat without messages gets a new
// session there. A chat with messages gets a fork of its session there: the
// agent's record of the session is copied into the folder's history, forked
// with the folder as its cwd (a new session id, with the whole conversation),
// and the copy removed; the original stays in the old folder's history. The
// chat's agent keeps running until the new one is ready, so a move that fails
// leaves the chat where it was, with a notice saying why.
func (s *Service) Move(ctx context.Context, chatID, folder string) error {
	if err := checkFolder(folder); err != nil {
		return err
	}
	c, err := s.stored(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	from, sid, fresh := c.session.Folder, c.sid, c.session.Title == ""
	switch {
	case c.session.Archived:
		err = errors.New("the chat is archived")
	case c.busy:
		err = errors.New("the chat is busy; move it once the turn has ended")
	}
	if err != nil || from == folder {
		c.mu.Unlock()
		return err
	}
	c.busy = true
	c.statusChangedLocked()
	c.mu.Unlock()

	var o opened
	if fresh {
		o, err = c.openSession(ctx, s.launch, "", folder, false)
	} else {
		o, err = s.fork(ctx, c, sid, from, folder)
	}
	if err == nil {
		c.mu.Lock()
		old := c.agent
		c.useLocked(o)
		c.saveLocked(func(s *model.Session) {
			s.Earlier = append(slices.Clip(s.Earlier), model.AgentSession{ID: s.SessionID, Folder: s.Folder})
			s.Folder, s.SessionID = folder, o.sid
		})
		c.mu.Unlock()
		s.dropSides(c) // they ran on the old agent
		if old != nil {
			old.Close()
		}
		if err := c.startMode(ctx, c.session.Mode); err != nil {
			log.Printf("chat %s: mode after moving: %v", c.id, err)
		}
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.busy = false
	if err != nil {
		c.noticeLocked("error", "Couldn't move the chat to "+folder+": "+err.Error())
	}
	c.statusChangedLocked()
	return err
}

// fork starts an agent with a fork of session sid in folder to.
func (s *Service) fork(ctx context.Context, c *chat, sid, from, to string) (opened, error) {
	if s.history == nil {
		return opened{}, errors.New("moving this agent's sessions isn't supported")
	}
	remove, err := s.history(sid, from, to)
	if err != nil {
		return opened{}, err
	}
	defer func() {
		if err := remove(); err != nil {
			log.Printf("chat %s: removing the copy of %s in %s: %v", c.id, sid, to, err)
		}
	}()
	return c.openSession(ctx, s.launch, sid, to, true)
}

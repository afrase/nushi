package chats

import (
	"context"
	"errors"
	"log"
	"path/filepath"
	"slices"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// Move moves a chat to another folder, or with worktree to a new git
// worktree of folder's repository. A chat without messages gets a new
// session there. A chat with messages gets a fork of its session there: the
// agent's record of the session is copied into the folder's history, forked
// with the folder as its cwd (a new session id, with the whole conversation),
// and the copy removed; the original stays in the old folder's history. The
// chat's agent keeps running until the new one is ready, so a move that fails
// leaves the chat where it was, with a notice saying why. A chat without
// messages that leaves the worktree it had removes it, if it holds no work;
// its empty session is deleted, so the chat never had it. A worktree that
// holds work, or one a chat with messages leaves, stays on disk, and
// Delete offers it. A folder inside the chat's worktree keeps it.
func (s *Service) Move(ctx context.Context, chatID, folder string, worktree bool) error {
	if err := CheckFolder(folder); err != nil {
		return err
	}
	c, err := s.stored(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	from, sid, fresh, oldWT, mode := c.session.Folder, c.sid, !c.session.HasMessages, c.session.Worktree, c.session.Mode
	// A chat whose reopen failed (its folder gone) has an empty transcript:
	// the moved session is reopened, which replays it.
	replay := !fresh && c.agent == nil && !c.kept
	switch {
	case c.closedLocked() != nil:
		err = c.closedLocked()
	case c.busy:
		err = errors.New("the chat is busy; move it once the turn has ended")
	case c.ownTurn:
		err = errors.New("the agent is working on its own (a background task ended); move the chat once it's done")
	}
	if err != nil || from == folder && !worktree {
		c.mu.Unlock()
		return err
	}
	c.busy = true
	c.statusChangedLocked()
	c.mu.Unlock()

	var wt *model.Worktree
	switch {
	case worktree:
		wt, folder, err = s.addWorktree(ctx, folder)
	case oldWT != nil && within(folder, oldWT.Path):
		wt = oldWT // still in its worktree
	}
	var o opened
	switch {
	case err != nil:
	case fresh:
		o, err = c.openSession(ctx, s.launch, "", folder, false)
	default:
		o, err = s.fork(ctx, c, sid, from, folder)
	}
	if err == nil {
		c.mu.Lock()
		old := c.agent
		c.orphanLocked() // what ran on the old agent ends with it
		s.useLocked(c, o)
		c.saveLocked(func(s *model.Session) {
			if !fresh { // an empty session is just dropped, not something the chat had
				s.Earlier = append(slices.Clip(s.Earlier), model.AgentSession{ID: s.SessionID, Folder: s.Folder})
			}
			s.Folder, s.SessionID, s.Worktree, s.Scratch = folder, o.sid, wt, false
		})
		if replay {
			c.agent = nil // reopened below
		}
		c.mu.Unlock()
		sides := s.dropSides(c) // they ran on the old agent
		if old != nil {
			if fresh {
				if err := old.DeleteSession(ctx, acp.DeleteSessionRequest{SessionID: acp.SessionID(sid)}); err != nil {
					log.Printf("chat %s: deleting the empty session %s: %v", c.id, sid, err)
				}
			}
			old.Stop(stopGrace)
		}
		go s.discard(c, sides)
		if left := oldWT != nil && wt != oldWT; left && (!fresh || !s.dropWorktree(oldWT)) {
			c.mu.Lock()
			c.saveLocked(func(s *model.Session) { // it stays, with the work in it, until Delete
				s.EarlierWorktrees = append(slices.Clip(s.EarlierWorktrees), *oldWT)
			})
			c.mu.Unlock()
		}
		if replay {
			o.agent.Stop(stopGrace)
		} else if err := c.startMode(ctx, o.agent, o.sid, mode); err != nil {
			log.Printf("chat %s: mode after moving: %v", c.id, err)
		}
	} else if wt != oldWT {
		s.dropWorktree(wt)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.busy = false
	if err != nil {
		c.noticeLocked("error", "Couldn't move the chat to "+folder+": "+err.Error())
	}
	if replay && err == nil {
		s.reopenLocked(c)
	}
	c.statusChangedLocked()
	c.deliverLocked()
	return err
}

// within says whether folder is dir or a folder in it.
func within(folder, dir string) bool {
	rel, err := filepath.Rel(dir, folder)
	return err == nil && filepath.IsLocal(rel)
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

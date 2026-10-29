package chats

import (
	"context"
	"errors"
	"path/filepath"
	"slices"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// Move moves a chat to another folder, or with worktree to a new git
// worktree of folder's repository. A folder in a worktree that's there
// already (another of the repository's worktrees) runs the chat in it,
// as one Nushi didn't make (Found), never removed by Nushi. A chat with
// messages is told where it went with its next prompt. A chat without messages gets a new
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
func (s *Service) Move(ctx context.Context, chatID, folder string, worktree bool) error { //nolint:gocognit,gocyclo // the cases in its comment, in order
	if err := CheckFolder(folder); err != nil {
		return err
	}
	c, err := s.stored(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	from, sid, fresh, oldWT, mode, picks := c.session.Folder, c.sid, !c.session.HasMessages, c.session.Worktree, c.session.Mode, c.session.Picks
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
	case c.backgroundLocked(0):
		err = errors.New("a subagent is still running in the background, and moving would stop it; move the chat once it's done")
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
		wt, folder, err = s.addWorktree(ctx, folder, "", "")
	case oldWT != nil && within(folder, oldWT.Path):
		wt = oldWT // still in its worktree
	default:
		wt = s.foundWorktree(ctx, c, folder)
	}
	var o opened
	switch {
	case err != nil:
	case fresh:
		o, err = c.openSession(ctx, "", folder, false)
	default:
		o, err = s.fork(ctx, c, sid, from, folder)
	}
	if err == nil {
		c.mu.Lock()
		old := c.agent
		c.dropPromptsLocked() // what ran on the old agent ends with it
		c.orphanLocked(true)
		s.useLocked(c, o)
		c.saveLocked(func(s *model.Session) {
			if !fresh { // an empty session is just dropped, not something the chat had
				s.Earlier = append(slices.Clip(s.Earlier), model.AgentSession{ID: s.SessionID, Folder: s.Folder})
			}
			s.Folder, s.SessionID, s.Worktree, s.Scratch = folder, o.sid, wt, false
			// Back in one it ran in before: it's the chat's own again.
			s.EarlierWorktrees = slices.DeleteFunc(slices.Clone(s.EarlierWorktrees), func(e model.Worktree) bool { return wt != nil && e.Path == wt.Path })
			// Told where it is with the next prompt; a fresh chat's session starts there.
			s.Moved, s.BranchFrom = !fresh, ""
		})
		if replay {
			c.agent = nil // reopened below
		}
		c.mu.Unlock()
		sides := s.dropSides(c) // they ran on the old agent
		if old != nil {
			if fresh {
				if _, err := old.DeleteSession(ctx, &acp.DeleteSessionRequest{SessionID: acp.SessionID(sid)}); err != nil {
					c.log().Warn("deleting the empty session left by the move", "old", sid, "err", err)
				}
			}
			_ = old.Stop(stopGrace) // its process is gone either way
		}
		go s.discard(c, sides) //nolint:gosec // discarding outlives the request
		if left := oldWT != nil && wt != oldWT && !oldWT.Found; left && (!fresh || s.inUse(c, oldWT.Path) || !s.dropWorktree(oldWT)) {
			c.mu.Lock()
			c.saveLocked(func(s *model.Session) { // it stays, with the work in it, until Delete
				s.EarlierWorktrees = append(slices.Clip(s.EarlierWorktrees), *oldWT)
			})
			c.mu.Unlock()
		}
		if replay {
			_ = o.agent.Stop(stopGrace) // its process is gone either way
		} else if err := c.reapply(ctx, o.agent, o.sid, mode, picks); err != nil {
			c.log().Warn("mode after moving", "err", err)
		}
	} else if wt != oldWT {
		s.dropWorktree(wt)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.busy = false
	if err != nil {
		c.noticeLocked("error", "Couldn't move the chat to "+folder+": "+err.Error())
		c.logLocked().Warn("chat not moved", "to", folder, "err", err)
	} else {
		c.logLocked().Info("chat moved", "from", from, "old", sid, "worktree", wt != nil)
	}
	if replay && err == nil {
		s.reopenLocked(c)
	}
	c.statusChangedLocked()
	c.deliverLocked()
	return err
}

// foundWorktree is the worktree a chat moving to folder runs in when folder
// is in one that isn't its repository's own folder: one Nushi made for the
// chat before it moved out (its own again), else one that was there
// (Found); nil otherwise.
func (s *Service) foundWorktree(ctx context.Context, c *chat, folder string) *model.Worktree {
	c.mu.Lock()
	earlier := slices.Clone(c.session.EarlierWorktrees)
	c.mu.Unlock()
	for _, wt := range earlier {
		if within(folder, wt.Path) {
			return &wt
		}
	}
	if s.worktrees == nil {
		return nil
	}
	return s.worktrees.Found(ctx, folder)
}

// within says whether folder is dir or a folder in it.
func within(folder, dir string) bool {
	rel, err := filepath.Rel(dir, folder)
	return err == nil && filepath.IsLocal(rel)
}

// fork starts an agent with a fork of session sid in folder to.
func (s *Service) fork(ctx context.Context, c *chat, sid, from, to string) (opened, error) {
	if c.kind.History == nil {
		return opened{}, errors.New("moving this agent's sessions isn't supported")
	}
	remove, err := c.kind.History(sid, from, to)
	if err != nil {
		return opened{}, err
	}
	defer func() {
		if err := remove(); err != nil {
			c.log().Warn("removing the history copied for the move", "old", sid, "to", to, "err", err)
		}
	}()
	return c.openSession(ctx, sid, to, true)
}

// inUse says whether something but chat c runs in dir: another chat, or a
// terminal (c's too: it stays in its folder).
func (s *Service) inUse(c *chat, dir string) bool {
	if s.terminals != nil && s.terminals.Within(dir) {
		return true
	}
	stored, _ := s.sessions.Sessions()
	return slices.ContainsFunc(stored, func(sess model.Session) bool { return sess.ID != c.id && within(sess.Folder, dir) })
}

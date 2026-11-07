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
// session there. A chat with messages gets a fork of its session there,
// with the folder as its cwd (a new session id, with the whole
// conversation); the original stays in the old folder's history. The
// chat's agent keeps running until the new one is ready, so a move that fails
// leaves the chat where it was, with a notice saying why. A chat without
// messages that leaves the worktree it had removes it, if it holds no work;
// its empty session is deleted, so the chat never had it. A worktree that
// holds work, or one a chat with messages leaves, stays on disk, and
// Delete offers it. A folder inside the chat's worktree keeps it.
func (s *Service) Move(ctx context.Context, chatID, folder string, worktree bool) error { //nolint:gocognit,gocyclo // the cases in its comment, in order
	if err := checkFolder(folder); err != nil {
		return err
	}
	c, err := s.stored(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	from, sid, fresh, oldWT, mode, picks := c.record.Folder, c.sid, !c.record.HasMessages, c.record.Worktree, c.record.Mode, c.record.Picks
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
		o, err = c.openSession(ctx, "", folder, false, "")
	default:
		o, err = s.fork(ctx, c, sid, folder)
	}
	if err == nil {
		c.mu.Lock()
		old := c.agent
		c.dropPromptsLocked() // what ran on the old agent ends with it
		c.orphanLocked(true)
		held := c.held // a queue held after a stopped or failed turn stays held, as in load
		s.useLocked(c, o)
		c.held = held
		c.saveLocked(func(s *model.ChatRecord) {
			if !fresh { // an empty session is just dropped, not something the chat had
				s.Earlier = append(slices.Clip(s.Earlier), model.AgentSession{ID: s.SessionID, Folder: s.Folder})
			}
			s.Folder, s.SessionID, s.Worktree, s.Scratch = folder, o.sid, wt, false
			// Back in one it ran in before: it's the chat's own again.
			s.EarlierWorktrees = slices.DeleteFunc(slices.Clone(s.EarlierWorktrees), func(e model.Worktree) bool { return wt != nil && e.Path == wt.Path })
			// Told where it is with the next prompt; a fresh chat's session starts there.
			s.Moved, s.BranchFrom = !fresh, ""
		})
		c.movedLocked(from)
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
			c.saveLocked(func(s *model.ChatRecord) { // it stays, with the work in it, until Delete
				s.EarlierWorktrees = append(slices.Clip(s.EarlierWorktrees), *oldWT)
			})
			c.mu.Unlock()
		}
		if replay {
			_ = o.agent.Stop(stopGrace) // its process is gone either way
		} else if err := c.reapply(ctx, o.agent, o.sid, mode, picks); err != nil {
			c.log().Warn("mode after moving", "err", err)
		}
	} else if worktree && wt != nil {
		s.dropWorktree(wt) // only one this move made: an earlier one may have another chat in it
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

// movedLocked names the files the chat's items and queued messages name
// again, now that its folder is no longer from (ADR 0014): each is named
// relative to the folder when inside it, else absolute, as the agent's
// live updates and a replay name them (chat.rel). A move carries no file
// along (a new worktree has only what's committed), so a path the items
// gave relative to from still means that file in from, absolute unless it
// is in the new folder too. A message's files absolute already stay so,
// as no live message's are named again: the uploads among them are known
// by their absolute path in the uploads folder (forks adopt, and pruning
// keeps, only those). The clients are sent each item that changed, and the
// copy of the transcript (ADR 0047) gets the same names, whether copies
// are on or not, as a cut does: a reopen's merge takes the copy's item
// over the replay's, which already names the tool calls' files this way.
func (c *chat) movedLocked(from string) {
	moved := movedNames{
		path: func(p string) string {
			if p == "" {
				return p
			}
			if !filepath.IsAbs(p) {
				p = filepath.Join(from, p)
			}
			return c.rel(p)
		},
		file: func(f string) string {
			if f == "" || filepath.IsAbs(f) {
				return f
			}
			return c.rel(filepath.Join(from, f))
		},
	}
	for i := range c.items {
		if it, ok := movedItem(c.items[i], moved); ok {
			c.items[i] = it
			c.publishLocked(it)
		}
	}
	queued := false
	for i, m := range c.queue {
		if files, ok := movedPaths(m.Files, moved.file); ok {
			c.queue[i].Files, queued = files, true
		}
	}
	if queued {
		c.queueChangedLocked()
	}
	if c.copies == nil {
		return
	}
	items, err := c.copies.Read(c.id)
	changed := false
	for i := range items {
		if it, ok := movedItem(items[i], moved); ok {
			items[i], changed = it, true
		}
	}
	if err == nil && changed {
		err = c.copies.Replace(c.id, items)
	}
	if err != nil {
		c.logLocked().Warn("transcript copy: files not named after the move", "err", err)
	}
}

// movedNames is how a move names a file again: path a tool call's (Paths,
// Diffs), file a message's (Files).
type movedNames struct {
	path, file func(string) string
}

// movedItem is it with each file it names (a tool call's Paths and Diffs,
// a user message's Files) as moved names it, and whether one changed. It
// shares no slice with it, which snapshots handed out may hold.
func movedItem(it model.Item, moved movedNames) (model.Item, bool) {
	paths, changed := movedPaths(it.Paths, moved.path)
	files, ok := movedPaths(it.Files, moved.file)
	changed = changed || ok
	var diffs []model.FileChange
	for i, d := range it.Diffs {
		path, old := moved.path(d.Path), moved.path(d.OldPath)
		if path == d.Path && old == d.OldPath {
			continue
		}
		if diffs == nil {
			diffs = slices.Clone(it.Diffs)
		}
		diffs[i].Path, diffs[i].OldPath = path, old
	}
	if diffs == nil {
		diffs = it.Diffs
	} else {
		changed = true
	}
	if changed {
		it.Paths, it.Files, it.Diffs = paths, files, diffs
	}
	return it, changed
}

// movedPaths is paths as moved names them, and whether one changed; a
// new slice when one did.
func movedPaths(paths []string, moved func(string) string) ([]string, bool) {
	var out []string
	for i, p := range paths {
		if m := moved(p); m != p {
			if out == nil {
				out = slices.Clone(paths)
			}
			out[i] = m
		}
	}
	if out == nil {
		return paths, false
	}
	return out, true
}

// foundWorktree is the worktree a chat moving to folder runs in when folder
// is in one that isn't its repository's own folder: one Nushi made for the
// chat before it moved out (its own again), else one that was there
// (Found); nil otherwise.
func (s *Service) foundWorktree(ctx context.Context, c *chat, folder string) *model.Worktree {
	c.mu.Lock()
	earlier := slices.Clone(c.record.EarlierWorktrees)
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

// fork starts an agent with a fork of session sid in folder to, which the
// agent finds wherever it is (HarnessInfo.Moves).
func (s *Service) fork(ctx context.Context, c *chat, sid, to string) (opened, error) {
	if !c.kind.Moves {
		return opened{}, errors.New("moving this agent's sessions isn't supported")
	}
	return c.openSession(ctx, sid, to, true, "")
}

// inUse says whether something but chat c may run in dir: another chat
// (or the chats can't be read), a terminal (c's too: it stays in its
// folder) or a dev server.
func (s *Service) inUse(c *chat, dir string) bool {
	return s.terminals != nil && s.terminals.Within(dir) || s.servers != nil && s.servers.Within(dir) || s.othersWorkIn(c, dir)
}

package chats

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"io/fs"
	"maps"
	"os"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// lookup returns a chat, open or stored, without reopening it. A stored
// one's copy is read with only the chat locked: who finds it meanwhile
// waits for its transcript, the other chats don't.
func (s *Service) lookup(id string) (*chat, error) {
	s.mu.Lock()
	if c := s.chats[id]; c != nil {
		s.mu.Unlock()
		return c, nil
	}
	sess, k, err := s.storedSession(id)
	if err != nil {
		s.mu.Unlock()
		return nil, err
	}
	c := s.newChat(k)
	c.id, c.sid, c.record, c.issue = id, sess.SessionID, sess, sess.Issue
	c.ultracode.Store(sess.Ultracode)
	c.mu.Lock() // a new chat's: nobody waits on it
	defer c.mu.Unlock()
	s.chats[id] = c
	s.mu.Unlock()
	c.loadCopyLocked() // its transcript until the agent replays it, or for good when it can't
	return c, nil
}

// storedSession is a stored chat's session, as its chat starts with it,
// and its agent's kind.
func (s *Service) storedSession(id string) (model.ChatRecord, *kind, error) {
	stored, err := s.sessions.Sessions()
	if err != nil {
		return model.ChatRecord{}, nil, err
	}
	i := slices.IndexFunc(stored, func(sess model.ChatRecord) bool { return sess.ID == id })
	if i < 0 {
		return model.ChatRecord{}, nil, fmt.Errorf("no chat %q", id)
	}
	k, err := s.kindOf(stored[i].Agent)
	if err != nil {
		return model.ChatRecord{}, nil, err
	}
	sess := stored[i]
	sess.Scratch = s.isScratch(sess.Folder)
	toldBefore(&sess)
	return sess, k, nil
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
	if c.agent == nil && !c.busy && !c.record.Archived && !c.halting && c.parent == nil && !c.reopenFailed && !c.asleep && !c.sessionGone {
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
	if c.record.Archived || c.halting {
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
	gone := err != nil && c.isGone(err)
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
	switch {
	case gone:
		c.goneLocked("")
		go s.expire(context.WithoutCancel(ctx), c, "the agent says so")
	case err != nil:
		c.failedLocked(err)
	}
	c.statusChangedLocked()
	c.deliverLocked()
}

// failedLocked marks the chat's reopen failed, not tried again until it's
// shown (Reopen), a message, a reload or a move, or its agent becoming
// ready, and says why in one notice, which replaces the last one's. Its
// reason says what helps: "not_ready" setting its agent up (Settings ›
// Agents), "folder_gone" moving the chat, "reopen_failed" trying again.
func (c *chat) failedLocked(err error) {
	c.reopenFailed = true
	reason := "reopen_failed"
	if gone := folderGone(c.record); gone != nil {
		reason, err = "folder_gone", gone
	} else if ready := c.kind.ready(); ready != nil {
		reason, err = "not_ready", ready
	}
	text := "Couldn't reopen the chat: " + detail(err)
	if i := c.indexLocked(c.failure); i >= 0 && i == len(c.items)-1 && c.items[i].Status == reason && c.items[i].Text == text {
		return // said already
	}
	c.unsendLocked(c.failure)
	c.failure = c.addLocked(model.Item{Kind: model.Notice, Status: reason, Text: text})
}

// Reopen is a chat being shown (or Try again): one whose agent should run
// but doesn't is reopened, as opening it does, and one whose last reopen
// failed tries again, once a call, unless what stopped it still holds (its
// folder is gone, its agent isn't ready: the notice says so then). A
// sleeping or archived chat stays as it is.
func (s *Service) Reopen(id string) error {
	c, err := s.lookup(id)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.reopenFailed && c.agent == nil && !c.busy && !c.sessionGone {
		if err := cmp.Or(folderGone(c.record), c.kind.ready()); err != nil {
			c.failedLocked(err)
			return nil
		}
		c.reopenFailed = false
		c.logLocked().Info("chat reopening again", "for", "shown")
	}
	s.reopenLocked(c)
	return nil
}

// AgentReady is the agent named agent becoming ready to start (set up, or
// found ready): its chats that failed to reopen because it wasn't may try
// again, each when it's next shown (Reopen). None starts now.
func (s *Service) AgentReady(agent string) {
	s.mu.Lock()
	open := slices.Collect(maps.Values(s.chats))
	s.mu.Unlock()
	for _, c := range open {
		c.mu.Lock()
		if i := c.indexLocked(c.failure); c.kind.Name == agent && c.reopenFailed && i >= 0 && c.items[i].Status == "not_ready" {
			c.reopenFailed = false
			c.statusChangedLocked()
			c.logLocked().Info("chat may reopen", "why", "agent ready")
		}
		c.mu.Unlock()
	}
}

// load starts the chat's agent and has it replay the session, then puts the
// session back on the chat's picks and in the mode it was last in (an agent
// may reopen a session on its defaults: Claude does). A chat that never had
// a message may have nothing to replay (Claude keeps a session only once it
// has one): it gets a new session instead.
func (s *Service) load(ctx context.Context, c *chat) error {
	c.mu.Lock()
	sid, folder, fresh, gone := c.sid, c.record.Folder, !c.record.HasMessages, folderGone(c.record)
	retired := c.retired
	c.retired = nil
	// A transcript that outlived its agent stays; else the replay is merged
	// with the copy, which has everything shown till now.
	replay := !c.kept
	if replay {
		c.copyLocked(true)
		c.replaying, c.replay = true, nil
	}
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
	c.mu.Lock()
	replayed := c.replay
	c.replaying, c.replay = false, nil
	c.mu.Unlock()
	if err != nil {
		return err
	}
	c.mu.Lock()
	held := c.held // a queue held before (an archived chat's) stays held
	s.useLocked(c, o)
	c.held = held
	if replay {
		c.restoreLocked(replayed)
		c.childrenSaidLocked()
	}
	c.orphanLocked(false) // replayed calls whose agent died before their results
	if o.sid != sid {
		c.saveLocked(func(s *model.ChatRecord) { s.SessionID = o.sid })
	}
	mode, picks, throwaway := c.record.Mode, c.record.Picks, slices.Clone(c.record.Throwaway)
	c.mu.Unlock()
	go s.discard(c, throwaway) //nolint:gosec // discarding outlives the request; left by an agent that stopped before it could
	return c.reapply(ctx, o.agent, o.sid, mode, picks)
}

// folderGone says why a chat can't run when its folder no longer exists
// (removed outside Nushi), or returns nil.
func folderGone(sess model.ChatRecord) error {
	if _, err := os.Stat(sess.Folder); !errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if wt := sess.Worktree; wt != nil && !wt.Found {
		return fmt.Errorf("its worktree %s was removed outside Nushi; deleting the chat cleans up its branch %s", wt.Path, wt.Branch)
	}
	return fmt.Errorf("its folder %s is gone", sess.Folder)
}

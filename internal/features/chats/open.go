package chats

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
)

// Open makes one of the agent's sessions (Find's) a chat in folder: the
// agent replays it through session/load, as it reopens a chat after a
// daemon restart; Nushi copies nothing (ADR 0008). The chat starts in the
// mode a new chat of the agent's would. A session that is a chat already
// returns that chat; one of Nushi's own forks is refused. Its title is
// the one listed (listed), else its first message's, until the agent names it.
func (s *Service) Open(ctx context.Context, agent, folder, sessionID, listed string) (string, error) {
	k, err := s.kindOf(agent)
	if err != nil {
		return "", err
	}
	if err := CheckFolder(folder); err != nil {
		return "", err
	}
	stored, err := s.sessions.Sessions()
	if err != nil {
		return "", err
	}
	for _, sess := range stored {
		if sess.SessionID == sessionID && sess.Agent == k.Name {
			return sess.ID, nil
		}
	}
	// The folder as the chats already there spell it (/tmp, not the
	// agent's /private/tmp), so the chat joins them.
	if i := slices.IndexFunc(stored, func(sess model.Session) bool {
		return sess.Folder != folder && git.RealPath(sess.Folder) == git.RealPath(folder)
	}); i >= 0 {
		folder = stored[i].Folder
	}
	own, err := s.ownSessions()
	if err != nil {
		return "", err
	}
	s.mu.Lock()
	switch {
	case own[sessionID]:
		err = errors.New("the session is one of Nushi's own")
	case s.opening[sessionID]:
		err = errors.New("the session is opening already")
	}
	if err == nil {
		s.opening[sessionID] = true
	}
	s.mu.Unlock()
	if err != nil {
		return "", err
	}
	defer func() {
		s.mu.Lock()
		delete(s.opening, sessionID)
		s.mu.Unlock()
	}()

	c := s.newChat(k)
	c.id = rand.Text()
	c.mu.Lock()
	c.sid, c.busy = sessionID, true // its replay is the transcript, not a turn of the agent's own
	c.replaying = true
	c.session = model.Session{ID: c.id, SessionID: sessionID, Agent: k.Name, Folder: folder, Title: listed, Created: time.Now(), HasMessages: true}
	c.mu.Unlock()
	o, err := c.openSession(ctx, sessionID, folder, false)
	c.mu.Lock()
	replayed := c.replay
	c.replaying, c.replay = false, nil
	c.mu.Unlock()
	if err != nil {
		c.mu.Lock()
		if c.seq > 0 { // its title came, and with it the app heard of it
			c.emitLocked(model.Event{ChatID: c.id, Removed: true})
		}
		c.mu.Unlock()
		if err := s.sessions.DeleteSession(c.id); err != nil {
			c.log().Warn("forgetting a chat that couldn't open", "err", err)
		}
		return "", fmt.Errorf("couldn't open the session: %w", err)
	}
	c.mu.Lock()
	s.useLocked(c, o)
	c.restoreLocked(replayed)
	c.childrenSaidLocked()
	c.orphanLocked(false) // calls whose agent ended before their results
	c.busy = false
	if i := slices.IndexFunc(c.items, func(it model.Item) bool { return it.Kind == model.UserMessage }); c.session.Title == "" && i >= 0 {
		c.session.Title = title(c.items[i].Text) // as for a chat's first prompt
	}
	c.storeLocked()
	c.mu.Unlock()
	// Only the mode: an agent that keeps the model in its sessions (Ante,
	// PiG, omp) has the one the session was on.
	if err := c.reapply(ctx, o.agent, o.sid, s.remembered.Mode(k.Name), nil); err != nil {
		c.log().Warn("starting mode", "err", err)
	}
	c.mu.Lock()
	c.saveLocked(c.modeLocked)
	c.statusChangedLocked()
	c.mu.Unlock()
	s.mu.Lock()
	s.chats[c.id] = c
	s.mu.Unlock()
	c.log().Info("chat opened from the agent's session")
	return c.id, nil
}

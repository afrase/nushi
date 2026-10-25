package chats

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// Open makes one of the agent's sessions (Find's) a chat in folder: the
// agent replays it through session/load, as it reopens a chat after a
// daemon restart; Nushi copies nothing (ADR 0008). The chat starts in the
// mode a new chat of the agent's would. A session that is a chat already
// returns that chat; one of Nushi's own forks is refused.
func (s *Service) Open(ctx context.Context, agent, folder, sessionID, title string) (string, error) {
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
	c.session = model.Session{ID: c.id, SessionID: sessionID, Agent: k.Name, Folder: folder, Title: title, Created: time.Now(), HasMessages: true}
	c.mu.Unlock()
	o, err := c.openSession(ctx, sessionID, folder, false)
	if err != nil {
		c.mu.Lock()
		if c.seq > 0 { // its title came, and with it the app heard of it
			c.emitLocked(model.Event{ChatID: c.id, Removed: true})
		}
		c.mu.Unlock()
		s.sessions.DeleteSession(c.id)
		return "", fmt.Errorf("couldn't open the session: %w", err)
	}
	c.mu.Lock()
	s.useLocked(c, o)
	c.orphanLocked() // calls whose agent ended before their results
	c.busy = false
	c.storeLocked()
	c.mu.Unlock()
	if err := c.startMode(ctx, o.agent, o.sid, s.modes.Mode(k.Name)); err != nil {
		log.Printf("chat %s: starting mode: %v", c.id, err)
	}
	c.mu.Lock()
	c.saveLocked(c.modeLocked)
	c.statusChangedLocked()
	c.mu.Unlock()
	s.mu.Lock()
	s.chats[c.id] = c
	s.mu.Unlock()
	return c.id, nil
}

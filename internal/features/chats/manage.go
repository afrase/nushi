package chats

import (
	"errors"
	"fmt"
	"maps"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// stored returns a chat that is listed (not a side chat), without reopening it.
func (s *Service) stored(id string) (*chat, error) {
	c, err := s.lookup(id)
	if err == nil && c.parent != nil {
		return nil, fmt.Errorf("%q is a side chat", id)
	}
	return c, err
}

// Rename sets the title the user gave a chat, which wins over the agent's.
// An empty name goes back to the agent's title.
func (s *Service) Rename(chatID, name string) error {
	c, err := s.stored(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.saveLocked(func(s *model.Session) { s.Name = strings.TrimSpace(name) })
	return nil
}

// Archive stops a chat's agent and marks the chat archived; its transcript
// stays readable until the daemon restarts. Unarchiving (archived false)
// reopens it through session/load, which replays the transcript.
func (s *Service) Archive(chatID string, archived bool) error {
	c, err := s.stored(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	if archived && c.reopeningLocked() {
		c.mu.Unlock()
		return errReopening
	}
	if !archived && c.session.Archived {
		c.items = nil
	}
	c.saveLocked(func(s *model.Session) { s.Archived = archived })
	c.mu.Unlock()
	if archived {
		s.stop(c)
	}
	_, err = s.open(chatID)
	return err
}

// Remove forgets a chat: its agent stops and its session file goes. The
// agent's own history of the session stays.
func (s *Service) Remove(chatID string) error {
	c, err := s.stored(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	if c.reopeningLocked() {
		c.mu.Unlock()
		return errReopening
	}
	c.session.Archived = true // keeps it from reopening while it stops
	c.mu.Unlock()
	s.stop(c)
	if err := s.sessions.DeleteSession(chatID); err != nil {
		return err
	}
	s.mu.Lock()
	delete(s.chats, chatID)
	s.mu.Unlock()
	c.mu.Lock()
	defer c.mu.Unlock()
	c.emitLocked(model.Event{ChatID: chatID, Removed: true})
	return nil
}

var errReopening = errors.New("the chat is still reopening; try again in a moment")

func (c *chat) reopeningLocked() bool { return c.busy && c.started.IsZero() }

// stop ends a chat's agent and its side chats. A running turn is cancelled
// first, and the agent gets a few seconds to end it.
func (s *Service) stop(c *chat) {
	c.mu.Lock()
	done := c.done
	c.mu.Unlock()
	if err := c.cancel(); err == nil && done != nil {
		select {
		case <-done:
		case <-time.After(5 * time.Second):
		}
	}
	s.dropSides(c)
	c.disconnect()
}

// dropSides forgets a chat's side chats, whose agent is about to stop.
func (s *Service) dropSides(c *chat) {
	c.mu.Lock()
	sides := slices.Collect(maps.Keys(c.sides))
	clear(c.sides)
	c.mu.Unlock()
	s.mu.Lock()
	for _, id := range sides {
		delete(s.chats, id)
	}
	s.mu.Unlock()
}

package chats

import (
	"context"
	"errors"
	"fmt"
	"log"
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
		c.items, c.kept = nil, false
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
	c, err := s.halt(chatID)
	if err != nil {
		return err
	}
	return s.forget(c)
}

// halt stops a chat's agent for good, before the chat goes. The chat
// doesn't reopen until it is forgotten, or unhalted if it stays.
func (s *Service) halt(chatID string) (*chat, error) {
	c, err := s.stored(chatID)
	if err != nil {
		return nil, err
	}
	c.mu.Lock()
	if c.reopeningLocked() {
		c.mu.Unlock()
		return nil, errReopening
	}
	c.halting = true
	c.mu.Unlock()
	s.stop(c)
	return c, nil
}

// forget removes a halted chat's session file and tells the app it's gone.
func (s *Service) forget(c *chat) error {
	if err := s.sessions.DeleteSession(c.id); err != nil {
		return err
	}
	s.mu.Lock()
	delete(s.chats, c.id)
	s.mu.Unlock()
	c.mu.Lock()
	defer c.mu.Unlock()
	c.emitLocked(model.Event{ChatID: c.id, Removed: true})
	return nil
}

var errReopening = errors.New("the chat is still reopening; try again in a moment")

func (c *chat) reopeningLocked() bool { return c.busy && c.started.IsZero() }

// stop ends a chat's agent and its side chats. A running turn is cancelled
// first, and the agent gets a few seconds to end it; nothing from the queue
// goes to the agent meanwhile, and the queue is emptied.
func (s *Service) stop(c *chat) {
	c.mu.Lock()
	c.stopping = true
	done, running := c.done, !c.started.IsZero()
	err := c.cancelLocked()
	c.mu.Unlock()
	if err == nil && running {
		select {
		case <-done:
		case <-time.After(5 * time.Second):
		}
	}
	sides := s.dropSides(c)
	c.disconnect()
	go s.discard(c, sides)
	c.mu.Lock()
	defer c.mu.Unlock()
	c.stopping = false
	c.queue = nil
	c.queueChangedLocked()
}

// dropSides forgets a chat's side chats, whose agent is about to stop, and
// returns their session ids, for discard once it has.
func (s *Service) dropSides(c *chat) []string {
	c.mu.Lock()
	sides := slices.Collect(maps.Keys(c.sides))
	clear(c.sides)
	c.mu.Unlock()
	s.mu.Lock()
	for _, id := range sides {
		delete(s.chats, id)
	}
	s.mu.Unlock()
	return sides
}

// discard has a new agent delete side chats' sessions from its history,
// once the agent they ran on has stopped: one that still runs would write a
// little of a session back as it ends it (see throwAway).
func (s *Service) discard(c *chat, sides []string) {
	if len(sides) == 0 {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := s.deleteHistory(ctx, c, sides); err != nil {
		log.Printf("chat %s: deleting its side chats %v: %v", c.id, sides, err)
	}
}

// Folder returns the folder a chat runs in (in its worktree, for a worktree
// chat). An archived chat has none to work in.
func (s *Service) Folder(chatID string) (string, error) {
	c, err := s.stored(chatID)
	if err != nil {
		return "", err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.session.Archived {
		return "", errors.New("the chat is archived")
	}
	return c.session.Folder, nil
}

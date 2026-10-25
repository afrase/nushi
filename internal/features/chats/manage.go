package chats

import (
	"context"
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
		c.items, c.kept, c.reopenFailed, c.asleep = nil, false, false, false
	}
	c.saveLocked(func(s *model.Session) { s.Archived = archived })
	c.logLocked().Info("chat archived", "archived", archived)
	c.mu.Unlock()
	if archived {
		s.stop(c)
	}
	_, err = s.open(chatID)
	return err
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
	c.disconnect() // an agent started since the halt, if any
	c.mu.Lock()
	defer c.mu.Unlock()
	c.emitLocked(model.Event{ChatID: c.id, Removed: true})
	return nil
}

var errReopening = errors.New("the chat is still reopening; try again in a moment")

func (c *chat) reopeningLocked() bool { return c.busy && c.started.IsZero() }

// stop ends a chat's agent and its side chats (see end), then has the
// agent's history forget the side chats. The queue stays, held: nothing
// from it goes to an agent until the next turn has ended.
func (s *Service) stop(c *chat) {
	sides := s.end(c)
	go s.discard(c, sides)
	c.mu.Lock()
	defer c.mu.Unlock()
	c.stopping = false
	c.held = len(c.queue) > 0
}

// end stops a chat's agent and its side chats, and returns the side chats'
// sessions. A running turn is cancelled first, and the agent gets a few
// seconds to end it; nothing from the queue goes to the agent meanwhile.
func (s *Service) end(c *chat) []string {
	c.mu.Lock()
	c.stopping = true
	done, running := c.done, !c.started.IsZero()
	err := c.cancelLocked()
	c.mu.Unlock()
	if err == nil && running {
		select {
		case <-done:
		case <-time.After(stopGrace):
		}
	}
	sides := s.dropSides(c)
	c.disconnect()
	return sides
}

// dropSides forgets a chat's side chats, whose agent is about to stop, and
// returns their session ids, for discard once it has.
func (s *Service) dropSides(c *chat) []string {
	c.mu.Lock()
	sides := slices.Collect(maps.Values(c.sides))
	clear(c.sides)
	c.mu.Unlock()
	var ids []string
	s.mu.Lock()
	for _, side := range sides {
		delete(s.chats, side.id)
		ids = append(ids, side.id)
	}
	s.mu.Unlock()
	for _, side := range sides {
		side.mu.Lock()
		side.agent = nil                                             // what still follows it (a background command) stops
		side.emitLocked(model.Event{ChatID: side.id, Removed: true}) // for the app showing it
		side.mu.Unlock()
	}
	return ids
}

// discard has a new agent delete sessions nobody will see again (side
// chats, throwaway forks) from its history, once the agent they ran on has
// stopped: one that still runs would write a little of a session back as it
// ends it (see Dialect.Redelete). The chat then forgets them.
//
//nolint:contextcheck // runs on its own, after the request that let the sessions go
func (s *Service) discard(c *chat, ids []string) {
	if len(ids) == 0 {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := s.deleteHistory(ctx, c, ids); err != nil {
		c.log().Warn("deleting thrown-away sessions", "sessions", strings.Join(ids, ","), "err", err)
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.throwawayLocked(ids, true)
}

// throwawayLocked adds sessions the agent forked from the chat that nobody
// will see again to the chat's record of them, or with deleted takes them
// out of it (model.Session.Throwaway).
// Not while the chat is being deleted: its file may be gone, and Delete
// deletes them anyway.
func (c *chat) throwawayLocked(ids []string, deleted bool) {
	if c.halting {
		return
	}
	c.saveLocked(func(s *model.Session) {
		if deleted {
			s.Throwaway = slices.DeleteFunc(slices.Clone(s.Throwaway), func(id string) bool { return slices.Contains(ids, id) })
		} else {
			s.Throwaway = append(slices.Clip(s.Throwaway), ids...)
		}
		if len(s.Throwaway) == 0 {
			s.Throwaway = nil
		}
	})
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

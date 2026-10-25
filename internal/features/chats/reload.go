package chats

import (
	"errors"
	"maps"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// MCPChanged marks the running chats whose folder affected says yes to,
// of the agent whose MCP servers the mcp feature changes:
// their agent keeps the MCP servers it started with until the chat is
// reloaded.
func (s *Service) MCPChanged(affected func(folder string) bool) {
	s.mu.Lock()
	open := slices.Collect(maps.Values(s.chats))
	s.mu.Unlock()
	for _, c := range open {
		c.mu.Lock()
		folder, running := c.session.Folder, c.agent != nil && c.parent == nil && c.kind.MCP
		c.mu.Unlock()
		if running && affected(folder) {
			c.mu.Lock()
			c.mcpChanged = true
			c.statusChangedLocked()
			c.mu.Unlock()
		}
	}
}

// Reload reopens a chat's session on a new agent (session/load, as after a
// daemon restart), so it starts with the MCP servers as they are now. Its
// transcript is replayed; its side chats end. Refused while it is busy.
func (s *Service) Reload(chatID string) error {
	c, err := s.chat(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	if c.busy {
		c.mu.Unlock()
		return errors.New("the chat is busy; reload it once the agent is done")
	}
	c.busy, c.mcpChanged, c.reopenFailed = true, false, false
	_ = c.cancelLocked() // a prompt or question of the agent's own turn: it won't be answered
	agent := c.agent
	c.statusChangedLocked()
	c.mu.Unlock()
	sides := s.dropSides(c)
	c.disconnect()
	if agent != nil { // its last updates, still on their way, before the cut
		select {
		case <-agent.Done():
		case <-time.After(stopGrace):
		}
	}
	c.mu.Lock()
	c.kept = false
	if len(c.items) > 0 {
		c.emitLocked(model.Event{ChatID: c.id, Cut: c.items[0].ID})
		c.items = nil
	}
	c.mu.Unlock()
	go s.discard(c, sides)
	go s.resume(c)
	return nil
}

package chats

import "errors"

// MCPChanged marks agent's running chats whose folder affected says yes
// to: their agent keeps the MCP servers it started with until the chat is
// reloaded.
func (s *Service) MCPChanged(agent string, affected func(folder string) bool) {
	open := s.openChats()
	for _, c := range open {
		c.mu.Lock()
		folder, running := c.record.Folder, c.agent != nil && c.parent == nil && c.kind.MCP && c.kind.Name == agent
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
// transcript is replayed; its side chats end. Refused while it is busy;
// meanwhile, what needs the agent waits for it (awake), as for a reopen.
func (s *Service) Reload(chatID string) error {
	c, err := s.chat(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	if c.busyLocked() {
		c.mu.Unlock()
		return errors.New("the chat is busy; reload it once the agent is done")
	}
	c.beginOpLocked(opReload)
	c.mcpChanged, c.reopenFailed = false, false
	_ = c.cancelLocked() // a prompt or question of the agent's own turn: it won't be answered
	c.statusChangedLocked()
	c.mu.Unlock()
	sides := s.dropSides(c)
	c.disconnect() // its last updates are in once it has ended, which load waits for (retire)
	c.mu.Lock()
	c.outlived = false // the replay is merged with the copy (restore.go)
	c.mu.Unlock()
	s.later(func() { s.discard(c, sides) })
	if !s.later(func() { s.resume(c) }) {
		c.mu.Lock()
		defer c.mu.Unlock()
		c.endOpLocked()
		return errClosing
	}
	return nil
}

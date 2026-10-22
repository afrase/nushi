package chats

import (
	"context"
	"errors"
	"fmt"
	"slices"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// chat returns an open chat. A stored chat whose agent isn't running (the
// daemon restarted) is reopened in the background through session/load; it
// is busy until its history has been replayed.
func (s *Service) chat(id string) (*chat, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	c := s.chats[id]
	if c == nil {
		stored, err := s.sessions.Sessions()
		if err != nil {
			return nil, err
		}
		i := slices.IndexFunc(stored, func(sess model.Session) bool { return sess.ID == id })
		if i < 0 {
			return nil, fmt.Errorf("no chat %q", id)
		}
		c = s.newChat()
		c.id, c.session = id, stored[i]
		s.chats[id] = c
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.agent == nil && !c.busy { // never reopened, or the last try failed
		c.busy = true
		c.emitLocked(model.Event{ChatID: c.id, Status: &model.Status{Busy: true}})
		go s.resume(c)
	}
	return c, nil
}

func (s *Service) resume(c *chat) {
	err := c.load(context.Background(), s.launch)
	c.mu.Lock()
	defer c.mu.Unlock()
	c.busy = false
	c.lastError = ""
	if err != nil {
		c.lastError = "Couldn't reopen the chat: " + err.Error()
	}
	c.emitLocked(model.Event{ChatID: c.id, Status: &model.Status{Error: c.lastError}})
}

// load starts the chat's agent and has it replay the session, then puts the
// session back in the mode it was last in.
func (c *chat) load(ctx context.Context, launch Launch) error {
	init, err := c.connect(ctx, launch)
	if err != nil {
		return err
	}
	if init.AgentCapabilities == nil || !init.AgentCapabilities.LoadSession {
		c.disconnect()
		return errors.New("the agent can't reopen sessions")
	}
	resp, err := c.agent.LoadSession(ctx, acp.LoadSessionRequest{SessionID: acp.SessionID(c.id), Cwd: c.session.Folder, MCPServers: []acp.MCPServer{}})
	if err != nil {
		c.disconnect()
		return err
	}
	c.mu.Lock()
	c.config = configFrom(resp.ConfigOptions, resp.Modes)
	c.emitLocked(model.Event{ChatID: c.id, Config: slices.Clone(c.config)})
	c.mu.Unlock()
	return c.startMode(ctx, c.session.Mode)
}

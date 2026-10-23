package chats

import (
	"context"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// A side chat is a session the agent forks from a chat's: it knows the
// conversation so far but doesn't add to it. It shares the chat's agent,
// isn't stored, and ends with CloseSide (or the daemon), which also has
// the agent delete its history of it: it is never shown again.

// SessionUpdate, RequestPermission and CreateElicitation take what the
// agent sends to the chat or to one of its side chats. A side chat's
// updates that arrive before it is set up are dropped.
func (c *chat) SessionUpdate(n acp.SessionNotification) {
	if to := c.route(n.SessionID); to != nil {
		to.update(n)
	}
}

func (c *chat) RequestPermission(ctx context.Context, req acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
	to := c.route(req.SessionID)
	if to == nil {
		return nil, fmt.Errorf("no session %q", req.SessionID)
	}
	return to.requestPermission(ctx, req)
}

func (c *chat) CreateElicitation(ctx context.Context, req acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error) {
	to := c.route(req.SessionID)
	if to == nil {
		return nil, fmt.Errorf("no session %q", req.SessionID)
	}
	return to.createElicitation(ctx, req)
}

func (c *chat) route(session acp.SessionID) *chat {
	c.mu.Lock()
	defer c.mu.Unlock()
	if session == "" || string(session) == c.sid {
		return c
	}
	return c.sides[string(session)]
}

// Fork opens a side chat of a chat and returns its id.
func (s *Service) Fork(ctx context.Context, chatID string) (string, error) {
	p, err := s.chat(chatID)
	if err != nil {
		return "", err
	}
	p.mu.Lock()
	agent, sid, folder := p.agent, p.sid, p.session.Folder
	can := p.canFork && p.parent == nil
	p.mu.Unlock()
	if agent == nil || !can {
		return "", errors.New("the agent can't fork this chat")
	}
	resp, err := agent.ForkSession(ctx, acp.ForkSessionRequest{SessionID: acp.SessionID(sid), Cwd: folder, MCPServers: []acp.MCPServer{}})
	if err != nil {
		return "", err
	}
	side := s.newChat()
	side.id, side.agent, side.parent = string(resp.SessionID), agent, p
	side.sid, side.canImage = side.id, p.canImage
	side.session = model.Session{ID: side.id, SessionID: side.sid, Agent: s.agent, Folder: folder, Title: "Side question", Created: time.Now()}
	p.mu.Lock()
	p.sides[side.id] = side
	p.mu.Unlock()
	s.mu.Lock()
	s.chats[side.id] = side
	s.mu.Unlock()
	return side.id, nil
}

// CloseSide ends a side chat: its running turn stops, and the agent closes
// its session and deletes its history of it.
func (s *Service) CloseSide(ctx context.Context, id string) error {
	s.mu.Lock()
	c := s.chats[id]
	if c == nil || c.parent == nil {
		s.mu.Unlock()
		return fmt.Errorf("no side chat %q", id)
	}
	delete(s.chats, id)
	s.mu.Unlock()
	c.parent.mu.Lock()
	delete(c.parent.sides, id)
	c.parent.mu.Unlock()
	c.cancel()
	if err := c.agent.CloseSession(ctx, acp.CloseSessionRequest{SessionID: acp.SessionID(id)}); err != nil {
		log.Printf("side chat %s: closing: %v", id, err)
	}
	if err := c.agent.DeleteSession(ctx, acp.DeleteSessionRequest{SessionID: acp.SessionID(id)}); err != nil {
		log.Printf("side chat %s: deleting: %v", id, err)
	}
	return nil
}

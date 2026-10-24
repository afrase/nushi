package chats

import (
	"context"
	"errors"
	"fmt"
	"log"
	"slices"
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
	if c.probe(n) {
		return
	}
	if to := c.route(n.SessionID); to != nil {
		to.update(n)
	}
}

// probe takes an update of a throwaway fork (see contextInFork): its
// message text goes to its silent run, and nothing else of it is kept.
func (c *chat) probe(n acp.SessionNotification) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	run := c.probes[string(n.SessionID)]
	if run == nil {
		return false
	}
	if m := n.Update.AgentMessageChunk; m != nil && m.Content.Text != nil {
		run.add(m)
	}
	return true
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
	id, _, err := p.forkSession(ctx, agent, sid, folder, nil)
	if err != nil {
		return "", err
	}
	p.mu.Lock()
	p.throwawayLocked([]string{id}, false)
	p.mu.Unlock()
	if ctx.Err() != nil { // the app went meanwhile: nobody will open it
		p.throwAway(agent, id)
		return "", ctx.Err()
	}
	side := s.newChat()
	side.id, side.agent, side.parent = id, agent, p
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

// CloseSide ends a side chat: its running turn stops, and the agent deletes
// its session, history and all.
func (s *Service) CloseSide(id string) error {
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
	c.mu.Lock()
	c.cancelLocked()
	agent := c.agent
	c.agent = nil // what still follows it (a background command) stops
	c.mu.Unlock()
	c.parent.throwAway(agent, id)
	return nil
}

// CloseSides ends every side chat (see CloseSide): the app keeps them only
// while it runs, so once no app is left, nobody will see them again.
func (s *Service) CloseSides() {
	s.mu.Lock()
	var sides []string
	for id, c := range s.chats {
		if c.parent != nil {
			sides = append(sides, id)
		}
	}
	s.mu.Unlock()
	for _, id := range sides {
		s.CloseSide(id)
	}
}

// throwAway has the chat's agent delete a session forked from the chat that
// nobody will see again (a side chat, a /context fork), and again a moment
// later for an agent that writes a little of it back as it ends
// (Dialect.Redelete); then the chat forgets it. If that fails, the chat
// keeps it, for a fresh agent to delete (see model.Session.Throwaway).
func (c *chat) throwAway(agent Agent, sid string) {
	del := func(last bool) {
		err := agent.DeleteSession(context.Background(), acp.DeleteSessionRequest{SessionID: acp.SessionID(sid)})
		if err != nil {
			log.Printf("deleting session %s: %v", sid, err)
		}
		if last {
			c.mu.Lock()
			defer c.mu.Unlock()
			kept := slices.Contains(c.session.Throwaway, sid)
			if err == nil && kept || err != nil && !kept {
				c.throwawayLocked([]string{sid}, err == nil)
			}
		}
	}
	if c.dialect.Redelete == 0 {
		del(true)
		return
	}
	del(false)
	time.AfterFunc(c.dialect.Redelete, func() { del(true) })
}

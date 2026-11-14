package chats

import (
	"context"
	"errors"
	"fmt"
	"maps"
	"slices"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// A side chat is a session the agent forks from a chat's: it knows the
// conversation so far but doesn't add to it. It shares the chat's agent,
// isn't stored, and ends with CloseSide (or the daemon), which also has
// the agent delete its history of it: it is never shown again. Its ×
// archives one with messages instead (ArchiveSide, ADR 0115), which
// RestoreSide can bring back.

// SessionUpdate, RequestPermission and CreateElicitation take what the
// agent sends to the chat or to one of its side chats. A side chat's
// updates that arrive before it is set up are dropped.
func (c *chat) SessionUpdate(_ context.Context, n *acp.SessionNotification) error {
	if c.probe(n) || c.childUpdate(n) {
		return nil
	}
	c.mu.Lock()
	to, ch := c.routeLocked(n.SessionID)
	var from *child
	if ch != nil {
		from = &child{launch: ch.launch}
	}
	// A new session's first updates (its commands) can pass the answer
	// that names it: they wait for useLocked. A replay's only go by ids
	// the chat knows.
	if to == nil && c.opening && !slices.Contains(replayKinds, n.Update.SessionUpdate) {
		c.early = append(c.early, n)
	}
	c.mu.Unlock()
	if to != nil {
		to.update(n, from)
	}
	return nil
}

// probe takes an update of a throwaway fork (see contextInFork): its
// message text goes to its silent run, and nothing else of it is kept.
func (c *chat) probe(n *acp.SessionNotification) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	run := c.probes[string(n.SessionID)]
	if run == nil {
		return false
	}
	if m := n.Update.AgentMessageChunk; m != nil && m.Content.Text != nil {
		run.add(m)
	}
	if n.Update.ToolCall != nil && run.tool != nil {
		run.toolCalled = true
		run.tool()
	}
	return true
}

// probing says whether sid is a throwaway fork's.
func (c *chat) probing(sid acp.SessionID) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.probes[string(sid)] != nil
}

func (c *chat) RequestPermission(ctx context.Context, req *acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
	if c.probing(req.SessionID) { // nobody sees a throwaway fork to answer
		return &acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{Cancelled: true}}, nil
	}
	to := c.route(req.SessionID)
	if to == nil {
		return nil, fmt.Errorf("no session %q", req.SessionID)
	}
	return to.requestPermission(ctx, req)
}

func (c *chat) CreateElicitation(ctx context.Context, req *acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error) {
	var session acp.SessionID // the form's, or the URL's; none for one outside a session
	switch {
	case req.Form != nil:
		session = req.Form.SessionID
	case req.URL != nil:
		session = req.URL.SessionID
	}
	to := c.route(session)
	if to == nil {
		return nil, fmt.Errorf("no session %q", session)
	}
	return to.createElicitation(ctx, req)
}

func (c *chat) route(session acp.SessionID) *chat {
	c.mu.Lock()
	defer c.mu.Unlock()
	to, _ := c.routeLocked(session)
	return to
}

// routeLocked finds the chat a session is: the chat, a side chat, or the
// chat (or side chat) one of the agent's subagents works for, then with
// that subagent's session.
func (c *chat) routeLocked(session acp.SessionID) (*chat, *child) {
	switch {
	case session == "" || string(session) == c.sid:
		return c, nil
	case c.sides[string(session)] != nil:
		return c.sides[string(session)], nil
	case c.children[string(session)] != nil:
		ch := c.children[string(session)]
		return ch.owner, ch
	}
	return nil, nil
}

// Fork opens a side chat of a chat and returns its id.
func (s *Service) Fork(ctx context.Context, chatID string) (string, error) {
	p, err := s.awakeChat(ctx, chatID)
	if err != nil {
		return "", err
	}
	return s.openSide(ctx, p, nil)
}

// sideSource is what a side chat opens from when it isn't a new fork of its
// chat's session but an archived side chat brought back (RestoreSide): its
// session, the chat's items it started with, its own, and its mode and
// picks.
type sideSource struct {
	sid         string
	base, items []model.Item
	mode        string
	picks       map[string]string
}

// errOtherSide refuses a side chat brought back beside one already open:
// the app shows one at a time.
var errOtherSide = errors.New("the chat has another side chat open")

// openSide opens a side chat of p, a fork of its session, or with from a
// fork of an archived side chat's, and returns its id.
func (s *Service) openSide(ctx context.Context, p *chat, from *sideSource) (string, error) {
	p.mu.Lock()
	agent, sid, folder := p.agent, p.sid, p.record.Folder
	can := p.canFork && p.parent == nil
	base, _ := p.finishedLocked() // the side chat forks the whole session
	lastItem := p.lastItem        // the side chat's own items come after
	reopening := p.settlingLocked()
	other := from != nil && len(p.sides) > 0
	p.mu.Unlock()
	if from != nil {
		sid, base = from.sid, from.base
	}
	switch {
	case agent == nil || !can:
		return "", errors.New("the agent can't fork this chat")
	case reopening:
		return "", errSettling
	case other:
		return "", errOtherSide
	}
	id, config, err := p.forkSession(ctx, agent, sid, folder, nil)
	if err != nil {
		return "", err
	}
	// Ultracode is the chat's, its agent's process's: not the side chat's to change.
	config = slices.DeleteFunc(config, func(o model.ConfigOption) bool { return o.ID == ultracodeID })
	p.mu.Lock()
	p.throwawayLocked([]string{id}, false)
	p.mu.Unlock()
	if ctx.Err() != nil { // the app went meanwhile: nobody will open it
		s.throwAway(p, agent, id)
		return "", ctx.Err()
	}
	side := s.newChat(p.kind)
	side.id, side.agent, side.parent, side.base, side.lastItem = id, agent, p, base, lastItem
	side.sid, side.canImage, side.config = side.id, p.canImage, config
	side.reapplying = true // until reapply: the fork's own options aren't picks
	side.copies = nil      // nobody sees a side chat again, so Nushi keeps no copy of it
	side.record = model.ChatRecord{ID: side.id, SessionID: side.sid, Agent: p.kind.Name, Folder: folder, Title: "Side chat", Created: time.Now()}
	if from != nil { // its conversation and picks as they were
		s.adoptUploads(side.id, from.items)
		side.items, side.record.HasMessages, side.record.Picks = from.items, true, maps.Clone(from.picks)
		for _, it := range from.items {
			side.noteID(it.ID)
		}
	}
	side.modeLocked(&side.record) // the fork's mode, as the agent says, until reapply
	// The app hears of the side chat from Fork's answer, then loads it:
	// what it says before (putting the chat's mode and picks on it) would
	// reach the app as a chat of the sidebar's.
	side.publish = func(model.Event) {}
	p.mu.Lock()
	switch {
	case p.agent != agent: // it ended meanwhile (reload, move, archive): the fork with it
		p.mu.Unlock()
		s.throwAway(p, agent, id)
		return "", errors.New("the agent stopped")
	case p.settlingLocked(): // a rewind or move began meanwhile: the chat's mode isn't back on it
		p.mu.Unlock()
		s.throwAway(p, agent, id)
		return "", errSettling
	case from != nil && len(p.sides) > 0: // one opened meanwhile
		p.mu.Unlock()
		s.throwAway(p, agent, id)
		return "", errOtherSide
	}
	// Read now, not before the fork: a change made meanwhile is carried.
	mode, picks := p.record.Mode, maps.Clone(p.record.Picks)
	if i := modeIndex(p.config); i >= 0 {
		mode = p.config[i].Current // what the agent says the chat is on
	}
	if from != nil {
		mode, picks = from.mode, maps.Clone(from.picks)
	}
	p.sides[side.id] = side
	side.commands = slices.Clone(p.commands) // the agent's, which it told only the chat
	p.mu.Unlock()
	s.mu.Lock()
	s.chats[side.id] = side
	s.mu.Unlock()
	// It starts on the chat's mode and picks, as a fork does (ForkAsChat):
	// the mode is the agent's permission control, and an aside asked in a
	// chat in Manual mustn't run in the agent's default (ADR 0060's
	// amendment). What the agent then reports is what it shows.
	if err := side.reapply(ctx, agent, side.sid, mode, picks); err != nil {
		side.log().Warn("mode of the side chat", "err", err)
	}
	side.mu.Lock()
	side.saveLocked(side.modeLocked) // what the agent says it's on: Keep carries it
	side.publish = s.publish
	side.mu.Unlock()
	p.mu.Lock()
	dropped := p.sides[side.id] != side // its agent stopped meanwhile (dropSides discards it)
	p.mu.Unlock()
	switch {
	case dropped:
		return "", errors.New("the agent stopped")
	case ctx.Err() != nil: // the app went meanwhile: nobody will show it
		_ = s.CloseSide(side.id)
		return "", ctx.Err()
	}
	side.log().Info("side chat opened")
	return side.id, nil
}

var errSettling = errors.New("the chat is reopening, moving or rewinding; open a side chat once that's done")

// settlingLocked says the chat's session is being opened again (a reopen,
// move or rewind) and its mode and picks aren't back on it yet: what the
// agent reports is the new session's defaults.
func (c *chat) settlingLocked() bool { return c.reopeningLocked() || c.reapplying }

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
	mine := c.parent.sides[id] == c
	delete(c.parent.sides, id)
	c.parent.mu.Unlock()
	if !mine {
		return nil // kept (KeepSide) or dropped (dropSides) meanwhile: theirs
	}
	c.log().Info("side chat closed")
	c.mu.Lock()
	_ = c.cancelLocked() // the agent may be gone already
	agent := c.agent
	c.agent = nil // what still follows it (a background command) stops
	c.mu.Unlock()
	if agent == nil {
		return nil // dropSides took it first: discard deletes the session
	}
	s.throwAway(c.parent, agent, id)
	return nil
}

// SidesGrace is how long side chats outlive the last app following: one
// that reconnects within it still has them.
var SidesGrace = 2 * time.Minute

// Following counts an app following the events (by +1, then -1), on the
// Mac's socket and devices' channels alike. Side chats live only in the
// apps (ADR 0027): once none has followed for SidesGrace, they're closed
// (unless the service closed first: Close stops the timer).
func (s *Service) Following(n int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.following += n
	if s.idle != nil {
		s.idle.Stop()
	}
	if s.following == 0 && !s.closing {
		s.idle = time.AfterFunc(SidesGrace, s.closeSides)
	}
}

// closeSides ends every side chat (see CloseSide), once no app has followed
// for SidesGrace: the app keeps them only while it runs, so nobody will see
// them again.
func (s *Service) closeSides() {
	s.mu.Lock()
	var sides []string
	for id, c := range s.chats {
		if c.parent != nil {
			sides = append(sides, id)
		}
	}
	s.mu.Unlock()
	for _, id := range sides {
		_ = s.CloseSide(id) // one already closed is fine
	}
}

// throwAway has the chat's agent delete a session forked from the chat that
// nobody will see again (a side chat, a /context fork), and again a moment
// later for an agent that writes a little of it back as it ends
// (model.HarnessInfo.Redelete); then the chat forgets it. If the agent can't (it
// went, or is going, meanwhile), the chat keeps it, and a fresh agent
// deletes it once that one has stopped (see discard).
//
//nolint:contextcheck // the side chat's session is deleted after the request that closed it
func (s *Service) throwAway(c *chat, agent Agent, sid string) {
	del := func() error {
		ctx, cancel := context.WithTimeout(context.Background(), s.timing.throwAwayWait())
		defer cancel()
		_, err := agent.DeleteSession(ctx, &acp.DeleteSessionRequest{SessionID: acp.SessionID(sid)})
		if err != nil {
			c.log().Warn("deleting a forked session", "fork", sid, "err", err)
		}
		return err
	}
	last := func() {
		err := del()
		c.mu.Lock()
		c.throwawayLocked([]string{sid}, err == nil)
		c.mu.Unlock()
		if err != nil {
			select {
			case <-agent.Done():
			case <-time.After(3 * s.timing.stopGrace()):
			}
			s.discard(c, []string{sid})
		}
	}
	if c.kind.Redelete == 0 {
		last()
		return
	}
	_ = del() // logged; last tries again
	go func() {
		select {
		case <-time.After(c.kind.Redelete):
			last()
		case <-s.ctx.Done(): // the chat keeps it (Close's doc)
		}
	}()
}

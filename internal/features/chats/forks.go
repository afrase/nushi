package chats

import (
	"cmp"
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"maps"
	"slices"
	"strings"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// A fork is a new chat from a chat's conversation, all of it or up to one
// of the agent's messages, going on separately (ADR 0067): its own agent
// process forks the session, its transcript and copy start with the
// chat's items to there, and the chat itself is left alone. Keep makes a
// side chat such a chat.

// Forkable says a session can be forked at it (as rewind does, at the
// message before one of the user's): one of the agent's own messages, not
// a subagent's, that the agent named (an ACP messageId; Nushi's own ids
// are item-N), and not one its safeguards stopped, of which it keeps
// nothing. Only while the agent can fork at messages (Status.CanRewind).
func Forkable(it model.Item) bool {
	return it.Kind == model.AgentMessage && it.Parent == "" && it.Status != model.StoppedBySafeguards && !strings.HasPrefix(it.ID, "item-")
}

// ForkAsChat makes a new chat of a chat's conversation and returns its id:
// the same agent and folder (and worktree), the chat's picks, its title
// marked as a fork. With at, one of the agent's messages (Forkable), the
// conversation up to it, it included; else all that has finished.
func (s *Service) ForkAsChat(ctx context.Context, chatID, at string) (string, error) {
	p, err := s.chat(chatID)
	if err == nil {
		err = s.awake(ctx, p)
	}
	if err != nil {
		return "", err
	}
	p.mu.Lock()
	of, sid := p.record, p.sid
	items, at, err := p.forkLocked(at)
	p.mu.Unlock()
	if err != nil {
		return "", err
	}
	c := s.newChat(p.kind)
	c.id, c.issue = rand.Text(), of.Issue
	c.ultracode.Store(of.Ultracode)
	// The fork's session is the new chat's to keep, even if the app went.
	ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), time.Minute)
	defer cancel()
	o, err := c.openSession(ctx, sid, of.Folder, true, at)
	if err != nil {
		return "", fmt.Errorf("couldn't fork the chat: %w", err)
	}
	c.mu.Lock()
	s.useLocked(c, o)
	c.record = forkRecord(c.id, o.sid, of)
	c.forkedLocked(items)
	c.mu.Unlock()
	if err := c.reapply(ctx, o.agent, o.sid, of.Mode, of.Picks); err != nil {
		c.log().Warn("mode after forking", "err", err)
	}
	c.mu.Lock()
	c.saveLocked(c.modeLocked)
	c.storeLocked()
	c.mu.Unlock()
	s.mu.Lock()
	s.chats[c.id] = c
	s.mu.Unlock()
	c.log().Info("chat forked", "from", p.id, "at_message", at != "")
	return c.id, nil
}

// forkLocked says what a fork of the chat starts with: its items up to and
// with the agent's message at (what followed in its turn left out, as a
// rewind does), or, for "", all that has finished; and the message its
// session forks at. While a turn runs, that is the agent's message before
// the turn's when the agent can fork at messages, so the fork and its
// transcript agree; else the whole session forks, and the transcript stops
// before the turn's message.
func (c *chat) forkLocked(at string) ([]model.Item, string, error) {
	switch {
	case c.agent == nil || !c.canFork || c.parent != nil:
		return nil, "", errors.New("the agent can't fork this chat")
	case c.reopeningLocked():
		return nil, "", errors.New("the chat is reopening, moving or rewinding; fork it once that's done")
	case !c.record.HasMessages:
		return nil, "", errors.New("the chat has no messages to fork")
	}
	if at == "" {
		items, at := c.finishedLocked()
		return items, at, nil
	}
	i := c.indexLocked(at)
	switch {
	case c.forkAt == nil:
		return nil, "", errors.New("the agent can't fork at a message")
	case i < 0 || !Forkable(c.items[i]):
		return nil, "", errors.New("no such message of the agent's")
	case i == len(c.items)-1 && !c.started.IsZero():
		return nil, "", errors.New("the message isn't finished yet")
	}
	return kept(c.items[:i+1]), at, nil
}

// finishedLocked is the chat's transcript without the running turn, if
// one runs, and the agent's message a fork of it should be cut at ("" for
// the whole session): see forkLocked.
func (c *chat) finishedLocked() ([]model.Item, string) {
	if c.started.IsZero() {
		return kept(c.items), ""
	}
	u := min(c.turnFrom, len(c.items)-1) // about: items may have gone since
	for u >= 0 && c.items[u].Kind != model.UserMessage {
		u--
	}
	if u < 0 {
		return kept(c.items), ""
	}
	if p := c.items[u].ForkAt; p != "" && c.forkAt != nil {
		if j := c.indexLocked(p); j >= 0 && j < u {
			return kept(c.items[:j+1]), p
		}
	}
	return kept(c.items[:u]), ""
}

// kept is a copy of items without those that are a chat's state rather
// than its history (shownOnly), what was under way ended.
func kept(items []model.Item) []model.Item {
	out := make([]model.Item, 0, len(items))
	for _, it := range items {
		if !shownOnly(it) {
			ended(&it)
			out = append(out, it)
		}
	}
	return out
}

// forkedLocked starts a new chat's transcript with a fork's items, and its
// copy with them.
func (c *chat) forkedLocked(items []model.Item) {
	for _, it := range items {
		c.noteID(it.ID)
		c.unsaved[it.ID] = true
	}
	c.items = items
	c.copyLocked(true)
}

// forkRecord is the record of a fork, id on session sid, of the chat of:
// where it works, what it's on and its picks are the chat's; its titles are
// marked " (fork)", as Claude marks a fork's (claude.ForkTitle), so the
// agent's own title for it changes nothing. A worktree's branch is shared,
// never renamed after either chat.
func forkRecord(id, sid string, of model.ChatRecord) model.ChatRecord {
	r := model.ChatRecord{ID: id, SessionID: sid, Agent: of.Agent, Folder: of.Folder, Title: forkTitle(of.Title), Name: forkTitle(of.Name),
		Mode: of.Mode, Created: time.Now(), HasMessages: true, Issue: of.Issue, GitHub: of.GitHub, Pull: of.Pull,
		Ultracode: of.Ultracode, Picks: maps.Clone(of.Picks)}
	if of.Worktree != nil {
		wt := *of.Worktree
		wt.AutoName = false
		r.Worktree = &wt
	}
	return r
}

func forkTitle(title string) string {
	if title == "" {
		return ""
	}
	return title + " (fork)"
}

// KeepSide makes a side chat a chat of its own, a fork of its chat (see
// ForkAsChat), and returns its id: its session is no longer thrown away
// but closed on the chat's agent, and the chat's own agent reopens it
// when it's next shown. Its transcript is the chat's as it was when the
// side chat opened, then the side chat's. Only between turns, and for an
// agent that can reopen sessions.
func (s *Service) KeepSide(ctx context.Context, id string) (string, error) {
	s.mu.Lock()
	side := s.chats[id]
	s.mu.Unlock()
	if side == nil || side.parent == nil {
		return "", fmt.Errorf("no side chat %q", id)
	}
	p := side.parent
	p.mu.Lock()
	of, canLoad := p.record, p.canLoad
	p.mu.Unlock()
	side.mu.Lock()
	busy := side.busy || side.ownTurn || len(side.waiting)+len(side.questions) > 0 || side.backgroundLocked(0)
	side.mu.Unlock()
	switch {
	case !canLoad:
		return "", errors.New("the agent can't reopen sessions, so the side chat can't be kept")
	case busy:
		return "", errors.New("the side chat is busy; keep it once its turn has ended")
	}
	// Whoever takes it out of its chat's side chats has it: this, its close
	// (CloseSide) or its chat's agent stopping (dropSides), which delete
	// its session.
	p.mu.Lock()
	mine := p.sides[id] == side
	if mine {
		delete(p.sides, id)
		p.throwawayLocked([]string{id}, true) // kept: no longer one to delete
	}
	p.mu.Unlock()
	if !mine {
		return "", fmt.Errorf("no side chat %q", id)
	}
	s.mu.Lock()
	delete(s.chats, id)
	s.mu.Unlock()
	side.mu.Lock()
	_ = side.cancelLocked() // a turn begun since it was looked at: it was kept as it was
	items := append(slices.Clone(side.base), kept(side.items)...)
	agent, sid, lastItem := side.agent, side.sid, side.lastItem
	// What was picked in the side chat wins over the chat's picks.
	mode, picks := cmp.Or(side.record.Mode, of.Mode), maps.Clone(of.Picks)
	for id, v := range side.record.Picks {
		picks = withPick(picks, id, v)
	}
	side.agent = nil // what still follows it stops
	side.emitLocked(model.Event{ChatID: id, Removed: true})
	side.mu.Unlock()
	if agent != nil {
		if _, err := agent.CloseSession(ctx, &acp.CloseSessionRequest{SessionID: acp.SessionID(sid)}); err != nil {
			side.log().Warn("closing the kept side chat's session", "err", err)
		}
	}

	c := s.newChat(p.kind)
	c.id, c.sid, c.issue = rand.Text(), sid, of.Issue
	c.ultracode.Store(of.Ultracode)
	c.mu.Lock()
	c.record = forkRecord(c.id, sid, of)
	c.record.Mode, c.record.Picks = mode, picks
	c.lastItem = lastItem
	c.forkedLocked(items)
	c.storeLocked()
	c.mu.Unlock()
	s.mu.Lock()
	s.chats[c.id] = c
	s.mu.Unlock()
	c.log().Info("side chat kept", "from", p.id)
	return c.id, nil
}

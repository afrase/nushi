package chats

import (
	"context"
	"errors"
	"log"
	"slices"
	"strings"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// forkPointLocked is where a rewind to just before a new user message forks
// the session: the last message of the agent's own (not a subagent's),
// if the agent named it; "" if there is none.
func (c *chat) forkPointLocked() string {
	for i := len(c.items) - 1; i >= 0; i-- {
		if it := c.items[i]; it.Kind == model.AgentMessage && it.Parent == "" {
			if strings.HasPrefix(it.ID, "item-") { // no messageId: can't fork there
				return ""
			}
			return it.ID
		}
	}
	return ""
}

// Rewind cuts a chat back to just before one of its user messages and
// returns that message. The agent's session is forked at the agent's last
// message before it (or, before the first message, a new session starts):
// a new session id, the same chat. The old session stays as one the chat
// had before (Earlier), so Delete still deletes it. Files aren't rewound.
func (s *Service) Rewind(ctx context.Context, chatID, itemID string) (model.Message, error) {
	c, err := s.chat(chatID)
	if err != nil {
		return model.Message{}, err
	}
	c.mu.Lock()
	i := slices.IndexFunc(c.items, func(it model.Item) bool { return it.ID == itemID })
	first := i >= 0 && !slices.ContainsFunc(c.items[:i], func(it model.Item) bool { return it.Kind == model.UserMessage })
	switch {
	case c.busy:
		err = errors.New("the chat is busy; rewind once the turn has ended")
	case i < 0 || c.items[i].Kind != model.UserMessage:
		err = errors.New("no such message")
	case !c.canRewind || c.agent == nil || c.parent != nil || c.items[i].ForkAt == "" && !first:
		err = errors.New("the agent can't rewind to this message")
	}
	if err != nil {
		c.mu.Unlock()
		return model.Message{}, err
	}
	msg := model.Message{Text: c.items[i].Text, Images: c.items[i].Images}
	agent, sid, folder, at := c.agent, c.sid, c.session.Folder, c.items[i].ForkAt
	c.busy = true
	c.statusChangedLocked()
	c.mu.Unlock()

	var next string
	var config []model.ConfigOption
	if at == "" {
		var resp *acp.NewSessionResponse
		if resp, err = agent.NewSession(ctx, acp.NewSessionRequest{Cwd: folder, MCPServers: []acp.MCPServer{}}); err == nil {
			next, config = string(resp.SessionID), configFrom(resp.ConfigOptions, resp.Modes)
		}
	} else {
		var resp *acp.ForkSessionResponse
		if resp, err = agent.ForkSession(ctx, acp.ForkSessionRequest{SessionID: acp.SessionID(sid), Cwd: folder,
			MCPServers: []acp.MCPServer{}, Meta: airFork(at)}); err == nil {
			next, config = string(resp.SessionID), configFrom(resp.ConfigOptions, resp.Modes)
		}
	}
	c.mu.Lock()
	c.busy = false
	if err != nil {
		c.noticeLocked("error", "Couldn't rewind the chat: "+err.Error())
		c.statusChangedLocked()
		c.mu.Unlock()
		return model.Message{}, err
	}
	c.sid, c.config = next, config
	c.items = c.items[:i]
	c.emitLocked(model.Event{ChatID: c.id, Cut: itemID})
	c.emitLocked(model.Event{ChatID: c.id, Config: slices.Clone(config)})
	c.saveLocked(func(s *model.Session) {
		s.Earlier = append(slices.Clip(s.Earlier), model.AgentSession{ID: s.SessionID, Folder: s.Folder})
		s.SessionID = next
		if first {
			s.Title = "" // a chat without messages again
		}
	})
	c.statusChangedLocked()
	c.mu.Unlock()
	if err := agent.CloseSession(ctx, acp.CloseSessionRequest{SessionID: acp.SessionID(sid)}); err != nil {
		log.Printf("chat %s: closing %s after rewinding: %v", c.id, sid, err)
	}
	if err := c.startMode(ctx, c.session.Mode); err != nil {
		log.Printf("chat %s: mode after rewinding: %v", c.id, err)
	}
	return msg, nil
}

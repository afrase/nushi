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

// rewindableLocked says whether the chat can be rewound to just before its
// item i, a user message: the agent forks at the message before it, or it
// is the first.
func (c *chat) rewindableLocked(i int) bool {
	first := !slices.ContainsFunc(c.items[:i], func(it model.Item) bool { return it.Kind == model.UserMessage })
	return c.canRewind && c.agent != nil && c.parent == nil && (c.items[i].ForkAt != "" || first)
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
	var msg model.Message
	var agent Agent
	var sid, folder, at string
	err = func() error {
		c.mu.Lock()
		defer c.mu.Unlock()
		i := c.indexLocked(itemID)
		switch {
		case c.busy:
			return errors.New("the chat is busy; rewind once the turn has ended")
		case i < 0 || c.items[i].Kind != model.UserMessage:
			return errors.New("no such message")
		case !c.rewindableLocked(i):
			return errors.New("the agent can't rewind to this message")
		}
		msg = model.Message{Text: c.items[i].Text, Images: c.items[i].Images}
		agent, sid, folder, at = c.agent, c.sid, c.session.Folder, c.items[i].ForkAt
		c.busy = true
		c.statusChangedLocked()
		return nil
	}()
	if err != nil {
		return model.Message{}, err
	}

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
	mode, err := func() (string, error) {
		c.mu.Lock()
		defer c.mu.Unlock()
		c.busy = false
		defer c.statusChangedLocked()
		defer c.deliverLocked()
		i := c.indexLocked(itemID) // looked up again: the lock was let go
		switch {
		case err != nil:
		case c.agent != agent:
			err = errors.New("the agent quit")
		case i < 0:
			err = errors.New("the message is gone")
		}
		if err != nil {
			c.noticeLocked("error", "Couldn't rewind the chat: "+err.Error())
			return "", err
		}
		first := !slices.ContainsFunc(c.items[:i], func(it model.Item) bool { return it.Kind == model.UserMessage })
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
		return c.session.Mode, nil
	}()
	if err != nil {
		return model.Message{}, err
	}
	if err := agent.CloseSession(ctx, acp.CloseSessionRequest{SessionID: acp.SessionID(sid)}); err != nil {
		log.Printf("chat %s: closing %s after rewinding: %v", c.id, sid, err)
	}
	if err := c.startMode(ctx, agent, next, mode); err != nil {
		log.Printf("chat %s: mode after rewinding: %v", c.id, err)
	}
	return msg, nil
}

// indexLocked returns the index of the item with id, or -1.
func (c *chat) indexLocked(id string) int {
	return slices.IndexFunc(c.items, func(it model.Item) bool { return it.ID == id })
}

// Stop stops the chat's running turn. With takeBack, if the agent hasn't
// answered the last user message with any text or tool call yet, that
// message is taken back too and returned: the chat is rewound to just
// before it, or, when it can't be, it stays in the transcript and the
// agent's history, with a notice saying so. Otherwise it returns nothing.
func (s *Service) Stop(ctx context.Context, chatID string, takeBack bool) (*model.Message, error) {
	c, err := s.chat(chatID)
	if err != nil {
		return nil, err
	}
	var id string
	var msg model.Message
	var done chan struct{}
	err = func() error {
		c.mu.Lock()
		defer c.mu.Unlock()
		i := len(c.items) - 1
		for i >= 0 && c.items[i].Kind != model.UserMessage {
			i--
		}
		answered := i < 0 || slices.ContainsFunc(c.items[i+1:], func(it model.Item) bool {
			return it.Kind == model.AgentMessage || it.Kind == model.ToolCall
		})
		running := !c.started.IsZero()
		done = c.done
		if err := c.cancelLocked(); err != nil || !takeBack || answered || !running {
			return err
		}
		id, msg = c.items[i].ID, model.Message{Text: c.items[i].Text, Images: c.items[i].Images}
		return nil
	}()
	if err != nil || id == "" {
		return nil, err
	}
	<-done
	can, gone := func() (bool, bool) {
		c.mu.Lock()
		defer c.mu.Unlock()
		i := c.indexLocked(id) // looked up again: the lock was let go
		if i < 0 {
			return false, true // rewound or reloaded meanwhile
		}
		can := c.rewindableLocked(i)
		if !can {
			c.noticeLocked("taken_back", "Your message is back in the box to edit; the agent still has it in its history.")
		}
		return can, false
	}()
	if gone {
		return nil, nil
	}
	if can {
		if _, err := s.Rewind(ctx, chatID, id); err != nil {
			return nil, err
		}
	}
	return &msg, nil
}

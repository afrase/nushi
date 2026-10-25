package chats

import (
	"context"
	"errors"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// forkPointLocked is where a rewind to just before a new user message forks
// the session: the last message of the agent's own (not a subagent's),
// if the agent named it; "" if there is none, or if a user message comes
// after it (one the agent answered without words: a fork there would drop
// it).
func (c *chat) forkPointLocked() string {
	for i := len(c.items) - 1; i >= 0; i-- {
		if it := c.items[i]; it.Kind == model.UserMessage {
			return ""
		} else if it.Kind == model.AgentMessage && it.Parent == "" {
			if strings.HasPrefix(it.ID, "item-") { // no messageId: can't fork there
				return ""
			}
			return it.ID
		}
	}
	return ""
}

// rewindableLocked says whether the chat can be rewound to just before its
// item i, a user message (see model.Item.Rewindable).
func (c *chat) rewindableLocked(i int) bool {
	return c.forkAt != nil && c.agent != nil && c.parent == nil && c.items[i].Rewindable
}

// Rewind cuts a chat back to just before one of its user messages and
// returns that message. The agent's session is forked at the agent's last
// message before it (or, before the first message, a new session starts):
// a new session id, the same chat. The old session stays as one the chat
// had before (Earlier), so Delete still deletes it. Files aren't rewound.
func (s *Service) Rewind(ctx context.Context, chatID, itemID string) (model.Message, error) {
	c, err := s.chat(chatID)
	if err == nil {
		err = s.awake(ctx, c)
	}
	if err != nil {
		return model.Message{}, err
	}
	var msg model.Message
	var agent Agent
	var sid, folder, at string
	var forkAt func(string) map[string]any
	err = func() error {
		c.mu.Lock()
		defer c.mu.Unlock()
		i := c.indexLocked(itemID)
		switch {
		case c.busy:
			return errors.New("the chat is busy; rewind once the turn has ended")
		case c.ownTurn || len(c.waiting)+len(c.questions) > 0:
			return errors.New("the agent is working on its own (a background task ended); stop it, or rewind once it's done")
		case i < 0 || c.items[i].Kind != model.UserMessage:
			return errors.New("no such message")
		case !c.rewindableLocked(i):
			return errors.New("the agent can't rewind to this message")
		}
		msg = messageOf(c.items[i])
		agent, sid, folder, at, forkAt = c.agent, c.sid, c.session.Folder, c.items[i].ForkAt, c.forkAt
		c.busy = true
		c.statusChangedLocked()
		return nil
	}()
	if err != nil {
		return model.Message{}, err
	}

	// What changes the agent's sessions goes on when the app goes: its
	// result is a session the chat must keep or throw away.
	ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), time.Minute)
	defer cancel()
	var next string
	var config []model.ConfigOption
	if at == "" {
		next, config, err = c.newSession(ctx, agent, folder)
	} else {
		next, config, err = c.forkSession(ctx, agent, sid, folder, forkAt(at))
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
			if next != "" { // made, then not used: Delete deletes it, or the next reopen
				c.throwawayLocked([]string{next}, false)
			}
			c.noticeLocked("error", "Couldn't rewind the chat: "+err.Error())
			return "", err
		}
		first := !slices.ContainsFunc(c.items[:i], func(it model.Item) bool { return it.Kind == model.UserMessage })
		// The fork ends with the agent's message at: what came after it
		// (tool calls the agent made after its last text) goes too.
		if j := c.indexLocked(at); at != "" && j >= 0 && j < i {
			i = j + 1
		}
		c.sid, c.config = next, config
		c.emitLocked(model.Event{ChatID: c.id, Cut: c.items[i].ID})
		c.items = c.items[:i]
		c.emitLocked(model.Event{ChatID: c.id, Config: slices.Clone(config)})
		c.saveLocked(func(s *model.Session) {
			s.Earlier = append(slices.Clip(s.Earlier), model.AgentSession{ID: s.SessionID, Folder: s.Folder})
			s.SessionID = next
			if first { // a chat without messages again
				s.Title, s.HasMessages = "", false
			}
		})
		return c.session.Mode, nil
	}()
	if err != nil {
		return model.Message{}, err
	}
	if err := agent.CloseSession(ctx, acp.CloseSessionRequest{SessionID: acp.SessionID(sid)}); err != nil {
		c.log().Warn("closing the session left by the rewind", "old", sid, "err", err)
	}
	if err := c.startMode(ctx, agent, next, mode); err != nil {
		c.log().Warn("mode after rewinding", "err", err)
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
		id, msg = c.items[i].ID, messageOf(c.items[i])
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

package chats

import (
	"cmp"
	"errors"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// relayLocked finds the subagent that tool call callID started, for a
// message the agent is asked to pass to it.
func (c *chat) relayLocked(callID string) (*model.Relay, error) {
	call := c.itemLocked(callID)
	switch {
	case c.dialect.Relay == nil:
		return nil, errors.New("the agent can't pass messages to its subagents")
	case call == nil || call.Agent == "":
		return nil, errors.New("that subagent is no longer in the chat")
	case call.AgentID == "":
		return nil, errors.New("the agent didn't say how to reach that subagent")
	}
	return &model.Relay{Agent: call.Agent, AgentID: call.AgentID}, nil
}

// userItem is a message as the transcript shows it, sent now: one for a
// subagent says which.
func userItem(m model.Message) model.Item {
	it := model.Item{Kind: model.UserMessage, Text: m.Text, Images: m.Images, Files: m.Files, Sent: time.Now()}
	if m.Relay != nil {
		it.RelayTo, it.RelayCall, it.RelayState, it.RelayStop = m.Relay.Agent, m.To, "sending", m.Relay.Stop
	}
	return it
}

// messageOf is a user message back as a message to send again: for a
// subagent still (Message.To), when the transcript knows which.
func messageOf(it model.Item) model.Message {
	m := model.Message{Text: it.Text, Files: it.Files, Images: it.Images, To: it.RelayCall}
	if it.RelayTo != "" {
		m.Relay = &model.Relay{Agent: it.RelayTo, Stop: it.RelayStop}
	}
	return m
}

// relayedLocked reads a replayed user message that asked the agent to pass
// a message to a subagent back into that message (see Dialect.Relayed).
func (c *chat) relayedLocked(it *model.Item) bool {
	if it.Kind != model.UserMessage || it.RelayTo != "" || c.dialect.Relayed == nil {
		return false
	}
	agent, id, text, ok := c.dialect.Relayed(it.Text)
	if !ok && c.dialect.StopRelayed != nil {
		agent, id, ok = c.dialect.StopRelayed(it.Text)
		text, it.RelayStop = "", ok
	}
	if ok {
		it.RelayTo, it.Text = agent, text
		if i := slices.IndexFunc(c.items, func(call model.Item) bool { return taskOf(call) == id }); i >= 0 {
			it.RelayCall = c.items[i].ID
			if it.RelayTo == "" { // a stop names the task by its id only
				it.RelayTo = cmp.Or(c.items[i].Agent, c.items[i].Title)
			}
		}
		it.RelayTo = cmp.Or(it.RelayTo, "task "+id)
	}
	return ok
}

// taskOf is the agent's id for the subagent or background command a tool
// call started, "" when it started neither or the agent didn't say.
func taskOf(call model.Item) string {
	switch {
	case call.Agent != "":
		return call.AgentID
	case call.Shell != nil:
		return call.Shell.ID
	}
	return ""
}

// relayingLocked links a call of the agent's that passes a message on to a
// subagent (Dialect.Relaying) to the user's message it passes, the oldest
// one waiting, and keeps that message's RelayState up to date with it.
func (c *chat) relayingLocked(call model.Item) {
	if c.dialect.Relaying == nil || call.Parent != "" {
		return
	}
	id := c.dialect.Relaying(call)
	sub := slices.IndexFunc(c.items, func(it model.Item) bool { return taskOf(it) == id })
	if id == "" || sub < 0 {
		return
	}
	relays := func(it model.Item) bool { // a stop is passed on by a call that stops
		return it.Kind == model.UserMessage && it.RelayCall == c.items[sub].ID && it.RelayStop == (call.Stops != "")
	}
	i := slices.IndexFunc(c.items, func(it model.Item) bool { return relays(it) && it.RelayedBy == call.ID })
	if i < 0 {
		i = slices.IndexFunc(c.items, func(it model.Item) bool {
			return relays(it) && it.RelayedBy == "" && (it.RelayState == "sending" || it.RelayState == "")
		})
	}
	if i < 0 {
		return // the agent's own message
	}
	m := &c.items[i]
	m.RelayedBy = call.ID
	switch call.Status {
	case "completed":
		m.RelayState = "relayed"
	case "failed":
		m.RelayState = "failed"
	default:
		m.RelayState = "sending"
	}
	c.publishLocked(*m)
}

// unrelayedLocked fails the messages for subagents the agent ended a turn
// without passing on.
func (c *chat) unrelayedLocked() {
	for i, it := range c.items {
		if it.RelayState == "sending" && it.RelayedBy == "" {
			c.items[i].RelayState = "failed"
			c.publishLocked(c.items[i])
		}
	}
}

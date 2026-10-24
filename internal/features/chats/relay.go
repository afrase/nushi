package chats

import (
	"errors"

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

// userItem is a message as the transcript shows it: one for a subagent
// says which.
func userItem(m model.Message) model.Item {
	it := model.Item{Kind: model.UserMessage, Text: m.Text, Images: m.Images, Files: m.Files}
	if m.Relay != nil {
		it.RelayTo, it.RelayCall = m.Relay.Agent, m.To
	}
	return it
}

// messageOf is a user message back as a message to send again: for a
// subagent still (Message.To), when the transcript knows which.
func messageOf(it model.Item) model.Message {
	m := model.Message{Text: it.Text, Files: it.Files, Images: it.Images, To: it.RelayCall}
	if it.RelayTo != "" {
		m.Relay = &model.Relay{Agent: it.RelayTo}
	}
	return m
}

// relayedLocked reads a replayed user message that asked the agent to pass
// a message to a subagent back into that message (see Dialect.Relayed).
func (c *chat) relayedLocked(it *model.Item) bool {
	if it.Kind != model.UserMessage || it.RelayTo != "" || c.dialect.Relayed == nil {
		return false
	}
	agent, text, ok := c.dialect.Relayed(it.Text)
	if ok {
		it.RelayTo, it.Text = agent, text
	}
	return ok
}

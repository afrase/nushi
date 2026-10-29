package chats

import (
	"cmp"
	"errors"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// toSubagentLocked finds the subagent that tool call callID started, for a
// message the agent is asked to pass to it.
func (c *chat) toSubagentLocked(callID string) (*model.ToSubagent, error) {
	call := c.itemLocked(callID)
	switch {
	case c.dialect.ToSubagent == nil:
		return nil, errors.New("the agent can't pass messages to its subagents")
	case call == nil || call.Agent == "":
		return nil, errors.New("that subagent is no longer in the chat")
	case call.AgentID == "":
		return nil, errors.New("the agent didn't say how to reach that subagent")
	}
	return &model.ToSubagent{Agent: call.Agent, AgentID: call.AgentID}, nil
}

// userItem is a message as the transcript shows it, sent now: one for a
// subagent says which.
func userItem(m model.Message) model.Item {
	it := model.Item{Kind: model.UserMessage, Text: m.Text, Images: m.Images, Files: m.Files, Sent: time.Now()}
	if m.ToSubagent != nil {
		it.ToSubagentName, it.ToSubagent, it.ToSubagentState, it.ToSubagentStop = m.ToSubagent.Agent, m.To, "sending", m.ToSubagent.Stop
	}
	return it
}

// messageOf is a user message back as a message to send again: for a
// subagent still (Message.To), when the transcript knows which.
func messageOf(it model.Item) model.Message {
	m := model.Message{Text: it.Text, Files: it.Files, Images: it.Images, To: it.ToSubagent}
	if it.ToSubagentName != "" {
		m.ToSubagent = &model.ToSubagent{Agent: it.ToSubagentName, Stop: it.ToSubagentStop}
	}
	return m
}

// readToSubagentLocked reads a replayed user message that asked the agent
// to pass a message to a subagent back into that message (see
// Dialect.ReadToSubagent).
func (c *chat) readToSubagentLocked(it *model.Item) bool {
	if it.Kind != model.UserMessage || it.ToSubagentName != "" || c.dialect.ReadToSubagent == nil {
		return false
	}
	agent, id, text, ok := c.dialect.ReadToSubagent(it.Text)
	if !ok && c.dialect.ReadStopTask != nil {
		agent, id, ok = c.dialect.ReadStopTask(it.Text)
		text, it.ToSubagentStop = "", ok
	}
	if ok {
		it.ToSubagentName, it.Text = agent, text
		if i := slices.IndexFunc(c.items, func(call model.Item) bool { return taskOf(call) == id }); i >= 0 {
			it.ToSubagent = c.items[i].ID
			if it.ToSubagentName == "" { // a stop names the task by its id only
				it.ToSubagentName = cmp.Or(c.items[i].Agent, c.items[i].Title)
			}
		}
		it.ToSubagentName = cmp.Or(it.ToSubagentName, "task "+id)
	}
	return ok
}

// taskOf is the agent's id for the subagent or background command a tool
// call started, "" when it started neither or the agent didn't say.
func taskOf(call model.Item) string {
	switch {
	case call.Agent != "":
		return call.AgentID
	case call.BackgroundCommand != nil:
		return call.BackgroundCommand.ID
	}
	return ""
}

// passedOnLocked links a call of the agent's that passes a message on to a
// subagent (Dialect.PassesToSubagent) to the user's message it passes, the
// oldest one waiting, and keeps that message's ToSubagentState up to date
// with it.
func (c *chat) passedOnLocked(call model.Item) {
	if c.dialect.PassesToSubagent == nil || call.Parent != "" {
		return
	}
	id := c.dialect.PassesToSubagent(call)
	sub := slices.IndexFunc(c.items, func(it model.Item) bool { return taskOf(it) == id })
	if id == "" || sub < 0 {
		return
	}
	passes := func(it model.Item) bool { // a stop is passed on by a call that stops
		return it.Kind == model.UserMessage && it.ToSubagent == c.items[sub].ID && it.ToSubagentStop == (call.Stops != "")
	}
	i := slices.IndexFunc(c.items, func(it model.Item) bool { return passes(it) && it.PassedOnBy == call.ID })
	if i < 0 {
		i = slices.IndexFunc(c.items, func(it model.Item) bool {
			return passes(it) && it.PassedOnBy == "" && (it.ToSubagentState == "sending" || it.ToSubagentState == "")
		})
	}
	if i < 0 {
		return // the agent's own message
	}
	m := &c.items[i]
	m.PassedOnBy = call.ID
	switch call.Status {
	case "completed":
		m.ToSubagentState = "relayed"
	case "failed":
		m.ToSubagentState = "failed"
	default:
		m.ToSubagentState = "sending"
	}
	c.publishLocked(*m)
}

// notPassedOnLocked fails the messages for subagents the agent ended a turn
// without passing on.
func (c *chat) notPassedOnLocked() {
	for i, it := range c.items {
		if it.ToSubagentState == "sending" && it.PassedOnBy == "" {
			c.items[i].ToSubagentState = "failed"
			c.publishLocked(c.items[i])
		}
	}
}

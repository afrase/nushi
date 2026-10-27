package chats

import (
	"errors"
	"slices"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// An agent that shows its subagents as sessions of their own (ACP's
// subagents RFD; Dialect.Subagents) announces each on the session that
// started it (subagent_update), sends the subagent's work on the child's
// session, and says when it runs and when it ends, and why. The child's
// first message names the tool call that started it. Its updates are the
// chat's, as the subagent's steps; its end is the subagent's state; and
// cancelling the child's session stops the subagent alone.

// child is one of those sessions, as the chat that owns the agent's
// connection keeps it: the chat (or side chat) the subagent works for,
// the tool call its first message named, and what the agent last said of
// its state ("" before it said; see model.Subagent.Said).
type child struct {
	owner  *chat
	launch string
	said   string
}

// childUpdate takes an update about a child session: its announcement or
// state (on the session it works for), or its first message. It says
// whether it took n.
func (c *chat) childUpdate(n *acp.SessionNotification) bool {
	u := n.Update
	var sid acp.SessionID
	switch {
	case u.SubagentUpdate != nil:
		sid = u.SubagentUpdate.SessionID
	case u.SessionMessage != nil:
		sid = n.SessionID
	default:
		return false
	}
	c.mu.Lock()
	ch := c.children[string(sid)]
	if ch == nil && u.SubagentUpdate != nil {
		if owner, _ := c.routeLocked(n.SessionID); owner != nil {
			ch = &child{owner: owner}
			c.children[string(sid)] = ch
		}
	}
	if ch == nil {
		c.mu.Unlock()
		return true
	}
	if m := u.SessionMessage; m != nil && ch.launch == "" {
		ch.launch = string(m.MessageID)
	}
	if su := u.SubagentUpdate; su != nil {
		if said, ok := saidOf(su.State); ok {
			ch.said = said
		}
	}
	got := *ch
	c.mu.Unlock()
	got.owner.mu.Lock()
	got.owner.childSaidLocked(got, string(sid))
	got.owner.mu.Unlock()
	return true
}

// saidEnd says a child's state is an end.
func saidEnd(said string) bool { return said != "" && said != "running" }

// saidOf reads a child's state: "running" while it works or waits on the
// user, its end once idle ("done", "stopped" when cancelled, "failed"; an
// end the agent can't explain, as when its process went, is "stopped").
// An unknown or cleared state says nothing.
func saidOf(st acp.Nullable[acp.StateUpdate]) (string, bool) {
	s := st.Value
	switch {
	case s == nil:
		return "", false
	case s.Running != nil, s.RequiresAction != nil:
		return "running", true
	case s.Idle == nil:
		return "", false
	}
	switch s.Idle.StopReason {
	case "end_turn":
		return "done", true
	case "cancelled", "":
		return "stopped", true
	}
	return "failed", true
}

// subagentCallLocked is the subagent call a child session works for: the
// call its first message named; or, when that is a call that passed it a
// message (and so ran it again), or the session never named one, the
// subagent call with the agent's id for it.
func (c *chat) subagentCallLocked(launch, sid string) *model.Item {
	id := sid
	if it := c.itemLocked(launch); it != nil && it.Agent != "" {
		return it
	} else if it != nil && it.AgentID != "" {
		id = it.AgentID
	}
	if i := slices.IndexFunc(c.items, func(it model.Item) bool { return it.Agent != "" && it.AgentID == id }); i >= 0 {
		return &c.items[i]
	}
	return nil
}

// childSaidLocked brings the subagent a child works for up to date with
// what the agent said of it. During a replay the call isn't the
// transcript's yet: restoreLocked comes back to it (childrenSaidLocked).
func (c *chat) childSaidLocked(ch child, sid string) {
	if c.replaying {
		return
	}
	call := c.subagentCallLocked(ch.launch, sid)
	if call == nil || call.Subagent == nil && call.Agent == "" {
		return
	}
	sa := model.Subagent{}
	if call.Subagent != nil {
		sa = *call.Subagent
	}
	said := ch.said
	if saidEnd(sa.Said) && saidEnd(said) {
		said = sa.Said // as first said: a replay may tell a stop otherwise
	}
	if sa.Said == said && sa.Session == sid {
		return
	}
	sa.Said, sa.Session = said, sid
	call.Subagent = &sa
	c.subagentLocked(call)
	c.publishLocked(*call)
}

// childrenSaidLocked brings every subagent of the chat up to date with what
// the agent said of it, after its transcript was made anew.
func (c *chat) childrenSaidLocked() {
	if c.parent != nil {
		return // a side chat isn't replayed
	}
	for sid, ch := range c.children {
		if ch.owner == c {
			c.childSaidLocked(*ch, sid)
		}
	}
}

// childOfLocked is the subagent call a child session's updates are steps of,
// "" when it isn't known yet (Dialect.Parent may say).
func (c *chat) childOfLocked(ch *child, sid string) string {
	if ch == nil {
		return ""
	}
	if call := c.subagentCallLocked(ch.launch, sid); call != nil {
		return call.ID
	}
	return ch.launch
}

// StopTask stops one of the agent's background tasks: the subagent or the
// background command tool call callID started. A subagent the agent shows
// as a session of its own stops when that session is cancelled; any other
// is stopped by asking the agent (Dialect.StopTask), as a message of the
// user's that waits for the agent's next chance. Either way it shows as
// stopped only once the agent says so.
func (s *Service) StopTask(chatID, callID string) error {
	c, err := s.chat(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	call := c.itemLocked(callID)
	switch {
	case call == nil:
		c.mu.Unlock()
		return errors.New("that task is no longer in the chat")
	case !runs(*call):
		c.mu.Unlock()
		return errors.New("that task isn't running")
	}
	if sa := call.Subagent; sa != nil && sa.Session != "" && c.agent != nil {
		agent, sid := c.agent, sa.Session
		c.logLocked().Info("stopping a subagent", "call", callID)
		c.mu.Unlock()
		return cancelTurn(agent, &acp.CancelNotification{SessionID: acp.SessionID(sid)})
	}
	c.mu.Unlock()
	return s.Prompt(chatID, model.Message{To: callID, Relay: &model.Relay{Stop: true}}, SendQueue)
}

// runs says the subagent or background command a tool call started runs.
func runs(call model.Item) bool {
	return call.Subagent != nil && call.Subagent.State == "running" || call.Shell != nil && call.Shell.State == "running"
}

// stopRelayLocked finds what a message asking the agent to stop the task
// callID started is about: the subagent (its type) or the background
// command, and the agent's id for it.
func (c *chat) stopRelayLocked(callID string) (*model.Relay, error) {
	call := c.itemLocked(callID)
	switch {
	case c.dialect.StopTask == nil:
		return nil, errors.New("the agent can't be asked to stop its tasks")
	case call == nil:
		return nil, errors.New("that task is no longer in the chat")
	case call.Shell != nil:
		return &model.Relay{Agent: call.Title, AgentID: call.Shell.ID, Stop: true}, nil
	case call.Agent != "" && call.AgentID != "":
		return &model.Relay{Agent: call.Agent, AgentID: call.AgentID, Stop: true}, nil
	}
	return nil, errors.New("the agent didn't say how to reach that task")
}

// stoppedLocked takes a tool call that stopped one of the agent's tasks, or
// found it already ended (Dialect.Stopped): a subagent the agent never said
// ended has.
func (c *chat) stoppedLocked(call model.Item) {
	if c.dialect.Stopped == nil || call.Parent != "" {
		return
	}
	id := c.dialect.Stopped(call)
	i := slices.IndexFunc(c.items, func(it model.Item) bool { return it.Agent != "" && it.AgentID == id })
	if id == "" || i < 0 || c.items[i].Subagent == nil || c.items[i].Subagent.State != "running" {
		return
	}
	sa := *c.items[i].Subagent
	sa.Said = "stopped"
	c.items[i].Subagent = &sa
	c.subagentLocked(&c.items[i])
	c.publishLocked(c.items[i])
}

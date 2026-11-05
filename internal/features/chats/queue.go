package chats

import (
	"context"
	"errors"
	"slices"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// deliverLocked hands the queue to the agent at its chance: while a turn
// runs, into the turn when the agent can be steered; when the chat is
// idle, the first message as the next prompt. A turn the user stopped
// takes nothing more: its end holds the queue (run), and a tool call the
// stop fails would otherwise steer the next message into it.
func (c *chat) deliverLocked() {
	switch {
	case len(c.queue) == 0 || c.agent == nil || c.stopping || c.halting || c.held || c.steering || c.sendingNow > 0:
	case !c.busy:
		m := c.queue[0]
		c.queue = c.queue[1:]
		c.queueChangedLocked()
		c.sendLocked(m)
	case c.steer && !c.started.IsZero() && !c.stopped:
		c.steering = true
		go c.steerQueue(c.agent, acp.SessionID(c.sid))
	}
}

// unsteerLocked marks the message id, added as steered, as the prompt of
// the turn it now starts instead.
func (c *chat) unsteerLocked(id string) {
	if i := c.indexLocked(id); i >= 0 {
		c.items[i].Steered = false
		c.publishLocked(c.items[i])
	}
}

// steerQueue hands the queue's messages to the running turn one at a time,
// in order; it is the chat's only steering worker while it runs. A message
// the agent doesn't take because the turn has just ended starts the next
// turn, unless the turn was stopped: then it goes back to the queue. A
// Stop while a message is out ends the hand-off there: the rest waits.
//
//nolint:contextcheck // a queued message is steered in after the request that queued it
func (c *chat) steerQueue(agent Agent, sid acp.SessionID) {
	c.mu.Lock()
	defer c.mu.Unlock()
	defer func() { c.steering = false }()
	for len(c.queue) > 0 && c.agent == agent && !c.stopping && !c.halting && !c.stopped && !c.started.IsZero() {
		m := c.queue[0]
		c.queue = c.queue[1:]
		c.queueChangedLocked()
		it := userItem(m)
		it.Steered = true
		id := c.addLocked(it)
		blocks := c.blocks(m)
		// The agent's updates may come before its answer: not under the lock;
		// counted before, as they may be the result of the work it cuts short.
		c.steered++
		c.mu.Unlock()
		taken, err := agent.Steer(context.Background(), sid, blocks)
		c.mu.Lock()
		if !taken {
			c.steered = max(c.steered-1, 0)
		}
		switch {
		case taken:
			continue
		case c.indexLocked(id) < 0:
			return // taken back (Stop) meanwhile: it is in the box
		case err == nil && !c.busy && c.agent == agent && !c.held && !c.stopped && !c.stopping && !c.halting && c.sendingNow == 0:
			c.unsteerLocked(id)
			c.startLocked(blocks) // the turn ended meanwhile: this starts the next
			return
		}
		c.unsendLocked(id)
		if err != nil {
			c.noticeLocked("error", "Couldn't hand your message to the agent; it's back in the queue: "+err.Error())
		}
		c.queue = append([]model.Message{m}, c.queue...)
		c.queueChangedLocked()
		return
	}
	// The turn ended while a message was out: its end found this worker
	// running and delivered nothing, so the rest goes as the next prompt.
	// Not in the defer: the failed hand-off above puts its message back,
	// and that waits for the next chance.
	c.steering = false
	if !c.busy {
		c.deliverLocked()
	}
}

// unsendLocked takes a message the agent never got out of the transcript,
// wherever it is: what came after it stays.
func (c *chat) unsendLocked(id string) {
	if i := c.indexLocked(id); i >= 0 {
		c.dropCopyLocked(c.items[i])
		c.items = slices.Delete(c.items, i, i+1)
		c.emitLocked(model.Event{ChatID: c.id, Dropped: id})
		c.unpinGoneLocked()
	}
}

// Unqueue takes a message out of the chat's queue and returns it, before
// the agent gets it.
func (s *Service) Unqueue(chatID, id string) (model.Message, error) {
	c, err := s.lookup(chatID) // a side chat's too
	if err != nil {
		return model.Message{}, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	i := slices.IndexFunc(c.queue, func(m model.Message) bool { return m.ID == id })
	if i < 0 {
		return model.Message{}, errors.New("the agent has it already")
	}
	m := c.queue[i]
	c.queue = slices.Delete(c.queue, i, i+1)
	c.queueChangedLocked()
	return m, nil
}

func (c *chat) queueChangedLocked() {
	q := slices.Clone(c.queue)
	c.emitLocked(model.Event{ChatID: c.id, Queue: &q})
}

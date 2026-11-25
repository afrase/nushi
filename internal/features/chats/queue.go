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
	case len(c.queue) == 0 || c.steering:
	case c.mayStartLocked():
		m := c.queue[0]
		c.queue = c.queue[1:]
		c.queueChangedLocked()
		c.sendLocked(c.imagesTakenLocked(m))
	case c.mayDeliverLocked() && c.steer && !c.started.IsZero() && !c.stopped && !c.steerFailed:
		c.steering = true
		go c.steerQueue(c.agent, acp.SessionID(c.sid))
	}
}

// mayStartLocked says the queue's next message may start a turn now: the
// chat is idle, and the queue may go to its agent (mayDeliverLocked).
func (c *chat) mayStartLocked() bool { return !c.busyLocked() && c.mayDeliverLocked() }

// mayDeliverLocked says the queue may go to the chat's agent at all: it
// has one that isn't being stopped, the queue isn't held after a stopped
// or failed turn, and no Send now is on its way, which goes first.
func (c *chat) mayDeliverLocked() bool {
	return c.agent != nil && !c.stopping && !c.halting && !c.held && c.sendingNow == 0
}

// imagesTakenLocked is a queued message as it goes to the agent: without
// its images, said so, when the agent takes none. Whether it does is known
// only once the chat has its agent, so a message queued while the chat
// reopened is checked as it goes, not as it was queued.
func (c *chat) imagesTakenLocked(m model.Message) model.Message {
	if len(m.Images) == 0 || c.canImage {
		return m
	}
	c.noticeLocked(model.NoticeError, "The agent doesn't take images: your queued message went without them.")
	m.Images = nil
	return m
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
		m := c.imagesTakenLocked(c.queue[0])
		c.queue = c.queue[1:]
		c.queueChangedLocked()
		it := userItem(m)
		it.Steered = true
		id := c.addLocked(it)
		blocks := c.blocks(m)
		// The agent's updates may come before its answer: not under the lock.
		c.mu.Unlock()
		taken, err := agent.Steer(context.Background(), sid, blocks)
		c.mu.Lock()
		switch {
		case taken:
			continue
		case c.indexLocked(id) < 0:
			return // taken back (Stop) meanwhile: it is in the box
		case err == nil && c.agent == agent && !c.stopped && c.mayStartLocked():
			c.unsteerLocked(id)
			c.startLocked(blocks) // the turn ended meanwhile: this starts the next
			return
		}
		c.unsendLocked(id)
		if err != nil { // said once: the turn's later tool ends don't try again
			c.steerFailed = true
			c.noticeLocked(model.NoticeError, "Couldn't hand your message to the agent; it's back in the queue: "+err.Error())
		}
		c.queue = append([]model.Message{m}, c.queue...)
		c.queueChangedLocked()
		if err != nil && !c.busyLocked() { // the turn ended meanwhile: the queue, a message sent since among it, goes as the next prompt
			c.steering = false
			c.deliverLocked()
		}
		return
	}
	// The turn ended while a message was out: its end found this worker
	// running and delivered nothing, so the rest goes as the next prompt.
	// Not in the defer: the failed hand-off above puts its message back,
	// and that waits for the next chance.
	c.steering = false
	if !c.busyLocked() {
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
	m, _, err := c.unqueueLocked(id)
	return m, err
}

// unqueueLocked takes message id out of the queue: it and where it was.
func (c *chat) unqueueLocked(id string) (model.Message, int, error) {
	i := slices.IndexFunc(c.queue, func(m model.Message) bool { return m.ID == id })
	if i < 0 {
		return model.Message{}, 0, errors.New("the agent has it already")
	}
	m := c.queue[i]
	c.queue = slices.Delete(c.queue, i, i+1)
	c.queueChangedLocked()
	return m, i, nil
}

// SendQueuedNow sends a message of the chat's queue at once, as Prompt's
// SendNow does (the running turn stops first), in one call: if the send
// fails or ctx ends first (the app went while the agent wound its turn
// down), the message goes back to its place in the queue, so no failure
// loses it.
func (s *Service) SendQueuedNow(ctx context.Context, chatID, id string) error {
	c, m, at, err := s.takeToSend(chatID, id)
	if err != nil {
		return err
	}
	return s.sendTaken(ctx, c, m, at)
}

// takeToSend takes a message out of the chat's queue for SendQueuedNow,
// and counts it as a Send now on its way (sendingNow) in the same hold:
// till sendTaken has sent it, the chat isn't quiet, so a restart can't
// begin (Rest) and refuse it into a queue that dies with the daemon, and
// the queue starts nothing ahead of it.
func (s *Service) takeToSend(chatID, id string) (*chat, model.Message, int, error) {
	c, err := s.lookup(chatID) // a side chat's too
	if err != nil {
		return nil, model.Message{}, 0, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	m, at, err := c.unqueueLocked(id)
	if err == nil {
		c.sendingNow++
	}
	return c, m, at, err
}

// sendTaken sends m, which takeToSend took from the queue's place at, and
// ends its count: the queue goes on, with m back in its place if it
// didn't go.
func (s *Service) sendTaken(ctx context.Context, c *chat, m model.Message, at int) error {
	send := m
	send.ID = "" // a new message, as the box's
	err := s.Prompt(ctx, c.id, send, SendNow)
	c.mu.Lock()
	defer c.mu.Unlock()
	c.sendingNow--
	if err != nil {
		c.queue = slices.Insert(c.queue, min(at, len(c.queue)), m)
		c.queueChangedLocked()
	}
	if !c.busyLocked() {
		c.deliverLocked()
	}
	return err
}

func (c *chat) queueChangedLocked() {
	q := slices.Clone(c.queue)
	c.emitLocked(model.Event{ChatID: c.id, Queue: &q})
}

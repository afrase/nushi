package chats

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"path/filepath"
	"slices"
	"strings"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/model"
)

// Send says what a prompt does while the chat is busy.
type Send int

const (
	SendIdle  Send = iota // refused
	SendQueue             // waits in the chat's queue for the agent's next chance
	SendNow               // stops the running turn and goes at once
)

// Prompt sends a message to the chat's agent, with links to the files it
// mentions and its images. The turn runs in the background; its progress
// arrives as events. A chat whose agent isn't running is reopened, and the
// message waits in the queue until it is. SendNow waits for the stopped
// turn to end, or for ctx: an agent that ignores the cancel doesn't keep
// the call.
func (s *Service) Prompt(ctx context.Context, chatID string, m model.Message, how Send) error {
	if n := size(m); n > agentproc.MaxMessage-64<<10 {
		return fmt.Errorf("the message is too large to send: %d MB with its images, and the agent takes about %d MB", n>>20, agentproc.MaxMessage>>20)
	}
	c, err := s.chat(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	// Each wait lets go of the lock, so everything is checked again after
	// it. Only the turn running when SendNow came is stopped: the queue
	// starts none meanwhile, and the message goes once it has ended.
	waited, sent := false, false
	defer func() {
		if waited {
			c.sendingNow--
			if !sent {
				c.deliverLocked()
			}
		}
	}()
	for {
		if err := s.refusesLocked(c); err != nil {
			return err
		}
		if c.asleep {
			c.logLocked().Info("chat waking", "for", "a message")
		}
		c.reopenFailed, c.asleep = false, false // a message tries again, and wakes it
		s.reopenLocked(c)
		if how != SendNow || c.started.IsZero() || waited {
			break
		}
		done := c.done
		if err := c.cancelLocked(); err != nil {
			return err
		}
		waited = true
		c.sendingNow++
		c.mu.Unlock()
		select {
		case <-done:
		case <-ctx.Done():
			c.mu.Lock() // the deferred unlock's, and sendingNow's
			return ctx.Err()
		}
		c.mu.Lock()
	}
	if err := c.relayOfLocked(&m); err != nil {
		return err
	}
	switch {
	case c.reopeningLocked() || c.busy && how == SendQueue:
		m.ID = rand.Text()
		c.queue = append(c.queue, m)
		c.queueChangedLocked()
		if c.reopeningLocked() {
			c.held = false // a new message is the held queue's chance
		}
	case c.busy:
		return errors.New("the agent is still working on the last prompt")
	case len(m.Images) > 0 && !c.canImage:
		return errors.New("the agent doesn't take images")
	default:
		c.sendLocked(m)
		sent = true
	}
	return nil
}

// refusesLocked says why the chat takes no prompt now; nil when it does.
// Prompt holds the chat's lock from this check until the turn has started
// or the message is queued, both of which Rest sees.
func (s *Service) refusesLocked(c *chat) error {
	if s.resting.Load() {
		return ErrRestarting
	}
	if err := c.closedLocked(); err != nil {
		return err
	}
	if err := folderGone(c.session); err != nil {
		return fmt.Errorf("the chat can't go on: %w", err)
	}
	if c.sessionGone {
		return errors.New("the chat can't go on: " + c.kind.goneText())
	}
	return nil
}

// relayOfLocked finds what a message for a subagent (or a stop of a task)
// goes to, from the tool call it names (Message.To).
func (c *chat) relayOfLocked(m *model.Message) error {
	if m.To == "" {
		return nil
	}
	relay := c.relayLocked
	if m.Relay != nil && m.Relay.Stop {
		relay = c.stopRelayLocked
	}
	r, err := relay(m.To)
	m.Relay = r
	return err
}

// closedLocked says why a chat takes no prompts: it is archived, being
// deleted, or its agent is stopping; nil when it takes them.
func (c *chat) closedLocked() error {
	switch {
	case c.session.Archived:
		return errors.New("the chat is archived")
	case c.halting:
		return errors.New("the chat is being deleted")
	case c.stopping:
		return errors.New("the chat's agent is stopping")
	}
	return nil
}

// sendLocked shows the message in the transcript and starts a turn with it.
func (c *chat) sendLocked(m model.Message) {
	c.addLocked(userItem(m))
	c.saveLocked(func(s *model.Session) {
		s.HasMessages = true
		if s.Title == "" {
			s.Title = title(m.Text)
		}
	})
	c.startLocked(c.blocks(m))
}

// startLocked starts a turn with prompt, after notes of where the chat
// works (moved, its folder's branch switched) and its worktree's branch
// renamed since the last one, if they were. The prompt is written to
// the agent in the background; a cancel waits for it (see cancelLocked).
func (c *chat) startLocked(prompt []acp.ContentBlock) {
	if c.agent == nil {
		c.noticeLocked("error", "The agent isn't running; send the message again to reopen the chat.")
		return
	}
	notes, told := c.notesLocked()
	prompt = append(notes, prompt...)
	sent, done := make(chan struct{}), make(chan struct{})
	c.busy, c.started, c.done, c.sent, c.held = true, time.Now(), done, sent, false
	c.released, c.steered, c.turnFrom, c.stopped = false, 0, len(c.items), false
	c.statusChangedLocked()
	c.logLocked().Info("turn started", "queued", len(c.queue))
	go c.run(c.agent, &acp.PromptRequest{SessionID: acp.SessionID(c.sid), Prompt: prompt}, told, sent, done)
}

// releaseLocked ends the running turn for the chat while the agent still
// holds its prompt open for subagents the turn left running in the
// background (see Dialect.TurnDone): the chat is idle, a message goes as
// the next prompt (which the agent takes at once, answering the held one),
// and the subagents' steps and the agent's answer to their reports come as
// its own work. The held prompt's answer then changes nothing (run).
func (c *chat) releaseLocked() {
	c.logLocked().Info("turn's work ended", "took", time.Since(c.started).Round(time.Millisecond), "held_for", "background subagents")
	c.released, c.busy, c.started = true, false, time.Time{}
	close(c.done)
	c.unrelayedLocked()
	c.copyLocked(true)
	c.endedLocked()
	c.statusChangedLocked()
	c.deliverLocked()
}

// backgroundLocked says a subagent the agent started (since item from)
// runs on in the background.
func (c *chat) backgroundLocked(from int) bool {
	return slices.ContainsFunc(c.items[min(from, len(c.items)):], func(it model.Item) bool { return it.Subagent != nil && it.Subagent.State == "running" })
}

// blocks makes a message the agent's content: the text, links to the files
// and the images.
func (c *chat) blocks(m model.Message) []acp.ContentBlock {
	text := m.Text
	switch r := m.Relay; {
	case r != nil && r.Stop:
		text = c.dialect.StopTask(r.Agent, r.AgentID)
	case r != nil:
		text = c.dialect.Relay(r.Agent, r.AgentID, text)
	}
	prompt := []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: text}}}
	for _, f := range m.Files {
		path := filepath.Join(c.session.Folder, f)
		prompt = append(prompt, acp.ContentBlock{Type: "resource_link", ResourceLink: &acp.ResourceLink{
			Name: f, URI: (&url.URL{Scheme: "file", Path: path}).String()}})
	}
	for _, img := range m.Images {
		prompt = append(prompt, acp.ContentBlock{Type: "image", Image: &acp.ImageContent{
			MimeType: img.MimeType, Data: base64.StdEncoding.EncodeToString(img.Data)}})
	}
	return prompt
}

// size is about how much of a prompt's frame a message takes: its text, and
// its images in base64.
func size(m model.Message) int {
	n := len(m.Text)
	for _, img := range m.Images {
		n += base64.StdEncoding.EncodedLen(len(img.Data))
	}
	return n
}

// title makes a chat's title from its first prompt: the first line, cut short.
func title(prompt string) string {
	line, _, _ := strings.Cut(strings.TrimSpace(prompt), "\n")
	if r := []rune(line); len(r) > 80 {
		return string(r[:79]) + "…"
	}
	return line
}

//nolint:contextcheck // a turn outlives the request that started it
func (c *chat) run(agent Agent, req *acp.PromptRequest, t *told, sent, done chan struct{}) {
	wait, err := agent.StartPrompt(context.Background(), req)
	close(sent)
	var resp *acp.PromptResponse
	if err == nil {
		if t != nil { // it went: the agent has the branch's name
			c.mu.Lock()
			c.toldLocked(t)
			c.mu.Unlock()
		}
		resp, err = wait(context.Background())
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.done != done || c.released { // released: its end was the chat's already
		c.released = c.released && c.done != done
		c.logLocked().Info("held prompt answered", "err", err)
		return
	}
	if log := c.logLocked().With("took", time.Since(c.started).Round(time.Millisecond)); err != nil {
		log.Warn("turn failed", "err", err)
	} else {
		log.Info("turn ended", "stop", resp.StopReason)
	}
	c.busy, c.started = false, time.Time{}
	close(c.done)
	c.unrelayedLocked()
	if err == nil && resp.Usage != nil {
		u := resp.Usage
		c.usage.Input, c.usage.Output = int64(u.InputTokens), int64(u.OutputTokens) //nolint:gosec // token counts, far below the limits
		c.usage.CachedRead, c.usage.CachedWrite = tokens(u.CachedReadTokens), tokens(u.CachedWriteTokens)
		c.usageChangedLocked()
	}
	quit := errors.Is(err, acp.ErrClosed) // the agent's connection ended: watch says so
	select {
	case <-agent.Done():
		quit = true
	default:
	}
	switch {
	case err != nil && !quit:
		c.noticeLocked("error", "The turn failed: "+err.Error())
	case err != nil:
	case resp.StopReason == "cancelled":
		c.noticeLocked("cancelled", "Stopped")
	case resp.StopReason == "refusal":
		c.noticeLocked("refusal", "The agent refused to go on")
	case resp.StopReason == "max_tokens":
		c.noticeLocked("max_tokens", "The agent stopped: it reached its token limit")
	case resp.StopReason == "max_turn_requests":
		c.noticeLocked("max_turn_requests", "The agent stopped: it reached its limit of requests in one turn")
	}
	c.nameBranchLocked() // between turns, before the next one starts
	// Unseen unless stopped or the agent went (watch says so); marked
	// before the status, so a client has it as the turn ends.
	if stopped := err == nil && resp.StopReason == "cancelled"; !stopped && (err == nil || !quit) {
		c.endedLocked()
	}
	c.statusChangedLocked()
	c.copyLocked(true)
	// A stopped or failed turn holds the queue until the next one ends.
	c.held = err != nil || resp.StopReason == "cancelled"
	c.deliverLocked()
}

// deliverLocked hands the queue to the agent at its chance: while a turn
// runs, into the turn when the agent can be steered; when the chat is
// idle, the first message as the next prompt.
func (c *chat) deliverLocked() {
	switch {
	case len(c.queue) == 0 || c.agent == nil || c.stopping || c.halting || c.held || c.steering || c.sendingNow > 0:
	case !c.busy:
		m := c.queue[0]
		c.queue = c.queue[1:]
		c.queueChangedLocked()
		c.sendLocked(m)
	case c.steer && !c.started.IsZero():
		c.steering = true
		go c.steerQueue(c.agent, acp.SessionID(c.sid))
	}
}

// steerQueue hands the queue's messages to the running turn one at a time,
// in order; it is the chat's only steering worker while it runs. A message
// the agent doesn't take because the turn has just ended starts the next
// turn, unless the turn was stopped: then it goes back to the queue.
//
//nolint:contextcheck // a queued message is steered in after the request that queued it
func (c *chat) steerQueue(agent Agent, sid acp.SessionID) {
	c.mu.Lock()
	defer c.mu.Unlock()
	defer func() { c.steering = false }()
	for len(c.queue) > 0 && c.agent == agent && !c.stopping && !c.halting && !c.started.IsZero() {
		m := c.queue[0]
		c.queue = c.queue[1:]
		c.queueChangedLocked()
		id := c.addLocked(userItem(m))
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
		case err == nil && !c.busy && c.agent == agent && !c.held && !c.stopping && !c.halting && c.sendingNow == 0:
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

// tokens is a count the agent may not report, as 0 when it doesn't.
func tokens(n *uint64) int64 {
	if n == nil {
		return 0
	}
	return int64(*n) //nolint:gosec // token counts, far below the limits
}

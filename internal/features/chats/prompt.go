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

	"github.com/afrase/nushi/acp"
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
// message waits in the queue until it is.
func (s *Service) Prompt(chatID string, m model.Message, how Send) error {
	c, err := s.chat(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	// Each wait lets go of the lock, so everything is checked again after it.
	for {
		if err := c.closedLocked(); err != nil {
			return err
		}
		if err := folderGone(c.session); err != nil {
			return fmt.Errorf("the chat can't go on: %w", err)
		}
		s.reopenLocked(c)
		if how != SendNow || c.started.IsZero() {
			break
		}
		done := c.done
		if err := c.cancelLocked(); err != nil {
			return err
		}
		c.mu.Unlock()
		<-done
		c.mu.Lock()
	}
	switch {
	case c.reopeningLocked() || c.busy && how == SendQueue:
		m.ID = rand.Text()
		c.queue = append(c.queue, m)
		c.queueChangedLocked()
	case c.busy:
		return errors.New("the agent is still working on the last prompt")
	case len(m.Images) > 0 && !c.canImage:
		return errors.New("the agent doesn't take images")
	default:
		c.sendLocked(m)
	}
	return nil
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
	c.addLocked(model.Item{Kind: model.UserMessage, Text: m.Text, Images: m.Images})
	c.saveLocked(func(s *model.Session) {
		s.HasMessages = true
		if s.Title == "" {
			s.Title = title(m.Text)
		}
	})
	c.startLocked(c.blocks(m))
}

// startLocked starts a turn with prompt. The prompt is written to the agent
// in the background; a cancel waits for it (see cancelLocked).
func (c *chat) startLocked(prompt []acp.ContentBlock) {
	if c.agent == nil {
		c.noticeLocked("error", "The agent isn't running; send the message again to reopen the chat.")
		return
	}
	sent := make(chan struct{})
	c.busy, c.started, c.done, c.sent, c.held = true, time.Now(), make(chan struct{}), sent, false
	c.statusChangedLocked()
	go c.run(c.agent, acp.PromptRequest{SessionID: acp.SessionID(c.sid), Prompt: prompt}, sent)
}

// blocks makes a message the agent's content: the text, links to the files
// and the images.
func (c *chat) blocks(m model.Message) []acp.ContentBlock {
	prompt := []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: m.Text}}}
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

// title makes a chat's title from its first prompt: the first line, cut short.
func title(prompt string) string {
	line, _, _ := strings.Cut(strings.TrimSpace(prompt), "\n")
	if r := []rune(line); len(r) > 80 {
		return string(r[:79]) + "…"
	}
	return line
}

func (c *chat) run(agent Agent, req acp.PromptRequest, sent chan struct{}) {
	wait, err := agent.StartPrompt(req)
	close(sent)
	var resp *acp.PromptResult
	if err == nil {
		resp, err = wait(context.Background())
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.busy, c.started = false, time.Time{}
	close(c.done)
	if err == nil && resp.Usage != nil {
		u := resp.Usage
		c.usage.Input, c.usage.Output, c.usage.CachedRead, c.usage.CachedWrite = u.InputTokens, u.OutputTokens, u.CachedReadTokens, u.CachedWriteTokens
		c.usageChangedLocked()
	}
	quit := false
	select {
	case <-agent.Done():
		quit = true // the agent's process ended: watch says so
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
	c.statusChangedLocked()
	// A stopped or failed turn holds the queue until the next one ends.
	c.held = err != nil || resp.StopReason == "cancelled"
	c.deliverLocked()
}

// deliverLocked hands the queue to the agent at its chance: while a turn
// runs, into the turn when the agent can be steered; when the chat is
// idle, the first message as the next prompt.
func (c *chat) deliverLocked() {
	switch {
	case len(c.queue) == 0 || c.agent == nil || c.stopping || c.halting || c.held || c.steering:
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
func (c *chat) steerQueue(agent Agent, sid acp.SessionID) {
	c.mu.Lock()
	defer c.mu.Unlock()
	defer func() { c.steering = false }()
	for len(c.queue) > 0 && c.agent == agent && !c.stopping && !c.halting && !c.started.IsZero() {
		m := c.queue[0]
		c.queue = c.queue[1:]
		c.queueChangedLocked()
		id := c.addLocked(model.Item{Kind: model.UserMessage, Text: m.Text, Images: m.Images})
		blocks := c.blocks(m)
		// The agent's updates may come before its answer: not under the lock.
		c.mu.Unlock()
		taken, err := agent.Steer(context.Background(), sid, blocks)
		c.mu.Lock()
		switch {
		case taken:
			continue
		case err == nil && !c.busy && c.agent == agent && !c.held && !c.stopping && !c.halting:
			c.startLocked(blocks) // the turn ended meanwhile: this starts the next
			return
		case err != nil:
			c.noticeLocked("error", "Couldn't hand your message to the agent; it's back in the queue: "+err.Error())
		}
		c.unsendLocked(id)
		c.queue = append([]model.Message{m}, c.queue...)
		c.queueChangedLocked()
		return
	}
}

// unsendLocked takes a message the agent never got out of the transcript,
// when nothing came after it.
func (c *chat) unsendLocked(id string) {
	if n := len(c.items); n > 0 && c.items[n-1].ID == id {
		c.items = c.items[:n-1]
		c.emitLocked(model.Event{ChatID: c.id, Cut: id})
	}
}

// Unqueue takes a message out of the chat's queue and returns it, before
// the agent gets it.
func (s *Service) Unqueue(chatID, id string) (model.Message, error) {
	c, err := s.stored(chatID)
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

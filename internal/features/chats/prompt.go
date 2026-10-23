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
// arrives as events.
func (s *Service) Prompt(chatID string, m model.Message, how Send) error {
	c, err := s.chat(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.waitSilentLocked()
	if err := folderGone(c.session); err != nil {
		return fmt.Errorf("the chat can't go on: %w", err)
	}
	if len(m.Images) > 0 && !c.canImage {
		return errors.New("the agent doesn't take images")
	}
	if how == SendNow && !c.started.IsZero() {
		done := c.done
		if err := c.cancelLocked(); err != nil {
			return err
		}
		c.mu.Unlock()
		<-done
		c.mu.Lock()
	}
	switch {
	case c.busy && how == SendQueue:
		m.ID = rand.Text()
		c.queue = append(c.queue, m)
		c.queueChangedLocked()
	case c.busy:
		return errors.New("the agent is still working on the last prompt")
	default:
		c.sendLocked(m)
	}
	return nil
}

// sendLocked shows the message in the transcript and starts a turn with it.
func (c *chat) sendLocked(m model.Message) {
	c.addLocked(model.Item{Kind: model.UserMessage, Text: m.Text, Images: m.Images})
	c.saveLocked(func(s *model.Session) {
		if s.Title == "" {
			s.Title = title(m.Text)
		}
	})
	c.startLocked(c.blocks(m))
}

func (c *chat) startLocked(prompt []acp.ContentBlock) {
	c.busy, c.started, c.done = true, time.Now(), make(chan struct{})
	c.statusChangedLocked()
	go c.run(c.agent, acp.PromptRequest{SessionID: acp.SessionID(c.sid), Prompt: prompt})
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

func (c *chat) run(agent Agent, req acp.PromptRequest) {
	resp, err := agent.Prompt(context.Background(), req)
	c.mu.Lock()
	defer c.mu.Unlock()
	c.busy, c.started = false, time.Time{}
	close(c.done)
	if err == nil && resp.Usage != nil {
		u := resp.Usage
		c.usage.Input, c.usage.Output, c.usage.CachedRead, c.usage.CachedWrite = u.InputTokens, u.OutputTokens, u.CachedReadTokens, u.CachedWriteTokens
		c.usageChangedLocked()
	}
	switch {
	case err != nil:
		c.noticeLocked("error", "The turn failed: "+err.Error())
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
	if err == nil && resp.StopReason != "cancelled" { // a stopped turn holds the queue
		c.deliverLocked()
	}
}

// deliverLocked hands the queue to the agent at its chance: while a turn
// runs, into the turn when the agent can be steered; when the chat is
// idle, the first message as the next prompt.
func (c *chat) deliverLocked() {
	if len(c.queue) == 0 || c.agent == nil {
		return
	}
	if !c.busy {
		m := c.queue[0]
		c.queue = c.queue[1:]
		c.queueChangedLocked()
		c.sendLocked(m)
		return
	}
	if !c.steer || c.started.IsZero() {
		return
	}
	queue := c.queue
	c.queue = nil
	c.queueChangedLocked()
	type steer struct {
		m      model.Message
		blocks []acp.ContentBlock
	}
	var steers []steer
	for _, m := range queue {
		c.addLocked(model.Item{Kind: model.UserMessage, Text: m.Text, Images: m.Images})
		steers = append(steers, steer{m, c.blocks(m)})
	}
	agent, sid := c.agent, acp.SessionID(c.sid)
	// The agent's updates may come before its answer: not under the lock.
	go func() {
		for i, s := range steers {
			taken, err := agent.Steer(context.Background(), sid, s.blocks)
			if taken {
				continue
			}
			c.mu.Lock()
			if err == nil && !c.busy { // the turn ended meanwhile: this starts the next
				c.startLocked(s.blocks)
				c.mu.Unlock()
				continue
			}
			if err != nil {
				c.noticeLocked("error", "Couldn't hand your message to the agent; it's back in the queue: "+err.Error())
			}
			var rest []model.Message
			for _, s := range steers[i:] {
				rest = append(rest, s.m)
			}
			c.queue = append(rest, c.queue...)
			c.queueChangedLocked()
			c.mu.Unlock()
			return
		}
	}()
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

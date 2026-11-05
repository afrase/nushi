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
// mentions or attaches (a device's uploads saved first) and its images. The turn runs in the background; its progress
// arrives as events. A chat whose agent isn't running is reopened, and the
// message waits in the queue until it is. SendNow waits for the stopped
// turn to end, or for ctx: an agent that ignores the cancel doesn't keep
// the call. A message that is one of the commands Nushi runs in the agent's
// place (TerminalCommands) is run here instead.
func (s *Service) Prompt(ctx context.Context, chatID string, m model.Message, how Send) error {
	if len(m.Uploads) > 0 {
		c, err := s.chat(chatID)
		if err != nil {
			return err
		}
		if err := s.saveUploads(c, &m); err != nil {
			return err
		}
	}
	if c, cmd, ok := s.terminalCommandOf(chatID, m); ok {
		return s.terminalCommand(ctx, c, m, cmd, how)
	}
	return s.prompt(ctx, chatID, m, how)
}

// prompt is Prompt's, for a message that goes to the agent as it is.
func (s *Service) prompt(ctx context.Context, chatID string, m model.Message, how Send) error {
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
	if err := c.toSubagentOfLocked(&m); err != nil {
		return err
	}
	switch {
	case c.reopeningLocked() && c.held:
		// A new message is the held queue's chance, and goes ahead of it,
		// as in a chat that's awake: Continue or Try again after a failed
		// turn first, then the queue.
		m.ID = rand.Text()
		c.queue = append([]model.Message{m}, c.queue...)
		c.queueChangedLocked()
		c.held = false
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
	if err := folderGone(c.record); err != nil {
		return fmt.Errorf("the chat can't go on: %w", err)
	}
	if c.sessionGone {
		return errors.New("the chat can't go on: " + c.kind.goneText())
	}
	return nil
}

// toSubagentOfLocked finds what a message to a subagent (or a stop of a
// task) goes to, from the tool call it names (Message.To).
func (c *chat) toSubagentOfLocked(m *model.Message) error {
	if m.To == "" {
		return nil
	}
	find := c.toSubagentLocked
	if m.ToSubagent != nil && m.ToSubagent.Stop {
		find = c.stopTaskLocked
	}
	r, err := find(m.To)
	m.ToSubagent = r
	return err
}

// closedLocked says why a chat takes no prompts: it is archived, being
// deleted, its agent is stopping, or its worktree is being removed; nil
// when it takes them.
func (c *chat) closedLocked() error {
	switch {
	case c.record.Archived:
		return errors.New("the chat is archived")
	case c.halting:
		return errors.New("the chat is being deleted")
	case c.stopping:
		return errors.New("the chat's agent is stopping")
	case c.removing:
		return errors.New("the chat's worktree is being removed")
	}
	return nil
}

// sendLocked shows the message in the transcript and starts a turn with it.
func (c *chat) sendLocked(m model.Message) {
	c.addLocked(userItem(m))
	c.saveLocked(func(s *model.ChatRecord) {
		s.HasMessages = true
		s.Updated = time.Now()
		if s.Title == "" {
			s.Title = title(m.Text)
		}
	})
	c.startLocked(c.blocks(m))
}

// startLocked starts a turn with prompt, after notes of where the chat
// works (moved, its folder's branch switched) and its worktree's branch
// renamed since the last one, if they were. The notes are made and the
// prompt is written to the agent in the background; a cancel waits for
// it (see cancelLocked).
func (c *chat) startLocked(prompt []acp.ContentBlock) {
	if c.agent == nil {
		c.noticeLocked("error", "The agent isn't running; send the message again to reopen the chat.")
		return
	}
	notes := c.notesLocked()
	sent, done := make(chan struct{}), make(chan struct{})
	c.busy, c.started, c.done, c.sent, c.held = true, time.Now(), done, sent, false
	c.released, c.steered, c.turnFrom, c.stopped = false, 0, len(c.items), false
	c.statusChangedLocked()
	c.logLocked().Info("turn started", "queued", len(c.queue))
	go c.run(c.agent, &acp.PromptRequest{SessionID: acp.SessionID(c.sid), Prompt: prompt}, notes, sent, done)
}

// releaseLocked ends the running turn for the chat while the agent still
// holds its prompt open for subagents the turn left running in the
// background (see Transcript.TurnDone): the chat is idle, a message goes as
// the next prompt (which the agent takes at once, answering the held one),
// and the subagents' steps and the agent's answer to their reports come as
// its own work. The held prompt's answer then changes nothing (run).
func (c *chat) releaseLocked() {
	c.logLocked().Info("turn's work ended", "took", time.Since(c.started).Round(time.Millisecond), "held_for", "background subagents")
	c.released, c.busy, c.started = true, false, time.Time{}
	close(c.done)
	c.notPassedOnLocked()
	c.copyLocked(true)
	c.lookRelatedLocked()
	end := model.TurnDone
	if c.turnStoppedLocked() {
		end = model.TurnStopped
	}
	c.turnEndedLocked(end, "")
	c.deliverLocked()
}

// backgroundLocked says a subagent the agent started (since item from)
// runs on in the background.
func (c *chat) backgroundLocked(from int) bool {
	return slices.ContainsFunc(c.items[min(from, len(c.items)):], func(it model.Item) bool { return it.Subagent != nil && it.Subagent.State == "running" })
}

// blocks makes a message the agent's content: the text, links to the files
// and the images. A link is named by the file's path in the folder, or by
// its absolute path when outside it: omp gives its model only the name, never
// the URI, so a bare name would send it to a same-named file in the folder.
func (c *chat) blocks(m model.Message) []acp.ContentBlock {
	text, files := m.Text, m.Files
	switch r := m.ToSubagent; {
	case r != nil && r.Stop:
		text = c.kind.background.StopTask(r.AgentID)
	case r != nil:
		// The files go in the message the agent forwards, by their paths,
		// not as links of the agent's own beside it: those it would be
		// told not to act on, and the subagent never told of.
		var b strings.Builder
		b.WriteString(text)
		sep := "\n\n"
		for _, f := range files {
			b.WriteString(sep + `@"` + c.filePath(f) + `"`)
			sep = " "
		}
		text, files = c.kind.toSubagents.ToSubagent(r.Agent, r.AgentID, b.String()), nil
	}
	prompt := []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: text}}}
	for _, f := range files {
		path, name := c.filePath(f), f
		if filepath.IsAbs(f) {
			name = path
		}
		prompt = append(prompt, acp.ContentBlock{Type: "resource_link", ResourceLink: &acp.ResourceLink{
			Name: name, URI: (&url.URL{Scheme: "file", Path: path}).String()}})
	}
	for _, img := range m.Images {
		prompt = append(prompt, acp.ContentBlock{Type: "image", Image: &acp.ImageContent{
			MimeType: img.MimeType, Data: base64.StdEncoding.EncodeToString(img.Data)}})
	}
	return prompt
}

// filePath is where a message's file is: its path in the chat's folder,
// or its own when outside it.
func (c *chat) filePath(f string) string {
	if filepath.IsAbs(f) {
		return filepath.Clean(f)
	}
	return filepath.Join(c.record.Folder, f)
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
func (c *chat) run(agent Agent, req *acp.PromptRequest, n *notes, sent, done chan struct{}) {
	blocks, t := n.blocks()
	req.Prompt = append(blocks, req.Prompt...)
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
	c.notPassedOnLocked()
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
	// Between turns, before the next one starts, and before how this one
	// ended: Try again sits on a failed turn's notice while it is last.
	c.nameBranchLocked()
	switch {
	case err != nil && !quit:
		c.noticeLocked("turn_failed", "The turn failed: "+err.Error())
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
	c.lookRelatedLocked()
	end, failure := c.verdictLocked(resp, err, quit)
	c.turnEndedLocked(end, failure)
	c.copyLocked(true)
	// A stopped or failed turn holds the queue until the next one ends: one
	// the user stopped even when the agent ended it as the stop came.
	c.held = end != model.TurnDone
	c.deliverLocked()
}

// tokens is a count the agent may not report, as 0 when it doesn't.
func tokens(n *uint64) int64 {
	if n == nil {
		return 0
	}
	return int64(*n) //nolint:gosec // token counts, far below the limits
}

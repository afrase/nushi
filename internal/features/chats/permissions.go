package chats

import (
	"context"
	"fmt"
	"log/slog"
	"slices"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// requestPermission shows the agent's permission prompt and waits for the
// user's answer. Nushi never answers one itself.
// isShow says a call is Nushi's show tool, by the title Claude's agents
// and Codex's adapter give it (docs/facts).
func isShow(title string) bool { return title == "mcp__nushi__show" || title == "mcp.nushi.show" }

func (c *chat) requestPermission(ctx context.Context, req *acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
	item := model.Item{Kind: model.Permission, Status: "pending", Title: req.ToolCall.Title}
	for _, o := range req.Options {
		item.Options = append(item.Options, model.Option{ID: string(o.OptionID), Name: o.Name, Kind: string(o.Kind)})
	}
	answer := make(chan string, 1)
	c.mu.Lock()
	c.setOutput(&item, req.ToolCall.Content) // under the lock: it reads the chat's folder
	call := c.itemLocked(string(req.ToolCall.ToolCallID))
	if call != nil {
		if item.Title == "" {
			item.Title = call.Title
		}
		if item.Text == "" && item.Diffs == nil {
			item.Text, item.Diffs = call.Text, call.Diffs
		}
	}
	if isShow(item.Title) { // the card says which file: what's being allowed (ADR 0068)
		item.Input = inputText(req.ToolCall.RawInput)
		if item.Input == "" && call != nil {
			item.Input = call.Input
		}
	}
	id := c.addLocked(item)
	c.waiting[id] = answer
	c.statusChangedLocked()
	c.mu.Unlock()

	var picked string
	select {
	case picked = <-answer:
	case <-ctx.Done():
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.waiting, id)
	c.statusChangedLocked()
	it := c.itemLocked(id) // nil once rewound or reloaded past
	if picked == "" {
		if it != nil {
			it.Status = "cancelled"
			c.publishLocked(*it)
		}
		return &acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{Cancelled: true}}, nil
	}
	if it != nil {
		it.Status, it.Answer = "answered", picked
		c.publishLocked(*it)
	}
	return &acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{
		Selected: &acp.SelectedPermissionOutcome{OptionID: acp.PermissionOptionID(picked)},
	}}, nil
}

// AnswerPermission sends the user's pick for a pending permission prompt.
func (s *Service) AnswerPermission(chatID, itemID, optionID string) error {
	c, err := s.chat(chatID)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	answer, it := c.waiting[itemID], c.itemLocked(itemID)
	if answer == nil || it == nil {
		return fmt.Errorf("no pending permission prompt %q", itemID)
	}
	if !slices.ContainsFunc(it.Options, func(o model.Option) bool { return o.ID == optionID }) {
		return fmt.Errorf("the prompt has no option %q", optionID)
	}
	delete(c.waiting, itemID)
	answer <- optionID
	return nil
}

// A prompt or question is answered only by the agent that asked it, while
// it waits: once that agent stops (sleep, a crash, the daemon's restart) it
// ends "cancelled", saved, and a resumed agent that wants an answer asks
// again, with a card of its own.

// asking says an item is a permission prompt or a question still pending.
func asking(it model.Item) bool {
	return (it.Kind == model.Permission || it.Kind == model.Question) && it.Status == "pending"
}

// liveLocked says the agent still waits on the prompt or question id.
func (c *chat) liveLocked(id string) bool {
	return c.waiting[id] != nil || c.questions[id] != nil
}

// dropPromptsLocked cancels the prompts and questions the agent waits on,
// as ACP asks of a client that stops a turn: each request answers
// "cancelled" and marks its item so once it has the lock.
func (c *chat) dropPromptsLocked() {
	if len(c.waiting)+len(c.questions) == 0 {
		return
	}
	for _, answer := range c.waiting {
		answer <- ""
	}
	for _, answer := range c.questions {
		close(answer)
	}
	clear(c.waiting)
	clear(c.questions)
	c.statusChangedLocked()
}

// endPromptsLocked marks the pending prompts and questions no agent waits
// on cancelled (left by an agent that stopped, or by a copy written before
// it did), and tells the app.
func (c *chat) endPromptsLocked() {
	for i, it := range c.items {
		if asking(it) && !c.liveLocked(it.ID) {
			c.items[i].Status = "cancelled"
			c.publishLocked(c.items[i])
		}
	}
}

// EndStalePrompts cancels, in the transcripts' copies, the prompts and
// questions a daemon that stopped left pending: no agent waits on them
// now. A chat already open is its own (restoreLocked). Run at start.
func (s *Service) EndStalePrompts() {
	if s.copies == nil {
		return
	}
	stored, err := s.sessions.Sessions()
	if err != nil {
		slog.Warn("ending stale prompts", "err", err)
		return
	}
	for _, sess := range stored {
		s.mu.Lock() // no chat opens while its copy is fixed (lookup)
		if s.chats[sess.ID] == nil && s.copies.Has(sess.ID) {
			s.endStale(sess.ID)
		}
		s.mu.Unlock()
	}
}

func (s *Service) endStale(id string) {
	items, err := s.copies.Read(id)
	if err != nil {
		slog.Warn("ending stale prompts", "chat", id, "err", err)
		return
	}
	var ended []model.Item
	var after []string
	prev := ""
	for _, it := range items {
		if asking(it) {
			it.Status = "cancelled"
			ended, after = append(ended, it), append(after, prev)
		}
		prev = it.ID
	}
	if len(ended) == 0 {
		return
	}
	if err := s.copies.Append(id, ended, after); err != nil {
		slog.Warn("ending stale prompts", "chat", id, "err", err)
		return
	}
	slog.Info("stale prompts cancelled", "chat", id, "items", len(ended))
}

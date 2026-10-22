package chats

import (
	"context"
	"fmt"
	"slices"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// requestPermission shows the agent's permission prompt and waits for the
// user's answer. Nushi never answers one itself.
func (c *chat) requestPermission(ctx context.Context, req acp.RequestPermissionRequest) (*acp.RequestPermissionResponse, error) {
	item := model.Item{Kind: model.Permission, Status: "pending", Title: req.ToolCall.Title}
	c.setOutput(&item, req.ToolCall.Content)
	for _, o := range req.Options {
		item.Options = append(item.Options, model.Option{ID: string(o.OptionID), Name: o.Name, Kind: string(o.Kind)})
	}
	answer := make(chan string, 1)
	c.mu.Lock()
	if call := c.itemLocked(string(req.ToolCall.ToolCallID)); call != nil {
		if item.Title == "" {
			item.Title = call.Title
		}
		if item.Text == "" && item.Diffs == nil {
			item.Text, item.Diffs = call.Text, call.Diffs
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
	it := c.itemLocked(id)
	if picked == "" {
		it.Status = "cancelled"
		c.publishLocked(*it)
		return &acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{Outcome: "cancelled", Cancelled: &struct{}{}}}, nil
	}
	it.Status, it.Answer = "answered", picked
	c.publishLocked(*it)
	return &acp.RequestPermissionResponse{Outcome: acp.RequestPermissionOutcome{
		Outcome: "selected", Selected: &acp.SelectedPermissionOutcome{OptionID: acp.PermissionOptionID(picked)},
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
	answer := c.waiting[itemID]
	if answer == nil {
		return fmt.Errorf("no pending permission prompt %q", itemID)
	}
	if !slices.ContainsFunc(c.itemLocked(itemID).Options, func(o model.Option) bool { return o.ID == optionID }) {
		return fmt.Errorf("the prompt has no option %q", optionID)
	}
	delete(c.waiting, itemID)
	answer <- optionID
	return nil
}

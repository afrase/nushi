package chats

import (
	"context"
	"errors"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// stuckWorktrees has a worktree with no work in it that won't go.
type stuckWorktrees struct{}

func (stuckWorktrees) Add(context.Context, string, string) (model.Worktree, string, error) {
	return model.Worktree{}, "", errors.New("no")
}
func (stuckWorktrees) Inspect(context.Context, model.Worktree) (model.WorktreeState, error) {
	return model.WorktreeState{}, nil
}
func (stuckWorktrees) Remove(context.Context, model.Worktree, bool) error {
	return errors.New("locked")
}
func (stuckWorktrees) DeleteBranch(context.Context, model.Worktree) error { return nil }

func TestAChatStaysIfItsWorktreeOrHistoryCantGo(t *testing.T) {
	ctx := context.Background()
	stays := func(what string, err error, c *chat) {
		t.Helper()
		c.mu.Lock()
		defer c.mu.Unlock()
		if err == nil || c.halting {
			t.Errorf("%s: Delete = %v, halting %v", what, err, c.halting)
		}
	}

	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	svc.worktrees = stuckWorktrees{}
	c.mu.Lock()
	c.session.Worktree = &model.Worktree{Path: "/w"}
	c.mu.Unlock()
	err := svc.Delete(ctx, c.id, DeleteOptions{"/w": {RemoveWorktree: true}})
	stays("the worktree", err, c)
	if len(agent.deleted) != 0 {
		t.Errorf("history deleted though the worktree stayed: %v", agent.deleted)
	}

	svc, agent, c = newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.deletes, agent.deleteErr = true, errors.New("busy")
	stays("the history", svc.Delete(ctx, c.id, nil), c)
	if _, err := svc.stored(c.id); err != nil {
		t.Errorf("the chat went: %v", err)
	}
}

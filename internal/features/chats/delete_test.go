package chats

import (
	"context"
	"errors"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// stuckWorktrees has a worktree with no work in it that won't go.
type stuckWorktrees struct{}

func (stuckWorktrees) Add(context.Context, string, string, string, string) (model.Worktree, string, error) {
	return model.Worktree{}, "", errors.New("no")
}
func (stuckWorktrees) Inspect(context.Context, model.Worktree) (model.WorktreeState, error) {
	return model.WorktreeState{}, nil
}
func (stuckWorktrees) Remove(context.Context, model.Worktree, bool) error {
	return errors.New("locked")
}
func (stuckWorktrees) DeleteBranch(context.Context, model.Worktree) error { return nil }
func (stuckWorktrees) BranchUse(context.Context, model.Worktree) (model.BranchUse, error) {
	return model.BranchUse{OnIt: true}, nil
}
func (stuckWorktrees) RenameBranch(context.Context, model.Worktree, string) error  { return nil }
func (stuckWorktrees) CheckBranch(context.Context, string, string) error           { return nil }
func (stuckWorktrees) List(context.Context, string) ([]model.WorktreeEntry, error) { return nil, nil }
func (stuckWorktrees) Found(context.Context, string) *model.Worktree               { return nil }
func (stuckWorktrees) Branch(context.Context, string) string                       { return "" }
func (stuckWorktrees) Changed(context.Context, string) (int, error)                { return 0, nil }
func (stuckWorktrees) Changes(context.Context, string, int) ([]string, error)      { return nil, nil }
func (stuckWorktrees) Switch(context.Context, string, string, bool) error          { return nil }

// removingWorktrees removes every worktree it's asked to, and says which.
type removingWorktrees struct {
	stuckWorktrees
	removed []string
}

func (w *removingWorktrees) Remove(_ context.Context, wt model.Worktree, _ bool) error {
	w.removed = append(w.removed, wt.Path)
	return nil
}

// A deleted chat's worktree that another chat works in stays, as with
// RemoveWorktree: removing it would take that chat's folder.
func TestDeleteLeavesAWorktreeAnotherChatWorksIn(t *testing.T) {
	ctx := context.Background()
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &removingWorktrees{}
	svc.worktrees = wts
	w := t.TempDir()
	c.mu.Lock()
	c.session.EarlierWorktrees = []model.Worktree{{Path: w}} // it moved out; the other chat started there
	c.mu.Unlock()
	svc.sessions.(*memSessions).stored = []model.Session{{ID: "other", Title: "Fix the build", Folder: filepath.Join(w, "app")}}
	err := svc.Delete(ctx, c.id, DeleteOptions{w: {RemoveWorktree: true}})
	if err == nil || !strings.Contains(err.Error(), "Fix the build") {
		t.Errorf("Delete = %v", err)
	}
	c.mu.Lock()
	halting := c.halting
	c.mu.Unlock()
	if len(wts.removed) > 0 || halting {
		t.Errorf("removed %q, halting %v", wts.removed, halting)
	}
}

// A move into a worktree the chat ran in before that fails leaves the
// worktree: another chat may have started there since.
func TestAFailedMoveKeepsAnEarlierWorktree(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &removingWorktrees{}
	svc.worktrees = wts
	turn(t, svc, c, "one") // with messages, the move forks: this kind can't
	w := t.TempDir()
	c.mu.Lock()
	c.session.EarlierWorktrees = []model.Worktree{{Path: w}}
	c.mu.Unlock()
	if err := svc.Move(context.Background(), c.id, w, false); err == nil {
		t.Fatal("moved")
	}
	if len(wts.removed) > 0 {
		t.Errorf("a failed move removed %q", wts.removed)
	}
}

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

// While a chat is being deleted, nothing reopens it or sends to it.
func TestNothingReopensAChatBeingDeleted(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	agent.deletes, agent.deleteGate = true, make(chan struct{})
	deleted := make(chan error)
	go func() { deleted <- svc.Delete(context.Background(), c.id, nil) }()
	eventually(t, c, func() bool { return c.halting && c.agent == nil })
	time.Sleep(20 * time.Millisecond) // the deleter is waiting on its delete
	agent.mu.Lock()
	launches := agent.launches
	agent.mu.Unlock()
	if _, err := svc.Get(c.id); err != nil {
		t.Fatal(err)
	}
	if err := svc.Prompt(t.Context(), c.id, model.Message{Text: "hi"}, SendQueue); err == nil {
		t.Error("a chat being deleted took a message")
	}
	if _, err := svc.Fork(context.Background(), c.id); err == nil {
		t.Error("a chat being deleted forked")
	}
	time.Sleep(20 * time.Millisecond)
	agent.mu.Lock()
	again := agent.launches
	agent.mu.Unlock()
	close(agent.deleteGate)
	if err := <-deleted; err != nil {
		t.Fatal(err)
	}
	if again != launches {
		t.Errorf("%d agents started while the chat was being deleted", again-launches)
	}
}

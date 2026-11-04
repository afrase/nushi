package chats

import (
	"context"
	"errors"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
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
func (stuckWorktrees) Locate(context.Context, string) (string, string, error) {
	return "", "", nil
}
func (stuckWorktrees) MergeBase(context.Context, string, string, string) (string, error) {
	return "", nil
}
func (stuckWorktrees) Merged(context.Context, string, string, []string) ([]string, error) {
	return nil, nil
}
func (stuckWorktrees) Branch(context.Context, string) string                  { return "" }
func (stuckWorktrees) Changed(context.Context, string) (int, error)           { return 0, nil }
func (stuckWorktrees) Changes(context.Context, string, int) ([]string, error) { return nil, nil }
func (stuckWorktrees) Switch(context.Context, string, string, bool) error     { return nil }

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
// RemoveWorktree: removing it would take that chat's folder. The plan
// names that chat, for the dialog to say why.
func TestDeleteLeavesAWorktreeAnotherChatWorksIn(t *testing.T) {
	ctx := context.Background()
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &removingWorktrees{}
	svc.worktrees = wts
	w := t.TempDir()
	c.mu.Lock()
	c.record.EarlierWorktrees = []model.Worktree{{Path: w}} // it moved out; the other chat started there
	c.mu.Unlock()
	svc.sessions.(*memSessions).stored = []model.ChatRecord{{ID: "other", Title: "Fix the build", Folder: filepath.Join(w, "app")}}
	p, err := svc.PlanDelete(ctx, c.id)
	testcheck.NoErr(t, err)
	if len(p.Worktrees) != 1 || !slices.Equal(p.Worktrees[0].Others, []string{"Fix the build"}) {
		t.Errorf("plan: %+v", p.Worktrees)
	}
	err = svc.Delete(ctx, c.id, DeleteOptions{w: {RemoveWorktree: true}})
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
	c.record.EarlierWorktrees = []model.Worktree{{Path: w}}
	c.mu.Unlock()
	if err := svc.Move(context.Background(), c.id, w, false); err == nil {
		t.Fatal("moved")
	}
	if len(wts.removed) > 0 {
		t.Errorf("a failed move removed %q", wts.removed)
	}
	lastNoticeIs(t, c, "error", "Couldn't move the chat")
}

// A chat without messages that moves out of its worktree leaves it when
// the chats can't be read: another chat may work in it.
func TestAMoveKeepsTheWorktreeWhenTheChatsCantBeRead(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &removingWorktrees{}
	svc.worktrees = wts
	w := t.TempDir()
	c.mu.Lock()
	c.record.Worktree = &model.Worktree{Path: w}
	c.mu.Unlock()
	svc.sessions.(*memSessions).readErr = errors.New("disk gone")
	testcheck.NoErr(t, svc.Move(context.Background(), c.id, t.TempDir(), false))
	c.mu.Lock()
	earlier := slices.Clone(c.record.EarlierWorktrees)
	c.mu.Unlock()
	if len(wts.removed) > 0 || len(earlier) != 1 || earlier[0].Path != w {
		t.Errorf("removed %q, earlier %v", wts.removed, earlier)
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
	c.record.Worktree = &model.Worktree{Path: "/w"}
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

// inspectingWorktrees is a worktree whose Inspect waits for the test.
type inspectingWorktrees struct {
	removingWorktrees
	inspecting, goOn chan struct{}
}

func (w *inspectingWorktrees) Inspect(context.Context, model.Worktree) (model.WorktreeState, error) {
	w.inspecting <- struct{}{}
	<-w.goOn
	return model.WorktreeState{}, nil
}

// While RemoveWorktree looks at the worktree (git, which takes time) the
// chat takes no prompt and doesn't reopen: a message then would start a
// turn that the removal cuts, in a folder about to go.
func TestRemoveWorktreeHoldsTheChat(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &inspectingWorktrees{inspecting: make(chan struct{}), goOn: make(chan struct{})}
	svc.worktrees = wts
	c.mu.Lock()
	c.record.Worktree = &model.Worktree{Path: c.record.Folder}
	c.mu.Unlock()
	removed := make(chan error, 1)
	go func() { removed <- svc.RemoveWorktree(context.Background(), c.id, false) }()
	<-wts.inspecting
	err := svc.Prompt(t.Context(), c.id, model.Message{Text: "hi"}, SendIdle)
	if err == nil || !strings.Contains(err.Error(), "worktree is being removed") {
		t.Errorf("a prompt during the removal: %v", err)
	}
	close(wts.goOn)
	testcheck.NoErr(t, <-removed)
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(agent.prompts) > 0 || !slices.Equal(wts.removed, []string{c.record.Folder}) || !c.asleep || c.removing {
		t.Errorf("prompts %q, removed %q, asleep %v, removing %v", agent.prompts, wts.removed, c.asleep, c.removing)
	}
}

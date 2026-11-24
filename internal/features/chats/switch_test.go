package chats

import (
	"context"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// switchingWorktrees is one checkout, folder, on main, whose switch waits
// at gate, saying so on entered.
type switchingWorktrees struct {
	stuckWorktrees
	folder  string
	gate    chan struct{}
	entered chan struct{}
}

func (w switchingWorktrees) List(context.Context, string) ([]model.WorktreeEntry, error) {
	return []model.WorktreeEntry{{Path: w.folder, Branch: "main", Main: true, Current: true}}, nil
}
func (switchingWorktrees) Branch(context.Context, string) string { return "main" }
func (w switchingWorktrees) Switch(context.Context, string, string, bool) error {
	w.entered <- struct{}{}
	<-w.gate
	return nil
}

// While a chat's folder switches branch, neither it nor another chat in
// the same checkout starts a turn there: a message is refused, as while a
// worktree is removed, and is taken again once the switch is done.
func TestNoTurnStartsMidSwitch(t *testing.T) {
	agent := &fakeAgent{}
	sessions := &memSessions{}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Sessions: sessions})
	t.Cleanup(svc.Close)
	folder := t.TempDir()
	c, other := startChat(t, svc, folder), startChat(t, svc, folder)
	sessions.mu.Lock()
	sessions.stored = []model.ChatRecord{c.record, other.record}
	sessions.mu.Unlock()
	w := switchingWorktrees{folder: folder, gate: make(chan struct{}), entered: make(chan struct{})}
	svc.worktrees = w
	switched := make(chan error, 1)
	go func() {
		_, err := svc.SwitchBranch(context.Background(), c.id, "b", false, true)
		switched <- err
	}()
	<-w.entered // git switch runs
	for _, ch := range []*chat{c, other} {
		if err := svc.Prompt(t.Context(), ch.id, model.Message{Text: "now"}, SendIdle); err == nil {
			t.Error("a turn started mid-switch")
		}
	}
	close(w.gate)
	testcheck.NoErr(t, <-switched)
	if got, _ := agent.texts(); len(got) != 0 {
		t.Errorf("prompts %q", got)
	}
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "after"}, SendIdle))
	idle(t, c)
}

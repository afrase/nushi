package chats

import (
	"context"
	"slices"
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

// A side chat works in its chat's folder, on its agent: mid-switch it
// starts no turn either, whether it was open before the switch or opened
// during it, and it takes messages again once the switch is done.
func TestNoSideChatTurnStartsMidSwitch(t *testing.T) {
	agent := &fakeAgent{}
	sessions := &memSessions{}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude"}, Launch: agent.launch}}, Options{Sessions: sessions})
	t.Cleanup(svc.Close)
	folder := t.TempDir()
	c, other := startChat(t, svc, folder), startChat(t, svc, folder)
	sessions.mu.Lock()
	sessions.stored = []model.ChatRecord{c.record, other.record}
	sessions.mu.Unlock()
	turn(t, svc, c, "one")
	turn(t, svc, other, "one")
	var sides []string
	for _, ch := range []*chat{c, other} {
		side, err := svc.Fork(t.Context(), ch.id)
		testcheck.NoErr(t, err)
		sides = append(sides, side)
	}
	w := switchingWorktrees{folder: folder, gate: make(chan struct{}), entered: make(chan struct{})}
	svc.worktrees = w
	switched := make(chan error, 1)
	go func() {
		_, err := svc.SwitchBranch(context.Background(), c.id, "b", false, true)
		switched <- err
	}()
	<-w.entered                                    // git switch runs
	opened, err := svc.Fork(t.Context(), other.id) // a side chat opened mid-switch
	testcheck.NoErr(t, err)
	sides = append(sides, opened)
	for _, side := range sides {
		if err := svc.Prompt(t.Context(), side, model.Message{Text: "now"}, SendIdle); err == nil {
			t.Error("a side chat's turn started mid-switch")
		}
	}
	close(w.gate)
	testcheck.NoErr(t, <-switched)
	if got, _ := agent.texts(); slices.Contains(got, "now") {
		t.Errorf("prompts %q", got)
	}
	for _, side := range sides {
		testcheck.NoErr(t, svc.Prompt(t.Context(), side, model.Message{Text: "after"}, SendIdle))
		s, _ := svc.lookup(side)
		idle(t, s)
	}
}

// A side chat at work keeps its chat's folder from switching branch, as
// the chat's own turn does: git would change the folder under its agent.
func TestNoSwitchWhileASideChatWorks(t *testing.T) {
	svc, agent, c := newChat(t, claudeSession, &memModes{})
	turn(t, svc, c, "one")
	side, err := svc.Fork(t.Context(), c.id)
	testcheck.NoErr(t, err)
	agent.mu.Lock()
	agent.gate = make(chan struct{})
	agent.mu.Unlock()
	testcheck.NoErr(t, svc.Prompt(t.Context(), side, model.Message{Text: "aside"}, SendIdle))
	open := make(chan struct{})
	close(open) // a switch that got this far isn't held up
	svc.worktrees = switchingWorktrees{folder: c.record.Folder, gate: open, entered: make(chan struct{}, 1)}
	if _, err := svc.SwitchBranch(t.Context(), c.id, "b", false, true); err == nil {
		t.Error("switched while a side chat worked")
	}
	agent.release()
	s, _ := svc.lookup(side)
	idle(t, s)
	agent.mu.Lock()
	agent.gate = nil // the next turn ends at once
	agent.mu.Unlock()
	testcheck.NoErr(t, svc.Prompt(t.Context(), side, model.Message{Text: "again"}, SendIdle)) // the refused switch held nothing
	idle(t, s)
}

package chats

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// A replayed user's message loses the note that went before it: a block
// of its own, or run into the user's text; nothing else.
func TestUnnoted(t *testing.T) {
	note := branchNote("nushi/brave-otter", "nushi/bump-go-1-27-3")
	if note != "[Nushi] This worktree's branch was renamed from nushi/brave-otter to nushi/bump-go-1-27-3. Use the new name." {
		t.Errorf("the note: %q", note)
	}
	for in, want := range map[string]string{
		note:                       "",
		note + "go on":             "go on",
		note + "\n\ngo on\n":       "go on\n",
		"go on " + note:            "go on " + note,
		"[Nushi] This worktree's":  "[Nushi] This worktree's",
		"plain\n" + note + "\nend": "plain\n" + note + "\nend",
	} {
		got, ok := unnoted(in)
		if got != want || ok != (got != in) {
			t.Errorf("unnoted(%q) = %q, %v; want %q", in, got, ok, want)
		}
	}
}

// heldWorktrees holds each CheckBranch until held is closed.
type heldWorktrees struct {
	stuckWorktrees
	checking chan struct{}
	held     chan struct{}
}

func (w *heldWorktrees) CheckBranch(context.Context, string, string) error {
	select {
	case w.checking <- struct{}{}:
	default:
	}
	<-w.held
	return nil
}

// The note of a branch renamed is checked with git without the chat's
// lock: the chat answers meanwhile; the prompt then goes with the note,
// and the rename's line says it was told.
func TestBranchNoteChecksOutsideTheLock(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &heldWorktrees{checking: make(chan struct{}, 1), held: make(chan struct{})}
	c.mu.Lock()
	c.worktrees = wts
	c.record.Worktree = &model.Worktree{Repo: "/r", Path: "/r", Branch: "nushi/new", Told: "nushi/old"}
	line := c.addLocked(model.Item{Kind: model.Notice, Status: "branch_renamed", Text: "Branch renamed to nushi/new"})
	c.mu.Unlock()
	sent := make(chan error, 1)
	go func() { sent <- svc.Prompt(t.Context(), c.id, model.Message{Text: "go on"}, SendIdle) }()
	<-wts.checking
	locked := make(chan struct{})
	go func() {
		c.mu.Lock()
		defer c.mu.Unlock()
		close(locked)
	}()
	select {
	case <-locked:
	case <-time.After(5 * time.Second):
		t.Error("the chat stayed locked while git checked the names")
	}
	close(wts.held)
	testcheck.NoErr(t, <-sent)
	eventually(t, c, func() bool { return !c.busy })
	agent.mu.Lock()
	prompt := agent.prompt
	agent.mu.Unlock()
	if len(prompt) != 2 || prompt[0].Text.Text != branchNote("nushi/old", "nushi/new") || prompt[1].Text.Text != "go on" {
		t.Errorf("prompt %+v", prompt)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if it := c.itemLocked(line); it == nil || !strings.HasSuffix(it.Text, toldSuffix) || c.record.Worktree.Told != "nushi/new" {
		t.Errorf("line %+v, told %q", it, c.record.Worktree.Told)
	}
}

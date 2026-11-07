package chats

import (
	"context"
	"path/filepath"
	"slices"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// fakeServers runs a dev server in each of its folders, and says which
// folders it was asked to stop.
type fakeServers struct {
	mu      sync.Mutex
	in      []string
	stopped []string
}

func (f *fakeServers) Within(dir string) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.ContainsFunc(f.in, func(folder string) bool { return within(folder, dir) })
}

func (f *fakeServers) StopWithin(dir string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.stopped = append(f.stopped, dir)
	f.in = slices.DeleteFunc(f.in, func(folder string) bool { return within(folder, dir) })
}

// A chat without messages that moves out of its worktree leaves it while
// a dev server runs there (ADR 0098), as it does a terminal's.
func TestAMoveKeepsAWorktreeWithAServer(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &removingWorktrees{}
	svc.worktrees = wts
	w := t.TempDir()
	svc.UseServers(&fakeServers{in: []string{filepath.Join(w, "web")}})
	c.mu.Lock()
	c.record.Worktree = &model.Worktree{Path: w}
	c.mu.Unlock()
	testcheck.NoErr(t, svc.Move(context.Background(), c.id, t.TempDir(), false))
	c.mu.Lock()
	earlier := slices.Clone(c.record.EarlierWorktrees)
	c.mu.Unlock()
	if len(wts.removed) > 0 || len(earlier) != 1 || earlier[0].Path != w {
		t.Errorf("removed %q, earlier %v", wts.removed, earlier)
	}
}

// Deleting a chat with its worktree stops the worktree's servers before
// it goes.
func TestDeleteStopsTheWorktreesServers(t *testing.T) {
	svc, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &removingWorktrees{}
	svc.worktrees = wts
	w := t.TempDir()
	servers := &fakeServers{in: []string{w}}
	svc.UseServers(servers)
	c.mu.Lock()
	c.record.EarlierWorktrees = []model.Worktree{{Path: w}}
	c.mu.Unlock()
	testcheck.NoErr(t, svc.Delete(context.Background(), c.id, DeleteOptions{w: {RemoveWorktree: true}}))
	if !slices.Equal(servers.stopped, []string{w}) || !slices.Equal(wts.removed, []string{w}) {
		t.Errorf("stopped %q, removed %q", servers.stopped, wts.removed)
	}
}

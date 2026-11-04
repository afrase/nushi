package chats

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// addingWorktrees makes each worktree it's asked for as a folder in dir,
// and removes each it's asked to.
type addingWorktrees struct {
	removingWorktrees
	dir string
}

func (w *addingWorktrees) Add(_ context.Context, _, name, branch, from string) (model.Worktree, string, error) {
	path := filepath.Join(w.dir, name)
	if err := os.Mkdir(path, 0o700); err != nil {
		return model.Worktree{}, "", err
	}
	return model.Worktree{Repo: w.dir, Path: path, Branch: branch, Base: from}, path, nil
}

// A new worktree is looked at before its agent starts there (a pull
// request's head, ADR 0023): refused, the agent never starts and the
// worktree goes; let through, the chat starts in it.
func TestAWorktreeCheckedBeforeTheAgentStarts(t *testing.T) {
	launches := 0
	agent := &fakeAgent{}
	wts := &addingWorktrees{dir: t.TempDir()}
	svc := newService(t, []Kind{{Harness: testHarness{Name: "fake"}, Launch: func(h acp.Client, _ *slog.Logger) (Agent, error) {
		launches++
		agent.h = h
		return agent, nil
	}}}, Options{Worktrees: wts})
	folder := t.TempDir()
	untrusted := errors.New("untrusted")
	var looked []string
	opts := StartOptions{Worktree: true, Branch: "pr-9-fix", From: "refs/nushi/pull/9", Check: func(f string) error {
		looked = append(looked, f)
		return untrusted
	}}
	if _, err := svc.StartOn(t.Context(), "", folder, opts); !errors.Is(err, untrusted) {
		t.Fatalf("StartOn = %v; want the check's error", err)
	}
	if launches != 0 || len(looked) != 1 || !slices.Equal(wts.removed, looked) {
		t.Fatalf("%d agents started; looked at %v, removed %v", launches, looked, wts.removed)
	}
	opts.Check = func(string) error { return nil }
	id, err := svc.StartOn(t.Context(), "", folder, opts)
	testcheck.NoErr(t, err)
	if r := svc.chats[id].record; launches != 1 || r.Worktree == nil || r.Folder != r.Worktree.Path {
		t.Errorf("%d agents started; the chat %+v", launches, r)
	}
}

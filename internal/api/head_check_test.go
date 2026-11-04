package api

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"path/filepath"
	"testing"

	"connectrpc.com/connect"
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/github"
	"github.com/afrase/nushi/internal/features/trust"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
)

// headWorktrees makes each worktree a folder whose .claude/settings.json
// has a hook, as a pull request's head can bring, and removes it.
type headWorktrees struct {
	chats.Worktrees // nothing else is called
	t               *testing.T
	dir             string
	removed         []string
}

func (w *headWorktrees) Add(_ context.Context, _, name, branch, from string) (model.Worktree, string, error) {
	path := filepath.Join(w.dir, name)
	if err := os.MkdirAll(filepath.Join(path, ".claude"), 0o700); err != nil {
		return model.Worktree{}, "", err
	}
	if err := os.WriteFile(filepath.Join(path, ".claude", "settings.json"), []byte(`{"hooks":{}}`), 0o600); err != nil {
		return model.Worktree{}, "", err
	}
	// The head is a commit: what the card's Start anyway is pinned to.
	testcheck.Git(w.t, path, "init", "-q", "-b", branch)
	testcheck.Git(w.t, path, "add", ".")
	testcheck.Git(w.t, path, "commit", "-q", "-m", "head")
	return model.Worktree{Repo: w.dir, Path: path, Branch: branch, Base: from}, path, nil
}

func (*headWorktrees) Inspect(context.Context, model.Worktree) (model.WorktreeState, error) {
	return model.WorktreeState{}, nil // the head's own files: no work
}

func (*headWorktrees) DeleteBranch(context.Context, model.Worktree) error { return nil }

func (w *headWorktrees) Remove(_ context.Context, wt model.Worktree, _ bool) error {
	w.removed = append(w.removed, wt.Path)
	return os.RemoveAll(wt.Path)
}

// hookAgent says a folder with .claude/settings.json runs its hook.
type hookAgent struct{}

func (hookAgent) Runs(folder string) ([]model.FolderRun, string, error) {
	file := filepath.Join(folder, ".claude", "settings.json")
	if _, err := os.Stat(file); err != nil {
		return nil, "", nil //nolint:nilerr // nothing to run
	}
	return []model.FolderRun{{File: file, What: "A hook", Command: filepath.Join(folder, "hook.sh")}}, "key", nil
}
func (hookAgent) Key(string) string                      { return "key" }
func (hookAgent) Trusted(string, []string) (bool, error) { return false, nil }

// forkPull is GitHub with one pull request, from a fork.
type forkPull struct{ github.Client }

func (forkPull) Pull(context.Context, string, int) (model.GitHubPull, error) {
	return model.GitHubPull{ID: "PR_9", Head: "fix", CrossRepo: true}, nil
}

// Security fix review 2026-11-04: nothing tested that StartChat checks a
// pull request's head (ADR 0023), so dropping that wiring kept CI green.
// A fork's head with a hook gets the card's answer and starts no agent;
// started again with the card's key, the agent starts.
func TestStartChatChecksAPullRequestsHead(t *testing.T) {
	launches := 0
	launch := func(acp.Client, *slog.Logger) (chats.Agent, error) {
		launches++
		return nil, errors.New("it quit")
	}
	st := store.New(t.TempDir())
	wts := &headWorktrees{t: t, dir: t.TempDir()}
	svc := chats.New(t.Context(), []chats.Kind{{Harness: model.HarnessInfo{Name: "a", Title: "A"}, Launch: launch}},
		chats.Options{Remembered: st, Sessions: st, Scratch: t.TempDir(), Worktrees: wts})
	gh := github.New(github.Deps{
		Gh:      github.Gh{Token: func(context.Context, string) (string, string, error) { return "tok", "gh", nil }, Hosts: func() []string { return nil }, Reload: func() {}},
		Tokens:  memTokens{},
		Store:   &memHosts{Store: store.New(t.TempDir())},
		Open:    func(string, string) github.Client { return forkPull{} },
		NeedsOK: func(error) bool { return false }, Restart: func(error) bool { return false }, Missing: func(error) bool { return false },
		Remotes: func(context.Context, string) (map[string]string, error) {
			return map[string]string{"origin": "git@github.com:o/app.git"}, nil
		},
		Fetch:       func(context.Context, string, string, string) error { return nil },
		CheckBranch: func(string) error { return nil },
	})
	c := client(t, New(Services{Chats: svc, GitHub: gh, Trust: trust.New(map[string]trust.Agent{"a": hookAgent{}}, st)}))
	req := &nushiv1.StartChatRequest{Folder: t.TempDir(), Worktree: true,
		Github: &nushiv1.GitHubLink{Host: "github.com", Repo: "o/app", Number: 9, Pull: true, Id: "PR_9"}}
	r, err := c.StartChat(t.Context(), connect.NewRequest(req))
	if err != nil {
		t.Fatal(err)
	}
	if r.Msg.ChatId != "" || len(r.Msg.HeadRuns) != 1 || r.Msg.HeadRuns[0].What != "A hook" || r.Msg.HeadRunsKey == "" || r.Msg.HeadFolder == "" {
		t.Fatalf("StartChat = %v; want the head's card", r.Msg)
	}
	if launches != 0 || len(wts.removed) != 1 {
		t.Fatalf("%d agents started, worktrees removed %v", launches, wts.removed)
	}
	req.HeadRunsKey = r.Msg.HeadRunsKey // Start anyway
	_, err = c.StartChat(t.Context(), connect.NewRequest(req))
	if connect.CodeOf(err) != connect.CodeFailedPrecondition || launches != 1 {
		t.Fatalf("started anyway: %v, %d agents started", err, launches)
	}
}

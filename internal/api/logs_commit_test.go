package api

import (
	"bytes"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/logs"
	"github.com/afrase/nushi/internal/testcheck"
)

// A failing commit-msg hook that echoes the message (as commitlint does)
// reaches the app, never the daemon's log (security review 2026-11-04,
// finding 3).
func TestAFailedCommitsOutputStaysOutOfTheLog(t *testing.T) {
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	testcheck.Git(t, repo, "init", "-q")
	testcheck.Git(t, repo, "config", "user.email", "a@b.c")
	testcheck.Git(t, repo, "config", "user.name", "a")
	hook := filepath.Join(repo, ".git", "hooks", "commit-msg")
	testcheck.NoErr(t, os.WriteFile(hook, []byte("#!/bin/sh\necho \"input: $(cat \"$1\")\"\necho 'subject may not be empty'\nexit 1\n"), 0o700)) //nolint:gosec // a hook runs
	testcheck.Write(t, filepath.Join(repo, "f"), "x")
	testcheck.Git(t, repo, "add", "f")
	ctx := t.Context()
	idx, err := git.IndexState(ctx, repo)
	testcheck.NoErr(t, err)
	env := append(os.Environ(), "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1")
	_, err = git.CommitStaged(ctx, repo, "fix login for acme-secret-customer", idx, env)
	if err == nil || !strings.Contains(err.Error(), "acme-secret-customer") {
		t.Fatalf("the app doesn't get what the hook said: %v", err)
	}
	var buf bytes.Buffer
	old := slog.Default()
	slog.SetDefault(slog.New(logs.Handler(&buf)))
	defer slog.SetDefault(old)
	logCalls{"socket"}.ended("/nushi.v1.NushiService/CommitStaged", 0, connect.NewError(connect.CodeFailedPrecondition, err))
	if strings.Contains(buf.String(), "acme-secret-customer") || !strings.Contains(buf.String(), "git commit failed") {
		t.Fatalf("logged %s", buf.String())
	}
}

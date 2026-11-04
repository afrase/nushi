package e2e

import (
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"sync"
	"testing"

	"github.com/afrase/nushi/internal/features/terminals"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/terminal"
	"github.com/afrase/nushi/internal/testcheck"
)

// until waits for ok, 5 s at most.
func until(t *testing.T, what string, ok func() bool) {
	t.Helper()
	if !testcheck.Eventually(ok) {
		t.Fatalf("timed out waiting for %s", what)
	}
}

// settled waits for chat id's turn to end, and returns the chat.
func (a *app) settled(id string) *nushiv1.GetChatResponse {
	a.t.Helper()
	until(a.t, "the turn's end", func() bool { return !a.get(id).Status.Busy })
	return a.get(id)
}

// gitRepo makes a repository with one commit on main.
func gitRepo(t *testing.T) string {
	t.Helper()
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "init")
	return repo
}
func branchExists(repo, branch string) bool {
	return exec.Command("git", "-C", repo, "rev-parse", "--verify", "-q", "refs/heads/"+branch).Run() == nil
}

// A terminal's shell inherits the daemon's ignored signals, and a test
// binary started in the background by a script has SIGINT ignored, so a
// terminal's ^C wouldn't reach its command. nushid handles SIGINT (serve's
// signal.Notify), which un-ignores it for what it starts; the test binary
// stands in for nushid, and was ignoring SIGINT itself anyway.
var handleInterrupt = sync.OnceFunc(func() {
	if signal.Ignored(os.Interrupt) {
		signal.Notify(make(chan os.Signal, 1), os.Interrupt)
	}
})

func startSh(folder string, cols, rows int, changed func()) (terminals.Shell, error) {
	handleInterrupt()
	return terminal.Start([]string{"/bin/sh"}, folder, []string{"PS1=$ ", "TERM=xterm-256color"}, cols, rows, changed)
}
func questionPending(e *nushiv1.EventsResponse) bool {
	it := e.GetItem().GetItem()
	return it.GetKind() == nushiv1.ItemKind_ITEM_KIND_QUESTION && it.GetStatus() == "pending"
}

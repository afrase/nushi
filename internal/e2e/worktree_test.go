package e2e

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/acp/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// gitRepo makes a repository with one commit on main.
func gitRepo(t *testing.T) string {
	t.Helper()
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	for _, args := range [][]string{{"init", "-q", "-b", "main"}, {"commit", "-q", "--allow-empty", "-m", "init"}} {
		cmd := exec.Command("git", append([]string{"-C", repo, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"}, args...)...)
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v\n%s", args, err, out)
		}
	}
	return repo
}

func TestChatsInWorktrees(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	chat := func(id string) *nushiv1.Chat {
		return must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Chat
	}

	// Two chats in new worktrees of one repository: each has its own folder
	// and branch, from main.
	var wts []*nushiv1.Worktree
	for range 2 {
		id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: repo, Worktree: true}))).ChatId
		c := chat(id)
		wt := c.Worktree
		if wt == nil || wt.Repo != repo || wt.Base != "main" || c.Folder != wt.Path || filepath.Dir(wt.Path) != filepath.Join(repo, ".worktrees") ||
			wt.Branch != "nushi/"+filepath.Base(wt.Path) {
			t.Fatalf("chat = %v", c)
		}
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "pwd"})))
		a.waitFor("the reply", idle)
		wts = append(wts, wt)
	}
	if wts[0].Path == wts[1].Path {
		t.Fatal("both chats got one worktree")
	}

	// A chat without messages moves into a new worktree and back out; the
	// worktree it leaves goes, with its branch.
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: repo}))).ChatId
	must(a.c.MoveChat(ctx, connect.NewRequest(&nushiv1.MoveChatRequest{ChatId: id, Folder: repo, Worktree: true})))
	wt := chat(id).Worktree
	if wt == nil || chat(id).Folder != wt.Path {
		t.Fatalf("after moving to a worktree: %v", chat(id))
	}
	must(a.c.MoveChat(ctx, connect.NewRequest(&nushiv1.MoveChatRequest{ChatId: id, Folder: repo})))
	if c := chat(id); c.Worktree != nil || c.Folder != repo {
		t.Errorf("after moving back: %v", c)
	}
	if _, err := os.Stat(wt.Path); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("the unused worktree is still there: %v", err)
	}

	// A folder outside git has no worktrees.
	if _, err := a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: t.TempDir(), Worktree: true})); err == nil {
		t.Error("a chat started in a worktree outside git")
	}
}

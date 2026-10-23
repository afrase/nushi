package e2e

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/acp/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// gitRepo makes a repository with one commit on main.
func gitRepo(t *testing.T) string {
	t.Helper()
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	gitIn(t, repo, "init", "-q", "-b", "main")
	gitIn(t, repo, "commit", "-q", "--allow-empty", "-m", "init")
	return repo
}

func gitIn(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"}, args...)...)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
}

func TestChatsInWorktrees(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	noCopy := func(string, string, string) (func() error, error) { return func() error { return nil }, nil }
	d := startDaemon(t, t.TempDir(), &acptest.History{}, noCopy)
	a := open(t, d)
	chat := func(id string) *nushiv1.Chat {
		return must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Chat
	}

	// Two chats in new worktrees of one repository: each has its own folder
	// and branch, from main.
	var ids []string
	var wts []*nushiv1.Worktree
	for range 3 {
		id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: repo, Worktree: true}))).ChatId
		c := chat(id)
		wt := c.Worktree
		if wt == nil || wt.Repo != repo || wt.Base != "main" || c.Folder != wt.Path || filepath.Dir(wt.Path) != filepath.Join(repo, ".worktrees") ||
			wt.Branch != "nushi/"+filepath.Base(wt.Path) {
			t.Fatalf("chat = %v", c)
		}
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "pwd"})))
		a.waitFor("the reply", idle)
		ids, wts = append(ids, id), append(wts, wt)
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

	// A chat with messages moved out of its worktree keeps it, and Delete
	// offers it with what removing it would lose.
	id = must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: repo, Worktree: true}))).ChatId
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: "pwd"})))
	a.waitFor("the reply", idle)
	wt = chat(id).Worktree
	gitIn(t, wt.Path, "commit", "-q", "--allow-empty", "-m", "work")
	must(a.c.MoveChat(ctx, connect.NewRequest(&nushiv1.MoveChatRequest{ChatId: id, Folder: repo})))
	if c := chat(id); c.Worktree != nil || c.Folder != repo {
		t.Fatalf("after moving out: %v", c)
	}
	if _, err := os.Stat(wt.Path); err != nil {
		t.Fatalf("the worktree went with the move: %v", err)
	}
	plan := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id})))
	if len(plan.Worktrees) != 1 || plan.Worktrees[0].Worktree.Path != wt.Path || plan.Worktrees[0].State.Commits != 1 || plan.Worktree != nil {
		t.Fatalf("plan after moving out = %v", plan)
	}
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: id, Worktrees: []*nushiv1.WorktreeChoice{
		{Path: wt.Path, RemoveWorktree: true, DeleteBranch: true, ForceBranch: true}}})))
	if _, err := os.Stat(wt.Path); !errors.Is(err, fs.ErrNotExist) || branchExists(repo, wt.Branch) {
		t.Errorf("after deleting the moved chat: the worktree %v, the branch %v", err, branchExists(repo, wt.Branch))
	}

	// Deleting: merged work loses nothing, so the worktree and branch go.
	gitIn(t, wts[0].Path, "commit", "-q", "--allow-empty", "-m", "merged")
	gitIn(t, repo, "merge", "-q", wts[0].Branch)
	plan = must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: ids[0]})))
	if st := plan.WorktreeState; plan.Worktree.GetPath() != wts[0].Path || st.Changed != 0 || st.Commits != 0 || st.Gone {
		t.Fatalf("plan = %v", plan)
	}
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: ids[0], RemoveWorktree: true, DeleteBranch: true})))
	if _, err := os.Stat(wts[0].Path); !errors.Is(err, fs.ErrNotExist) || branchExists(repo, wts[0].Branch) {
		t.Errorf("after deleting a chat with merged work: the worktree %v, the branch %v", err, branchExists(repo, wts[0].Branch))
	}

	// Unmerged commits and changes need forcing.
	gitIn(t, wts[1].Path, "commit", "-q", "--allow-empty", "-m", "unmerged")
	os.WriteFile(filepath.Join(wts[1].Path, "new.txt"), []byte("x"), 0o644)
	plan = must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: ids[1]})))
	if st := plan.WorktreeState; st.Changed != 1 || st.Commits != 1 {
		t.Fatalf("plan = %v", plan)
	}
	for _, req := range []*nushiv1.DeleteChatRequest{{RemoveWorktree: true}, {RemoveWorktree: true, ForceWorktree: true, DeleteBranch: true}} {
		req.ChatId = ids[1]
		if _, err := a.c.DeleteChat(ctx, connect.NewRequest(req)); err == nil {
			t.Errorf("deleted without forcing: %v", req)
		}
	}
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: ids[1], RemoveWorktree: true, ForceWorktree: true})))
	if _, err := os.Stat(wts[1].Path); !errors.Is(err, fs.ErrNotExist) || !branchExists(repo, wts[1].Branch) {
		t.Errorf("the worktree should be gone (%v) and the branch kept", err)
	}

	// A worktree removed outside Nushi: the chat says so, and Delete works.
	os.RemoveAll(wts[2].Path)
	if _, err := a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: ids[2], Text: "hi"})); err == nil ||
		!strings.Contains(err.Error(), "removed outside Nushi") {
		t.Errorf("prompting a chat whose worktree is gone: %v", err)
	}
	plan = must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: ids[2]})))
	if !plan.WorktreeState.Gone {
		t.Errorf("plan = %v", plan)
	}
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: ids[2], RemoveWorktree: true, DeleteBranch: true})))
	if branchExists(repo, wts[2].Branch) {
		t.Error("the branch of the removed worktree is still there")
	}
}

func branchExists(repo, branch string) bool {
	return exec.Command("git", "-C", repo, "rev-parse", "--verify", "-q", "refs/heads/"+branch).Run() == nil
}

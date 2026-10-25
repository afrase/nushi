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

	"github.com/afrase/nushi/internal/acptest"
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
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
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
	if len(plan.Worktrees) != 1 || plan.Worktrees[0].Worktree.Path != wt.Path || plan.Worktrees[0].State.Commits != 1 {
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
	if st := plan.Worktrees[0].State; plan.Worktrees[0].Worktree.Path != wts[0].Path || st.Changed != 0 || st.Commits != 0 || st.Gone {
		t.Fatalf("plan = %v", plan)
	}
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: ids[0], Worktrees: []*nushiv1.WorktreeChoice{
		{Path: wts[0].Path, RemoveWorktree: true, DeleteBranch: true}}})))
	if _, err := os.Stat(wts[0].Path); !errors.Is(err, fs.ErrNotExist) || branchExists(repo, wts[0].Branch) {
		t.Errorf("after deleting a chat with merged work: the worktree %v, the branch %v", err, branchExists(repo, wts[0].Branch))
	}

	// Unmerged commits and changes need forcing.
	gitIn(t, wts[1].Path, "commit", "-q", "--allow-empty", "-m", "unmerged")
	check(t, os.WriteFile(filepath.Join(wts[1].Path, "new.txt"), []byte("x"), 0o644))
	plan = must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: ids[1]})))
	if st := plan.Worktrees[0].State; st.Changed != 1 || st.Commits != 1 {
		t.Fatalf("plan = %v", plan)
	}
	for _, c := range []*nushiv1.WorktreeChoice{{RemoveWorktree: true}, {RemoveWorktree: true, ForceWorktree: true, DeleteBranch: true}} {
		c.Path = wts[1].Path
		req := &nushiv1.DeleteChatRequest{ChatId: ids[1], Worktrees: []*nushiv1.WorktreeChoice{c}}
		if _, err := a.c.DeleteChat(ctx, connect.NewRequest(req)); err == nil {
			t.Errorf("deleted without forcing: %v", c)
		}
		if _, err := os.Stat(filepath.Join(wts[1].Path, "new.txt")); err != nil {
			t.Errorf("a refused delete removed the worktree: %v", err)
		}
	}
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: ids[1], Worktrees: []*nushiv1.WorktreeChoice{
		{Path: wts[1].Path, RemoveWorktree: true, ForceWorktree: true}}})))
	if _, err := os.Stat(wts[1].Path); !errors.Is(err, fs.ErrNotExist) || !branchExists(repo, wts[1].Branch) {
		t.Errorf("the worktree should be gone (%v) and the branch kept", err)
	}

	// A worktree removed outside Nushi: the chat says so, and Delete works.
	check(t, os.RemoveAll(wts[2].Path))
	if _, err := a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: ids[2], Text: "hi"})); err == nil ||
		!strings.Contains(err.Error(), "removed outside Nushi") {
		t.Errorf("prompting a chat whose worktree is gone: %v", err)
	}
	plan = must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: ids[2]})))
	if !plan.Worktrees[0].State.Gone {
		t.Errorf("plan = %v", plan)
	}
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: ids[2], Worktrees: []*nushiv1.WorktreeChoice{
		{Path: wts[2].Path, RemoveWorktree: true, DeleteBranch: true}}})))
	if branchExists(repo, wts[2].Branch) {
		t.Error("the branch of the removed worktree is still there")
	}
}

func branchExists(repo, branch string) bool {
	return exec.Command("git", "-C", repo, "rev-parse", "--verify", "-q", "refs/heads/"+branch).Run() == nil
}

// A chat without messages that moves keeps its worktree when it moves into
// a folder of it, and leaves it on record (for Delete) when it holds work;
// a folder git doesn't track gets no worktree.
func TestWorktreeMovesKeepTheWork(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	check(t, os.MkdirAll(filepath.Join(repo, "newapp"), 0o755))
	check(t, os.WriteFile(filepath.Join(repo, "newapp", "a.txt"), []byte("new\n"), 0o644))
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	if _, err := a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: filepath.Join(repo, "newapp"), Worktree: true})); err == nil {
		t.Error("a worktree chat in a folder the worktree doesn't have started")
	}
	chat := func(id string) *nushiv1.Chat {
		return must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id}))).Chat
	}
	move := func(id, folder string) {
		t.Helper()
		must(a.c.MoveChat(ctx, connect.NewRequest(&nushiv1.MoveChatRequest{ChatId: id, Folder: folder})))
	}
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: repo, Worktree: true}))).ChatId
	wt := chat(id).Worktree
	sub := filepath.Join(wt.Path, "sub")
	check(t, os.Mkdir(sub, 0o755))
	move(id, sub)
	if c := chat(id); c.Worktree.GetPath() != wt.Path || c.Folder != sub {
		t.Errorf("moved into its worktree: %v", c)
	}
	if _, err := os.Stat(sub); err != nil {
		t.Fatalf("the folder the chat moved to went: %v", err)
	}

	gitIn(t, wt.Path, "commit", "-q", "--allow-empty", "-m", "work")
	move(id, repo)
	plan := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id})))
	if len(plan.Worktrees) != 1 || plan.Worktrees[0].Worktree.Path != wt.Path || plan.Worktrees[0].State.Commits != 1 {
		t.Errorf("the worktree it left, with a commit, isn't offered: %v", plan.Worktrees)
	}

	// Nor one a terminal runs in; Delete ends the terminal, then removes it.
	id = must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: repo, Worktree: true}))).ChatId
	wt = chat(id).Worktree
	must(a.c.OpenTerminal(ctx, connect.NewRequest(&nushiv1.OpenTerminalRequest{ChatId: id, Cols: 80, Rows: 24})))
	move(id, repo)
	if _, err := os.Stat(wt.Path); err != nil {
		t.Fatalf("a worktree with a terminal in it went: %v", err)
	}
	plan = must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id})))
	if len(plan.Worktrees) != 1 || len(plan.Terminals) != 1 {
		t.Fatalf("plan = %v", plan)
	}
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: id, Worktrees: []*nushiv1.WorktreeChoice{
		{Path: wt.Path, RemoveWorktree: true, DeleteBranch: true}}})))
	left := must(a.c.ListTerminals(ctx, connect.NewRequest(&nushiv1.ListTerminalsRequest{ChatId: id}))).Terminals
	if _, err := os.Stat(wt.Path); !errors.Is(err, fs.ErrNotExist) || len(left) > 0 {
		t.Errorf("after Delete: the worktree %v, terminals %v", err, left)
	}
}

// A chat on a Jira issue remembers it, and its worktree is on the branch
// asked for (another chat on it gets the next number), in a folder named
// after it.
func TestChatOnAnIssue(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	start := func(branch string) (*nushiv1.Chat, error) {
		r, err := a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: repo, Worktree: true,
			JiraSite: "acme.atlassian.net", JiraKey: "ACME-12", JiraSummary: "Log in with a passkey", Branch: branch}))
		if err != nil {
			return nil, err
		}
		return must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: r.Msg.ChatId}))).Chat, nil
	}
	for _, c := range []struct{ branch, want, folder string }{
		{"ACME-12-log-in-with-a-passkey", "ACME-12-log-in-with-a-passkey", "ACME-12-log-in-with-a-passkey"},
		{"ACME-12-log-in-with-a-passkey", "ACME-12-log-in-with-a-passkey-2", "ACME-12-log-in-with-a-passkey-2"},
		{"me/ACME-12", "me/ACME-12", "me-ACME-12"}, // the user's own
	} {
		chat, err := start(c.branch)
		if err != nil {
			t.Fatal(err)
		}
		if chat.JiraSite != "acme.atlassian.net" || chat.JiraKey != "ACME-12" || chat.Worktree.GetBranch() != c.want ||
			filepath.Base(chat.Worktree.GetPath()) != c.folder {
			t.Errorf("chat %v, want branch %s in %s", chat, c.want, c.folder)
		}
	}
	for _, bad := range []string{"ACME-12/../../x", "-ACME-12", "a b", "x.lock"} {
		if _, err := start(bad); err == nil {
			t.Errorf("branch %q taken", bad)
		}
	}
	list := must(a.c.ListChats(ctx, connect.NewRequest(&nushiv1.ListChatsRequest{}))).Chats
	if len(list) != 3 || list[0].JiraKey != "ACME-12" {
		t.Errorf("listed %v", list)
	}
}

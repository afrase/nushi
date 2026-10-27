package e2e

import (
	"context"
	"os/exec"
	"slices"
	"strings"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// A plain worktree chat's branch is named after the chat once a turn ends
// with a title: once, its folder staying, a number after a taken name;
// not mid-turn, not once pushed or renamed by the user, not for a title
// without words. Delete still offers the renamed branch.
func TestBranchNamedAfterTheChat(t *testing.T) {
	ctx := context.Background()
	repo := gitRepo(t)
	d := startDaemon(t, t.TempDir(), &acptest.History{}, nil)
	a := open(t, d)
	get := func(id string) *nushiv1.GetChatResponse {
		return must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	}
	start := func() (string, *nushiv1.Worktree) {
		id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: repo, Worktree: true}))).ChatId
		return id, get(id).Chat.Worktree
	}
	until := func(what string, ok func() bool) { t.Helper(); until(t, what, ok) }
	// turn sends text and waits for the turn's end.
	turn := func(id, text string) *nushiv1.GetChatResponse {
		t.Helper()
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: text})))
		return settled(ctx, t, a, id)
	}
	head := func(dir string) string {
		out, _ := exec.Command("git", "-C", dir, "symbolic-ref", "--short", "HEAD").Output()
		return strings.TrimSpace(string(out))
	}
	renamed := func(r *nushiv1.GetChatResponse) []string {
		var out []string
		for _, it := range r.Items {
			if it.Kind == nushiv1.ItemKind_ITEM_KIND_NOTICE && it.Status == "branch_renamed" {
				out = append(out, it.Text)
			}
		}
		return out
	}

	// Named after the agent's title at the turn's end: the worktree follows,
	// in its own folder; the transcript says so. Only once.
	id, wt := start()
	if !strings.HasPrefix(wt.Branch, "nushi/") || head(wt.Path) != wt.Branch {
		t.Fatalf("a new worktree: %v", wt)
	}
	r := turn(id, "hello\ntitle: Bump Go to 1.27.3")
	const want = "nushi/bump-go-to-1-27-3"
	if c := r.Chat; c.Worktree.Branch != want || c.Worktree.Path != wt.Path || c.Folder != wt.Path || head(wt.Path) != want || branchExists(repo, wt.Branch) {
		t.Fatalf("after the first turn: %v, the worktree on %q", c, head(wt.Path))
	}
	if got := renamed(r); !slices.Equal(got, []string{"Branch renamed to " + want}) {
		t.Errorf("notices: %q", got)
	}
	if c := turn(id, "title: Something else").Chat; c.Worktree.Branch != want || c.Title != "Something else" {
		t.Errorf("renamed again: %v", c)
	}

	// An agent that names its sessions (as Claude does) is waited for, when
	// its title comes after the first turn; one that doesn't (Codex here),
	// not. Without the agent's title, the turn after goes on with the
	// first prompt's line.
	idLate, wtLate := start()
	if r := turn(idLate, "hello\nlate title: Go version bump"); r.Chat.Worktree.Branch != wtLate.Branch {
		t.Errorf("named before the agent's title: %v", r.Chat.Worktree)
	}
	until("the late title's name", func() bool { return get(idLate).Chat.Worktree.Branch == "nushi/go-version-bump" })
	if got := renamed(get(idLate)); len(got) != 1 {
		t.Errorf("notices: %q", got)
	}
	idNone, wtNone := start()
	if got := turn(idNone, "hello there").Chat.Worktree.Branch; got != wtNone.Branch {
		t.Errorf("named after one turn without the agent's title: %s", got)
	}
	if got := turn(idNone, "again").Chat.Worktree.Branch; got != "nushi/hello-there" {
		t.Errorf("after the second turn: %s", got)
	}
	idCodex := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Agent: "codex", Folder: repo, Worktree: true}))).ChatId
	if got := turn(idCodex, "plain words").Chat.Worktree.Branch; got != "nushi/plain-words" {
		t.Errorf("a Codex chat's branch: %s", got)
	}

	// A taken name gets a number.
	id2, _ := start()
	if got := turn(id2, "title: Bump Go to 1.27.3").Chat.Worktree.Branch; got != want+"-2" {
		t.Errorf("a taken name: %s", got)
	}

	// Mid-turn the title comes, and the branch waits for the turn's end.
	id3, wt3 := start()
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id3, Text: "title: Slow work\nwait"})))
	until("the agent's title", func() bool { return get(id3).Chat.Title == "Slow work" })
	time.Sleep(50 * time.Millisecond)
	if r := get(id3); !r.Status.Busy || r.Chat.Worktree.Branch != wt3.Branch || head(wt3.Path) != wt3.Branch {
		t.Fatalf("mid-turn: %v, the worktree on %q", r, head(wt3.Path))
	}
	must(a.c.CancelTurn(ctx, connect.NewRequest(&nushiv1.CancelTurnRequest{ChatId: id3})))
	until("the turn's end", func() bool { return !get(id3).Status.Busy })
	if got := get(id3).Chat.Worktree.Branch; got != "nushi/slow-work" || head(wt3.Path) != got {
		t.Errorf("after a stopped turn: %s", got)
	}

	// Odd titles: only their ASCII words; without any, the two words stay
	// until a title has some.
	for title, want := range map[string]string{
		"🚀 Ship it! (v2)":           "nushi/ship-it-v2",
		"fix/login: a//b ~^":        "nushi/fix-login-a-b",
		"Ünïcode — ok":              "nushi/n-code-ok",
		strings.Repeat("word ", 20): "nushi/word-word-word-word-word-word-word-word",
	} {
		id, _ := start()
		if got := turn(id, "title: "+title).Chat.Worktree.Branch; got != want {
			t.Errorf("%q: %s, want %s", title, got, want)
		}
	}
	id5, wt5 := start()
	if got := turn(id5, "title: ?!… 🙂").Chat.Worktree.Branch; got != wt5.Branch {
		t.Errorf("a title without words: %s", got)
	}
	if got := turn(id5, "title: Now with words").Chat.Worktree.Branch; got != "nushi/now-with-words" {
		t.Errorf("after a title with words: %s", got)
	}

	// Not once pushed, as it was, nor after.
	bare := t.TempDir()
	gitIn(t, bare, "init", "-q", "--bare")
	gitIn(t, repo, "remote", "add", "origin", bare)
	id6, wt6 := start()
	gitIn(t, wt6.Path, "push", "-q", "-u", "origin", "HEAD")
	for _, title := range []string{"Pushed work", "Still pushed"} {
		if got := turn(id6, "title: "+title).Chat.Worktree.Branch; got != wt6.Branch {
			t.Errorf("a pushed branch renamed to %s", got)
		}
	}
	rename := func(id, branch string) error {
		_, err := a.c.RenameBranch(ctx, connect.NewRequest(&nushiv1.RenameBranchRequest{ChatId: id, Branch: branch}))
		return err
	}
	if err := rename(id6, "nushi/mine"); err == nil || !strings.Contains(err.Error(), "on the remote") {
		t.Errorf("renaming a pushed branch: %v", err)
	}

	// Renamed by the user: the title no longer names it.
	id7, wt7 := start()
	for _, bad := range []string{"a b", "-x", "x.lock", want} {
		if err := rename(id7, bad); err == nil {
			t.Errorf("renamed to %q", bad)
		}
	}
	if err := rename(id7, "me/my-name"); err != nil {
		t.Fatal(err)
	}
	if c := get(id7).Chat; c.Worktree.Branch != "me/my-name" || head(wt7.Path) != "me/my-name" || c.Worktree.Path != wt7.Path {
		t.Errorf("after Rename branch: %v", c)
	}
	if r := turn(id7, "title: Named after this"); r.Chat.Worktree.Branch != "me/my-name" || len(renamed(r)) > 0 {
		t.Errorf("the title renamed a branch the user named: %v", r.Chat.Worktree)
	}
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id7, Text: "wait"})))
	until("the turn's start", func() bool { return get(id7).Status.Busy })
	if err := rename(id7, "me/mid-turn"); err == nil {
		t.Error("renamed mid-turn")
	}
	must(a.c.CancelTurn(ctx, connect.NewRequest(&nushiv1.CancelTurnRequest{ChatId: id7})))

	// Delete offers the renamed branch and deletes it.
	gitIn(t, wt.Path, "commit", "-q", "--allow-empty", "-m", "work")
	plan := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: id})))
	if p := plan.Worktrees[0]; p.Worktree.Branch != want || p.State.BranchGone || p.State.Commits != 1 {
		t.Fatalf("plan = %v", plan)
	}
	must(a.c.DeleteChat(ctx, connect.NewRequest(&nushiv1.DeleteChatRequest{ChatId: id, Worktrees: []*nushiv1.WorktreeChoice{
		{Path: wt.Path, RemoveWorktree: true, DeleteBranch: true, ForceBranch: true}}})))
	if branchExists(repo, want) {
		t.Error("Delete left the renamed branch")
	}
}

// until waits for ok, 5 s at most.
func until(t *testing.T, what string, ok func() bool) {
	t.Helper()
	for end := time.Now().Add(5 * time.Second); !ok(); time.Sleep(10 * time.Millisecond) {
		if time.Now().After(end) {
			t.Fatalf("timed out waiting for %s", what)
		}
	}
}

// settled waits for a chat's turn to end, and returns the chat.
func settled(ctx context.Context, t *testing.T, a *app, id string) *nushiv1.GetChatResponse {
	t.Helper()
	get := func() *nushiv1.GetChatResponse {
		return must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	}
	until(t, "the turn's end", func() bool { return !get().Status.Busy })
	return get()
}

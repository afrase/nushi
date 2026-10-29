package e2e

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/testcheck"
)

// A chat in a repository's own folder switches its branch from the
// Environment widget, with the guards: not to a branch another worktree
// has (it opens that worktree instead), not with uncommitted changes, not
// while a chat in the folder works, and only once the user knows the
// folder's other chats go along. Every chat there is told with its next
// prompt. Then it moves into the worktree that was there, which Nushi
// never removes.
func TestSwitchBranchAndOpenAWorktree(t *testing.T) {
	ctx := context.Background()
	repo, history := gitRepo(t), &acptest.History{}
	if err := os.WriteFile(filepath.Join(repo, "a.txt"), []byte("a\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "a")
	testcheck.Git(t, repo, "branch", "other")
	try := filepath.Join(repo, ".worktrees", "cappy", "try-sqrly")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "try-sqrly", try)
	d := startDaemon(t, t.TempDir(), history, nil)
	a := open(t, d)
	get := func(id string) *nushiv1.GetChatResponse {
		return must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	}
	start := func(text string) string {
		id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: repo}))).ChatId
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: text})))
		settled(ctx, t, a, id)
		return id
	}
	turn := func(id, text string) []string {
		t.Helper()
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: text})))
		p := history.Prompts(settled(ctx, t, a, id).Chat.SessionId)
		return p[len(p)-1]
	}
	switchTo := func(id, branch string, others bool) (*nushiv1.SwitchBranchResponse, error) {
		r, err := a.c.SwitchBranch(ctx, connect.NewRequest(&nushiv1.SwitchBranchRequest{ChatId: id, Branch: branch, WithOthers: others}))
		if err != nil {
			return nil, err
		}
		return r.Msg, nil
	}
	on := func() string {
		b, err := os.ReadFile(filepath.Join(repo, ".git", "HEAD"))
		if err != nil {
			t.Fatal(err)
		}
		return strings.TrimSpace(strings.TrimPrefix(string(b), "ref: refs/heads/"))
	}
	one, two := start("title: One"), start("title: Two")

	// The lists: branches with the worktree that has each, the worktrees.
	l := must(a.c.ListBranches(ctx, connect.NewRequest(&nushiv1.ListBranchesRequest{Folder: repo})))
	at := map[string]string{}
	for _, b := range l.Branches {
		at[b.Name] = b.Worktree
	}
	if len(at) != 3 || at["main"] != repo || at["other"] != "" || at["try-sqrly"] != try {
		t.Errorf("branches: %v", at)
	}
	if len(l.Worktrees) != 2 || !l.Worktrees[0].Main || !l.Worktrees[0].Current || l.Worktrees[1].Path != try || l.Worktrees[1].Branch != "try-sqrly" {
		t.Errorf("worktrees: %v", l.Worktrees)
	}

	// Another worktree's branch: that worktree, not a switch.
	if r, err := switchTo(one, "try-sqrly", true); err != nil || r.Switched || r.Worktree != try {
		t.Errorf("a worktree's branch: %v, %v", r, err)
	}
	// Uncommitted changes: not switched, and nothing stashed.
	if err := os.WriteFile(filepath.Join(repo, "a.txt"), []byte("changed\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if r, err := switchTo(one, "other", true); err != nil || r.Switched || r.Changed != 1 || on() != "main" {
		t.Errorf("with a change: %v, %v, on %s", r, err, on())
	}
	testcheck.Git(t, repo, "checkout", "--", "a.txt")
	// The folder's other chat mid-turn: refused, naming it.
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: two, Text: "wait"})))
	if _, err := switchTo(one, "other", true); err == nil || !strings.Contains(err.Error(), "“Two” is working") {
		t.Errorf("another chat mid-turn: %v", err)
	}
	must(a.c.CancelTurn(ctx, connect.NewRequest(&nushiv1.CancelTurnRequest{ChatId: two})))
	settled(ctx, t, a, two)
	// Its own turn: refused.
	must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: one, Text: "wait"})))
	if _, err := switchTo(one, "other", true); err == nil || !strings.Contains(err.Error(), "agent is working") {
		t.Errorf("mid-turn: %v", err)
	}
	must(a.c.CancelTurn(ctx, connect.NewRequest(&nushiv1.CancelTurnRequest{ChatId: one})))
	settled(ctx, t, a, one)
	// The other chat goes along: asked first.
	if r, err := switchTo(one, "other", false); err != nil || r.Switched || !slices.Equal(r.Others, []string{"Two"}) || on() != "main" {
		t.Errorf("with another chat there: %v, %v", r, err)
	}
	if r, err := switchTo(one, "other", true); err != nil || !r.Switched || on() != "other" {
		t.Fatalf("switched: %v, %v, on %s", r, err, on())
	}

	// Both agents are told with their next prompt, once; the lines say so.
	note := "[Nushi] This folder's branch changed from main to other. Work on other from now on."
	for _, id := range []string{one, two} {
		if got := turn(id, "next"); !slices.Equal(got, []string{note, "next"}) {
			t.Errorf("the prompt after the switch: %q", got)
		}
		if got := turn(id, "again"); !slices.Equal(got, []string{"again"}) {
			t.Errorf("told twice: %q", got)
		}
	}
	lines := 0
	for _, it := range get(one).Items {
		if it.Status == "branch_switched" && it.Text == "Switched to branch other · told the agent" {
			lines++
		}
	}
	if lines != 1 {
		t.Errorf("the switch's line: %d", lines)
	}
	// Switched and back: nothing to tell.
	for _, b := range []string{"main", "other"} {
		if _, err := switchTo(two, b, true); err != nil {
			t.Fatal(err)
		}
	}
	if got := turn(two, "back"); !slices.Equal(got, []string{"back"}) {
		t.Errorf("switched back: %q", got)
	}

	// Into the worktree that was there: the chat runs in it, listed under
	// the repository, is told where it is, and Delete leaves the worktree.
	if _, err := a.c.MoveChat(ctx, connect.NewRequest(&nushiv1.MoveChatRequest{ChatId: one, Folder: try})); err != nil {
		t.Fatal(err)
	}
	c := get(one).Chat
	if wt := c.Worktree; c.Folder != try || wt == nil || !wt.Found || wt.Path != try || wt.Repo != repo || wt.Branch != "try-sqrly" {
		t.Fatalf("moved: %s in %v", c.Folder, c.Worktree)
	}
	moved := "[Nushi] This chat moved to `" + try + "`, on branch try-sqrly. Work there from now on."
	if got := turn(one, "where"); !slices.Equal(got, []string{moved, "where"}) {
		t.Errorf("the prompt after the move: %q", got)
	}
	if _, err := switchTo(one, "main", true); err == nil || !strings.Contains(err.Error(), "worktree") {
		t.Errorf("a worktree chat's switch: %v", err)
	}
	if p := must(a.c.PlanDeleteChat(ctx, connect.NewRequest(&nushiv1.PlanDeleteChatRequest{ChatId: one}))); len(p.Worktrees) != 0 {
		t.Errorf("Delete offers the worktree that was there: %v", p.Worktrees)
	}
	// A new chat there runs in it the same way.
	id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: try}))).ChatId
	if wt := get(id).Chat.Worktree; wt == nil || !wt.Found || wt.Path != try {
		t.Errorf("a new chat in the worktree: %v", wt)
	}
	// Back to the repository's own folder: a plain chat again; the
	// worktree stays.
	if _, err := a.c.MoveChat(ctx, connect.NewRequest(&nushiv1.MoveChatRequest{ChatId: one, Folder: repo})); err != nil {
		t.Fatal(err)
	}
	if c := get(one).Chat; c.Worktree != nil || c.Folder != repo {
		t.Errorf("back: %s in %v", c.Folder, c.Worktree)
	}
	if _, err := os.Stat(try); err != nil {
		t.Errorf("the worktree that was there: %v", err)
	}
}

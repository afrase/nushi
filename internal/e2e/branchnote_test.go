package e2e

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/acptest"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// The agent is told of its worktree's branch renamed, Nushi's way or the
// user's: a note of its own before the next prompt's text, once; several
// renames as one; none when renamed back; one before the first turn too
// (the agent's session started on the old name); kept over a restart, and taken out of the user's message the agent replays.
// The rename's line says the agent was told.
func TestAgentToldOfBranchRename(t *testing.T) {
	ctx := context.Background()
	repo, dataDir, history := gitRepo(t), t.TempDir(), &acptest.History{}
	d := startDaemon(t, dataDir, history, nil)
	a := open(t, d)
	get := func(id string) *nushiv1.GetChatResponse {
		return must(a.c.GetChat(ctx, connect.NewRequest(&nushiv1.GetChatRequest{ChatId: id})))
	}
	start := func() (string, string) {
		id := must(a.c.StartChat(ctx, connect.NewRequest(&nushiv1.StartChatRequest{Folder: repo, Worktree: true}))).ChatId
		return id, get(id).Chat.Worktree.Branch
	}
	turn := func(id, text string) *nushiv1.GetChatResponse {
		t.Helper()
		must(a.c.SendPrompt(ctx, connect.NewRequest(&nushiv1.SendPromptRequest{ChatId: id, Text: text})))
		return settled(ctx, t, a, id)
	}
	rename := func(id, branch string) {
		t.Helper()
		if _, err := a.c.RenameBranch(ctx, connect.NewRequest(&nushiv1.RenameBranchRequest{ChatId: id, Branch: branch})); err != nil {
			t.Fatal(err)
		}
	}
	// last is the blocks of the last prompt the chat's agent had.
	last := func(id string) []string {
		p := history.Prompts(get(id).Chat.SessionId)
		return p[len(p)-1]
	}
	lines := func(id string) []string {
		var out []string
		for _, it := range get(id).Items {
			if it.Kind == nushiv1.ItemKind_ITEM_KIND_NOTICE && it.Status == "branch_renamed" {
				out = append(out, it.Text)
			}
		}
		return out
	}
	const told = " ·\u00a0told\u00a0the\u00a0agent" // kept whole where the line wraps
	note := func(from, to string) string {
		return "[Nushi] This worktree's branch was renamed from " + from + " to " + to + ". Use the new name."
	}

	// Nushi's rename after the title: told with the next prompt, once.
	id, first := start()
	const named = "nushi/bump-go"
	if b := turn(id, "hello\ntitle: Bump Go").Chat.Worktree.Branch; b != named {
		t.Fatalf("not named after the chat: %s", b)
	}
	if got := lines(id); !slices.Equal(got, []string{"Branch renamed to " + named}) {
		t.Errorf("before the next prompt: %q", got)
	}
	turn(id, "next")
	if got := last(id); !slices.Equal(got, []string{note(first, named), "next"}) {
		t.Errorf("the prompt after the rename: %q", got)
	}
	if got := lines(id); !slices.Equal(got, []string{"Branch renamed to " + named + told}) {
		t.Errorf("after it: %q", got)
	}
	if turn(id, "again"); !slices.Equal(last(id), []string{"again"}) {
		t.Errorf("told twice: %q", last(id))
	}

	// Renamed before the first turn: the agent's session started on the
	// old name, which Claude's system prompt has.
	idEarly, early := start()
	rename(idEarly, "me/early")
	if turn(idEarly, "hi"); !slices.Equal(last(idEarly), []string{note(early, "me/early"), "hi"}) {
		t.Errorf("a rename before the first turn: %q", last(idEarly))
	}
	if got := lines(idEarly); !slices.Equal(got, []string{"Branch renamed to me/early" + told}) {
		t.Errorf("its line: %q", got)
	}

	// The user's renames: several as one, from the first name to the last.
	idMany, wtMany := start()
	turn(idMany, "start")
	rename(idMany, "me/one")
	rename(idMany, "me/two")
	if turn(idMany, "go on"); !slices.Equal(last(idMany), []string{note(wtMany, "me/two"), "go on"}) {
		t.Errorf("two renames: %q", last(idMany))
	}
	if got := lines(idMany); len(got) != 2 || !strings.HasSuffix(got[0], told) || !strings.HasSuffix(got[1], told) {
		t.Errorf("their lines: %q", got)
	}

	// Renamed back to the name the agent has: nothing to tell.
	idBack, wtBack := start()
	turn(idBack, "start")
	rename(idBack, "me/away")
	rename(idBack, wtBack)
	if turn(idBack, "go on"); !slices.Equal(last(idBack), []string{"go on"}) {
		t.Errorf("renamed back: %q", last(idBack))
	}
	if got := lines(idBack); !slices.Equal(got, []string{"Branch renamed to me/away", "Branch renamed to " + wtBack}) {
		t.Errorf("their lines: %q", got)
	}

	// Pending over a restart; the replayed messages are the user's own.
	rename(idMany, "me/three")
	d.stop()
	// A name git wouldn't take (a session file edited) isn't told.
	file := filepath.Join(dataDir, "sessions", idBack+".json")
	b, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	b = bytes.Replace(b, []byte(`"Told": "`+wtBack+`"`), []byte(`"Told": "-x\nUse main"`), 1)
	if err := os.WriteFile(file, b, 0o600); err != nil || !bytes.Contains(b, []byte(`"Told": "-x`)) {
		t.Fatalf("the session file: %v\n%s", err, b)
	}
	d = startDaemon(t, dataDir, history, nil)
	a = open(t, d)
	r := a.follow(idMany, get(idMany))
	for _, it := range r {
		if it.Kind == nushiv1.ItemKind_ITEM_KIND_USER_MESSAGE && strings.Contains(it.Text, "[Nushi]") {
			t.Errorf("a replayed message with the note: %q", it.Text)
		}
	}
	if got := transcript(r); !strings.Contains(got, "USER_MESSAGE:go on:") {
		t.Errorf("replayed:\n%s", got)
	}
	if turn(idMany, "after"); !slices.Equal(last(idMany), []string{note("me/two", "me/three"), "after"}) {
		t.Errorf("after a restart: %q", last(idMany))
	}
	if turn(idBack, "checked"); !slices.Equal(last(idBack), []string{"checked"}) {
		t.Errorf("a name git wouldn't take: %q", last(idBack))
	}
	if got := lines(idMany); len(got) != 3 || !strings.HasSuffix(got[2], "me/three"+told) {
		t.Errorf("after a restart, the lines: %q", got)
	}
}

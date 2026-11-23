package chats

import (
	"context"
	"log/slog"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// A replayed user's message loses the note that went before it: a block
// of its own, or run into the user's text; nothing else.
func TestUnnoted(t *testing.T) {
	note := branchNote("nushi/brave-otter", "nushi/bump-go-1-27-3")
	if note != `<nushi-branch-renamed from="nushi/brave-otter" to="nushi/bump-go-1-27-3"/>` {
		t.Errorf("the note: %q", note)
	}
	for in, want := range map[string]string{
		note:                       "",
		note + "go on":             "go on",
		note + "\n\ngo on\n":       "go on\n",
		"go on " + note:            "go on " + note,
		"<nushi-branch-renamed":    "<nushi-branch-renamed",
		"plain\n" + note + "\nend": "plain\n" + note + "\nend",
		`<nushi-x a="b">c`:         `<nushi-x a="b">c`,
	} {
		got, ok := unnoted(in)
		if got != want || ok != (got != in) {
			t.Errorf("unnoted(%q) = %q, %v; want %q", in, got, ok, want)
		}
	}
}

// Each note is a bare tag, its values escaped so none ends it early, and
// the replay takes every one off, however it's run together.
func TestNotesAreBareTags(t *testing.T) {
	for _, c := range []struct{ got, want string }{
		{switchNote("main", "other"), `<nushi-branch-switched from="main" to="other"/>`},
		{moveNote("/r/a b", ""), `<nushi-moved folder="/r/a b"/>`},
		{moveNote("/r/try", "try-sqrly"), `<nushi-moved folder="/r/try" branch="try-sqrly"/>`},
		{stopNote("b1x_2"), `<nushi-command-stopped id="b1x_2"/>`},
		{editNote("a.go"), `<nushi-edited path="a.go"/>`},
		{editNote(`odd"/><x y="`), `<nushi-edited path="odd&#34;/&gt;&lt;x y=&#34;"/>`},
		{editNote("a&b`c'.go"), `<nushi-edited path="a&amp;b` + "`" + `c&#39;.go"/>`},
	} {
		if c.got != c.want {
			t.Errorf("got %s, want %s", c.got, c.want)
		}
	}
	all := stopNote("b1") + editNote(`x"/>y`) + "\n\n" + moveNote("/r", "b") + branchNote("a", "b") + "Carry on"
	if text, ok := unnoted(all); !ok || text != "Carry on" {
		t.Errorf("replayed as %q", text)
	}
}

// A session written before the notes were tags still replays without
// them: the sentences Nushi sent then, as they were.
func TestOldNotesStillUnnoted(t *testing.T) {
	for _, old := range []string{
		"[Nushi] This worktree's branch was renamed from nushi/brave-otter to nushi/bump-go-1-27-3. Use the new name.",
		"[Nushi] This folder's branch changed from main to other. Work on other from now on.",
		"[Nushi] This chat moved to `/Users/me/src/try`. Work there from now on.",
		"[Nushi] This chat moved to `/Users/me/src/try`, on branch try-sqrly. Work there from now on.",
		"[Nushi] The user stopped your background command bx81fz2; its exit code was that stop, not a failure.",
		"[Nushi] The user edited `a.go` in Nushi since your last turn; re-read it before changing it.",
		"[Nushi] The user edited `a.go`, `docs/b.md` in Nushi since your last turn; re-read them before changing them.",
	} {
		for _, in := range []string{old + "\n\nCarry on", old + "Carry on"} {
			if text, ok := unnoted(in); !ok || text != "Carry on" {
				t.Errorf("unnoted(%q) = %q, %v", in, text, ok)
			}
		}
	}
	both := "[Nushi] The user stopped your background command b1; its exit code was that stop, not a failure.\n\n" +
		"[Nushi] This folder's branch changed from main to other. Work on other from now on.\n\nCarry on"
	if text, ok := unnoted(both); !ok || text != "Carry on" {
		t.Errorf("two old notes replayed as %q", text)
	}
}

// heldWorktrees holds each CheckBranch until held is closed.
type heldWorktrees struct {
	stuckWorktrees
	checking chan struct{}
	held     chan struct{}
}

func (w *heldWorktrees) CheckBranch(context.Context, string, string) error {
	select {
	case w.checking <- struct{}{}:
	default:
	}
	<-w.held
	return nil
}

// The note of a branch renamed is checked with git without the chat's
// lock: the chat answers meanwhile; the prompt then goes with the note,
// and the rename's line says it was told.
func TestBranchNoteChecksOutsideTheLock(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	wts := &heldWorktrees{checking: make(chan struct{}, 1), held: make(chan struct{})}
	c.mu.Lock()
	c.worktrees = wts
	c.record.Worktree = &model.Worktree{Repo: "/r", Path: "/r", Branch: "nushi/new", Told: "nushi/old"}
	line := c.addLocked(model.Item{Kind: model.Notice, Status: "branch_renamed", Text: "Branch renamed to nushi/new"})
	c.mu.Unlock()
	sent := make(chan error, 1)
	go func() { sent <- svc.Prompt(t.Context(), c.id, model.Message{Text: "go on"}, SendIdle) }()
	<-wts.checking
	locked := make(chan struct{})
	go func() {
		c.mu.Lock()
		defer c.mu.Unlock()
		close(locked)
	}()
	select {
	case <-locked:
	case <-time.After(5 * time.Second):
		t.Error("the chat stayed locked while git checked the names")
	}
	close(wts.held)
	testcheck.NoErr(t, <-sent)
	idle(t, c)
	agent.mu.Lock()
	prompt := agent.prompt
	agent.mu.Unlock()
	if len(prompt) != 2 || prompt[0].Text.Text != branchNote("nushi/old", "nushi/new") || prompt[1].Text.Text != "go on" {
		t.Errorf("prompt %+v", prompt)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if it := c.itemLocked(line); it == nil || !strings.HasSuffix(it.Text, toldSuffix) || c.record.Worktree.Told != "nushi/new" {
		t.Errorf("line %+v, told %q", it, c.record.Worktree.Told)
	}
}

// A move is told for any folder but one with a line break, which would
// split the note: a folder's name may hold a zero-width joiner (an emoji
// sequence), a soft hyphen or a tab, as it could before the notes were
// tags; the tag's quoting keeps each inside it.
func TestMoveToldForAnyFolderButALineBreak(t *testing.T) {
	for folder, told := range map[string]bool{
		"/Users/me/👩\u200d💻 work":    true,
		"/Users/me/soft\u00adhyphen": true,
		"/Users/me/a\tb":             true,
		"/Users/me/it's & `x`":       true,
		"/Users/me/a\nb":             false,
		"/Users/me/a\rb":             false,
	} {
		n := &notes{sess: model.ChatRecord{Folder: folder, Moved: true}, git: stuckWorktrees{}, log: slog.New(slog.DiscardHandler)}
		block, _, pending := n.place()
		if !pending || (block != nil) != told {
			t.Errorf("%q: note %v, pending %v; want told %v", folder, block, pending, told)
		}
		if block != nil && block.Text.Text != moveNote(folder, "") {
			t.Errorf("%q: note %s", folder, block.Text.Text)
		}
	}
}

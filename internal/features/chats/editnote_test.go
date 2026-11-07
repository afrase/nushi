package chats

import (
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// A file the user saved in the preview goes with the chat's next prompt
// as a note of its own, once, by its name in the chat's folder (several
// as one note, each once); the replay leaves the note out.
func TestTheAgentHearsOfAFileTheUserEdited(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.mu.Lock()
	folder := c.record.Folder
	c.mu.Unlock()
	svc.UserEdited(c.id, filepath.Join(realPath(folder), "a.go"))
	svc.UserEdited(c.id, filepath.Join(folder, "docs", "b.md"))
	svc.UserEdited("another", filepath.Join(folder, "a.go"))
	svc.UserEdited("another", "/elsewhere/c.md")               // not in its folder, nor its save
	svc.UserEdited(c.id, filepath.Join(folder, "odd`name.go")) // can't be named in the note
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "Carry on"}, SendQueue))
	eventually(t, c, func() bool { return !c.busy })
	agent.mu.Lock()
	sent := agent.prompt
	agent.mu.Unlock()
	want := "[Nushi] The user edited `a.go`, `docs/b.md` in Nushi since your last turn; re-read them before changing them."
	if len(sent) != 2 || sent[0].Text.Text != want || sent[1].Text.Text != "Carry on" {
		t.Fatalf("sent %+v", sent)
	}
	if text, ok := unnoted(want + "\n\nCarry on"); !ok || text != "Carry on" {
		t.Errorf("replayed as %q", text)
	}
	one := editNote([]string{"/Users/me/.claude/plans/plan.md"})
	if text, ok := unnoted(one + "go on"); !ok || text != "go on" {
		t.Errorf("one file's note replayed as %q", text)
	}
	// Told once.
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "Again"}, SendQueue))
	eventually(t, c, func() bool { return !c.busy })
	agent.mu.Lock()
	sent = agent.prompt
	agent.mu.Unlock()
	if len(sent) != 1 || sent[0].Text.Text != "Again" {
		t.Errorf("the second prompt sent %+v", sent)
	}
}

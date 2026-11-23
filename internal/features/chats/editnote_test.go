package chats

import (
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// A file the user saved in the preview goes with the chat's next prompt
// as a note of its own, once, by its name in the chat's folder (a tag a
// file, each once); the replay leaves the notes out.
func TestTheAgentHearsOfAFileTheUserEdited(t *testing.T) {
	svc, agent, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	c.mu.Lock()
	folder := c.record.Folder
	c.mu.Unlock()
	svc.UserEdited(c.id, filepath.Join(git.RealPath(folder), "a.go"))
	svc.UserEdited(c.id, filepath.Join(folder, "docs", "b.md"))
	svc.UserEdited("another", filepath.Join(folder, "a.go"))
	svc.UserEdited("another", "/elsewhere/c.md")                                     // not in its folder, nor its save
	svc.UserEdited(c.id, filepath.Join(folder, "odd"+string(rune(0x0a))+"name.go"))  // can't be named in the note
	svc.UserEdited(c.id, filepath.Join(folder, "evil"+string(rune(0x202e))+"gp.go")) // nor a bidi mark
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "Carry on"}, SendQueue))
	idle(t, c)
	agent.mu.Lock()
	sent := agent.prompt
	agent.mu.Unlock()
	a, b := `<nushi-edited path="a.go"/>`, `<nushi-edited path="docs/b.md"/>`
	if len(sent) != 3 || sent[0].Text.Text != a || sent[1].Text.Text != b || sent[2].Text.Text != "Carry on" {
		t.Fatalf("sent %+v", sent)
	}
	if text, ok := unnoted(a + "\n\n" + b + "\n\nCarry on"); !ok || text != "Carry on" {
		t.Errorf("replayed as %q", text)
	}
	one := editNote("/Users/me/.claude/plans/plan.md")
	if text, ok := unnoted(one + "go on"); !ok || text != "go on" {
		t.Errorf("one file's note replayed as %q", text)
	}
	// Told once.
	testcheck.NoErr(t, svc.Prompt(t.Context(), c.id, model.Message{Text: "Again"}, SendQueue))
	idle(t, c)
	agent.mu.Lock()
	sent = agent.prompt
	agent.mu.Unlock()
	if len(sent) != 1 || sent[0].Text.Text != "Again" {
		t.Errorf("the second prompt sent %+v", sent)
	}
}

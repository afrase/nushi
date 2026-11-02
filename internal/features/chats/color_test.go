package chats

import (
	"errors"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestSetColor(t *testing.T) {
	svc := newService(t, []Kind{{Harness: testHarness{Name: "claude", Title: "Claude"}, Launch: (&fakeAgent{}).launch}}, Options{Scratch: t.TempDir()})
	id, err := svc.Start(t.Context(), "", t.TempDir(), false)
	testcheck.NoErr(t, err)
	c := svc.chats[id]
	saved := func() string {
		t.Helper()
		c.mu.Lock()
		defer c.mu.Unlock()
		return c.record.Color
	}

	for _, name := range chatColors {
		testcheck.NoErr(t, svc.SetColor(c.id, name))
		if got := saved(); got != name {
			t.Errorf("stored %q, want %q", got, name)
		}
	}

	// What isn't one of the eight never reaches the record.
	for _, name := range []string{"Amber", "#ff0000", " amber", "../amber", "red"} {
		if err := svc.SetColor(c.id, name); !errors.Is(err, ErrColor) {
			t.Errorf("SetColor(%q) = %v, want ErrColor", name, err)
		}
	}
	if got := saved(); got != "green" {
		t.Errorf("a refused name changed the color to %q", got)
	}

	testcheck.NoErr(t, svc.SetColor(c.id, ""))
	if got := saved(); got != "" {
		t.Errorf("cleared, stored %q", got)
	}

	if err := svc.SetColor("nope", "amber"); err == nil || errors.Is(err, ErrColor) {
		t.Errorf("an unknown chat = %v, want its own error", err)
	}
}

// A fork keeps its chat's color, and so does a side chat kept as a chat; a
// side chat itself isn't listed, so it takes none.
func TestForkKeepsColor(t *testing.T) {
	svc, agent, c, _, _ := newCopyingChat(t)
	ctx := t.Context()
	testcheck.NoErr(t, svc.SetColor(c.id, "rust"))
	agent.updates = []acp.SessionUpdate{chunk("m1", "ok")}
	testcheck.NoErr(t, svc.Prompt(ctx, c.id, model.Message{Text: "one"}, SendIdle))
	eventually(t, c, func() bool { return !c.busy })

	id, err := svc.ForkAsChat(ctx, c.id, "")
	testcheck.NoErr(t, err)
	if got := svc.chats[id].record.Color; got != "rust" {
		t.Errorf("the fork's color = %q", got)
	}

	side, err := svc.Fork(ctx, c.id)
	testcheck.NoErr(t, err)
	if err := svc.SetColor(side, "teal"); err == nil {
		t.Error("a side chat took a color")
	}
	kept, err := svc.KeepSide(ctx, side)
	testcheck.NoErr(t, err)
	if got := svc.chats[kept].record.Color; got != "rust" {
		t.Errorf("the kept side chat's color = %q", got)
	}
}

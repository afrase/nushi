package pi

import (
	"context"
	"io"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/pi/pitest"
)

// A chat's pi that dies while a side chat is open on the same bridge
// (side chats share the chat's agent) leaves the bridge running for the
// side chat, so the chat's session opens again on its file at its next
// prompt, also once the side chat has closed. Before, every later prompt
// of the chat failed as "no open session", for good.
func TestADeadSessionOpensAgainBesideAnother(t *testing.T) {
	store := &pitest.Store{Sessions: t.TempDir(), Waiting: make(chan string, 1)}
	c := start(t, store, io.Discard)
	cwd := t.TempDir()
	main := openNew(t, c, cwd)
	side := openNew(t, c, cwd)
	ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
	defer cancel()
	deaf := func(n int) { // a turn on main whose pi, the nth, dies in it
		t.Helper()
		w, err := c.StartPrompt(ctx, &acp.PromptRequest{SessionID: main.SessionID, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "deaf"}}}})
		if err != nil {
			t.Fatal(err)
		}
		next(ctx, t, store.Waiting, "the deaf turn's wait")
		c.killPi(n)
		if r, err := w(ctx); err == nil { // its answer comes once the bridge has handled the death
			t.Errorf("the turn its pi died in: %+v; want an error", r)
		}
	}
	deaf(0)
	if r := prompt(t, c, main.SessionID, "hello"); r.StopReason != "end_turn" {
		t.Errorf("the chat's next prompt: %+v", r)
	}
	deaf(2) // the pi it opened again (the side chat's is the 1st)
	if _, err := c.CloseSession(ctx, &acp.CloseSessionRequest{SessionID: side.SessionID}); err != nil {
		t.Fatal(err)
	}
	if r := prompt(t, c, main.SessionID, "again"); r.StopReason != "end_turn" {
		t.Errorf("the chat's prompt after the side chat closed: %+v", r)
	}
	if texts := c.texts(main.SessionID); len(texts) == 0 || !strings.HasSuffix(texts[len(texts)-1], ":You said: again") {
		t.Errorf("the chat's texts: %q", texts)
	}
}

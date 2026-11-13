package pi

import (
	"context"
	"io"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/pi/pitest"
)

// pi dying mid-turn, with a prompt sent behind that turn: the turn fails
// saying the agent stopped, the prompt fails too (the agent stopped, if it
// was waiting in the bridge, or no open session, if it came after the
// session went), neither hangs, and a new session starts on a new pi.
func TestPiDiesMidTurn(t *testing.T) {
	store := &pitest.Store{Sessions: t.TempDir(), Waiting: make(chan string, 1)}
	c, die := startDying(t, store, io.Discard)
	s := openNew(t, c, t.TempDir())
	ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
	defer cancel()
	ask := func(text string) func(context.Context) (*acp.PromptResponse, error) {
		t.Helper()
		w, err := c.StartPrompt(ctx, &acp.PromptRequest{SessionID: s.SessionID, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: text}}}})
		if err != nil {
			t.Fatal(err)
		}
		return w
	}
	turn := ask("wait")
	<-store.Waiting
	queued := ask("and then this")
	die()
	stopped := func(err error) bool { return err != nil && strings.Contains(err.Error(), errStopped.Error()) }
	if r, err := turn(ctx); !stopped(err) {
		t.Errorf("the turn: %+v, %v; want %q", r, err, errStopped)
	}
	if r, err := queued(ctx); !stopped(err) && (err == nil || !strings.Contains(err.Error(), "no open session")) {
		t.Errorf("the prompt behind it: %+v, %v; want %q", r, err, errStopped)
	}
	s2 := openNew(t, c, t.TempDir())
	if r := prompt(t, c, s2.SessionID, "hello"); r.StopReason != "end_turn" {
		t.Errorf("a new session: %+v", r)
	}
}

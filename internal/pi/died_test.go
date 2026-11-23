package pi

import (
	"context"
	"io"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/pi/pitest"
)

// pi dying mid-turn, with a prompt sent behind that turn: the turn fails
// saying the agent stopped, the prompt fails too (the agent stopped, or
// the connection closed), neither hangs, and the bridge ends its
// connection, as its last session's pi is gone: the client sees the agent
// quit and opens the chat again on a new bridge, where before every later
// prompt failed as "no open session" on a bridge that lived on.
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
	if r, err := turn(ctx); err == nil {
		t.Errorf("the turn: %+v; want an error", r)
	}
	if r, err := queued(ctx); err == nil {
		t.Errorf("the prompt behind it: %+v; want an error", r)
	}
	ended(ctx, t, c)
}

// A pi that answers no Stop (PiG 0.5.3 after /sprite, docs/facts/pig.md)
// is killed once its abort has waited abortWait: the turn ends and the
// bridge, its last pi gone, ends its connection. Before, the turn ran on
// for good and the chat stayed busy.
func TestPiThatIgnoresAStopIsKilled(t *testing.T) {
	was := abortWait
	abortWait = 50 * time.Millisecond
	t.Cleanup(func() { abortWait = was })
	store := &pitest.Store{Sessions: t.TempDir(), Waiting: make(chan string, 1)}
	c := start(t, store, io.Discard)
	s := openNew(t, c, t.TempDir())
	ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
	defer cancel()
	w, err := c.StartPrompt(ctx, &acp.PromptRequest{SessionID: s.SessionID, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "deaf"}}}})
	if err != nil {
		t.Fatal(err)
	}
	next(ctx, t, store.Waiting, "the deaf run's wait")
	if err := c.Cancel(ctx, &acp.CancelNotification{SessionID: s.SessionID}); err != nil {
		t.Fatal(err)
	}
	if r, err := w(ctx); err == nil && r.StopReason != "cancelled" || ctx.Err() != nil {
		t.Errorf("the stopped turn: %+v, %v; want it ended", r, err)
	}
	ended(ctx, t, c)
}

// ended waits for the bridge to end the client's connection.
func ended(ctx context.Context, t *testing.T, c *peer) {
	t.Helper()
	select {
	case <-c.Done():
	case <-ctx.Done():
		t.Fatal("the bridge kept its connection with no pi left")
	}
}

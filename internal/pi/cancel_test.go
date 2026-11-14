package pi

import (
	"context"
	"io"
	"testing"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/pi/pitest"
)

// A session/cancel sent right after a session/prompt cancels it, however
// soon after: acp-go starts the prompt's handler first, but the cancel's
// runs beside it, before the turn may be registered or its prompt written
// to pi (acp.SequenceFromContext orders the two). Each round's "wait"
// would run until an abort pi never got.
func TestCancelRightAfterPrompt(t *testing.T) {
	store := &pitest.Store{Sessions: t.TempDir()}
	cancelRounds(t, store, 30, nil)
}

// A Stop that reaches pi before pi has taken the prompt it follows (pi
// handles each command as it reads it, and a prompt sets up before its
// run) still stops it: the abort waits for pi's answer to the prompt, so
// it finds the run. Before, pi answered the abort at once, the bridge let
// the session go, and the next round's prompt was refused as "already
// processing" while the stopped one ran on.
func TestCancelBeforePiTakesThePrompt(t *testing.T) {
	store := &pitest.Store{Sessions: t.TempDir(), PromptLag: 20 * time.Millisecond, Read: make(chan string)}
	cancelRounds(t, store, 5, func(ctx context.Context) { next(ctx, t, store.Read, "pi's read of the prompt") })
}

// cancelRounds runs rounds of a "wait" prompt and a Stop sent right
// after it (once read says the moment has come, if given), each answered
// cancelled, then a prompt that runs.
func cancelRounds(t *testing.T, store *pitest.Store, rounds int, read func(context.Context)) {
	t.Helper()
	c := start(t, store, io.Discard)
	s := openNew(t, c, t.TempDir())
	for i := range rounds {
		ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
		w, err := c.StartPrompt(ctx, &acp.PromptRequest{SessionID: s.SessionID, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "wait"}}}})
		if err != nil {
			t.Fatal(err)
		}
		if read != nil {
			read(ctx)
		}
		if err := c.Cancel(context.Background(), &acp.CancelNotification{SessionID: s.SessionID}); err != nil {
			t.Fatal(err)
		}
		r, err := w(ctx)
		cancel()
		if err != nil || r.StopReason != "cancelled" {
			t.Fatalf("round %d: %+v, %v; want cancelled", i, r, err)
		}
	}
	if read != nil {
		go func() { <-store.Read }() // the last prompt's
	}
	if r := prompt(t, c, s.SessionID, "hello"); r.StopReason != "end_turn" {
		t.Errorf("the next prompt: %+v", r)
	}
}

package ante

import (
	"context"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/ante/antetest"
)

// A session/cancel sent right after a session/prompt cancels it, however
// soon after: acp-go starts the prompt's handler first, but the cancel's
// runs beside it, before the turn may be registered or its op written to
// the host (acp.SequenceFromContext orders the two). Each round's "wait"
// would otherwise run on, its Interrupt gone before it; the next prompt
// then runs.
func TestCancelRightAfterPrompt(t *testing.T) {
	c := start(t, &antetest.Store{Home: t.TempDir()})
	s, err := c.NewSession(context.Background(), &acp.NewSessionRequest{Cwd: "/work"})
	if err != nil {
		t.Fatal(err)
	}
	for i := range 30 {
		ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
		w, err := c.StartPrompt(ctx, &acp.PromptRequest{SessionID: s.SessionID, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "wait"}}}})
		if err != nil {
			t.Fatal(err)
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
	if r := prompt(t, c, s.SessionID, "hello"); r.StopReason != "end_turn" {
		t.Errorf("the next prompt: %+v", r)
	}
}

// A Stop that finds nothing to stop (its prompt's turn ended, or hasn't
// begun: next cancels that) sends Ante nothing, and one that comes before
// a later prompt never stops that prompt's turn. It used to send an
// Interrupt anyway, which nothing ordered with the next prompt's input:
// one that went late stopped the next turn, as Pi's bridge once found
// (internal/pi's TestStopWithNothingToStop).
func TestStopWithNothingToStop(t *testing.T) {
	store := &antetest.Store{Home: t.TempDir(), Waiting: make(chan string, 1)}
	c := start(t, store)
	s, err := c.NewSession(context.Background(), &acp.NewSessionRequest{Cwd: "/work"})
	if err != nil {
		t.Fatal(err)
	}
	prompt(t, c, s.SessionID, "hello")
	if err := c.Cancel(context.Background(), &acp.CancelNotification{SessionID: s.SessionID}); err != nil {
		t.Fatal(err)
	}
	wait := begin(t, c, store, s.SessionID, "wait")
	if ok, err := c.Steer(t.Context(), s.SessionID, []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "go on"}}}); !ok || err != nil {
		t.Fatalf("steer = %v, %v", ok, err)
	}
	if r := wait(); r.StopReason != "end_turn" {
		t.Errorf("the next prompt: %+v", r)
	}
	if n := store.Interrupts(); n != 0 {
		t.Errorf("a Stop with nothing to stop sent %d Interrupts", n)
	}
}

// A steer while /compact runs (a turn Ante runs no model in, so nothing
// takes a steer) is refused as PromptRequired, so the client sends it as
// the next prompt; it used to be Injected and lost.
func TestSteerDuringCompact(t *testing.T) {
	store := &antetest.Store{Home: t.TempDir(), Waiting: make(chan string, 1)}
	c := start(t, store)
	s, err := c.NewSession(context.Background(), &acp.NewSessionRequest{Cwd: "/work"})
	if err != nil {
		t.Fatal(err)
	}
	prompt(t, c, s.SessionID, "hello")
	compact := begin(t, c, store, s.SessionID, "/compact wait")
	if ok, err := c.Steer(t.Context(), s.SessionID, []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: "go on"}}}); ok || err != nil {
		t.Errorf("steer = %v, %v; want PromptRequired", ok, err)
	}
	if err := c.Cancel(context.Background(), &acp.CancelNotification{SessionID: s.SessionID}); err != nil {
		t.Fatal(err)
	}
	compact()
}

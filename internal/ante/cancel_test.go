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

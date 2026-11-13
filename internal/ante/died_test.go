package ante

import (
	"context"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/ante/antetest"
)

// Ante's host dying mid-turn, with a prompt sent behind that turn: the
// turn fails saying the host stopped, the prompt fails too (the host
// stopped, if it was waiting in the bridge, or no open session, if it came
// after the session went), neither hangs, and a new session starts on a
// new host. (acp-go's connection can't run in a synctest bubble, which
// would say when the prompt waits.)
func TestHostDiesMidTurn(t *testing.T) {
	store := &antetest.Store{Home: t.TempDir(), Waiting: make(chan string, 1)}
	c, die := startDying(t, store)
	s, err := c.NewSession(t.Context(), &acp.NewSessionRequest{Cwd: "/work"})
	if err != nil {
		t.Fatal(err)
	}
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
	stopped := func(err error) bool {
		return err != nil && strings.Contains(err.Error(), "Ante's host") && strings.Contains(err.Error(), "stopped")
	}
	if r, err := turn(ctx); !stopped(err) {
		t.Errorf("the turn: %+v, %v; want the host stopped", r, err)
	}
	if r, err := queued(ctx); !stopped(err) && (err == nil || !strings.Contains(err.Error(), "no open session")) {
		t.Errorf("the prompt behind it: %+v, %v; want the host stopped", r, err)
	}
	s2, err := c.NewSession(t.Context(), &acp.NewSessionRequest{Cwd: "/work"})
	if err != nil {
		t.Fatal(err)
	}
	if r := prompt(t, c, s2.SessionID, "hello"); r.StopReason != "end_turn" {
		t.Errorf("a new session: %+v", r)
	}
}

package ante

import (
	"context"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/ante/antetest"
)

// A turn Ante ends Failed fails the prompt with Ante's headline and
// details, and the sign-in hint when it's an expired sign-in; an input
// Ante refuses fails with Ante's words. Either way the session takes the
// next prompt.
func TestFailedTurns(t *testing.T) {
	c := start(t, &antetest.Store{Home: t.TempDir()})
	s, err := c.NewSession(t.Context(), &acp.NewSessionRequest{Cwd: "/work"})
	if err != nil {
		t.Fatal(err)
	}
	for text, want := range map[string]string{
		"please fail":   "Not signed in: the token expired (run `ante auth login` in a terminal)",
		"refuse this":   "input refused: the session is busy compacting",
		"fail it again": "Not signed in: the token expired (run `ante auth login` in a terminal)",
	} {
		ctx, cancel := context.WithTimeout(t.Context(), turnTimeout)
		_, err := c.Prompt(ctx, &acp.PromptRequest{SessionID: s.SessionID, Prompt: []acp.ContentBlock{{Type: "text", Text: &acp.TextContent{Text: text}}}})
		cancel()
		if err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("%q: %v, want %q", text, err, want)
		}
		if r := prompt(t, c, s.SessionID, "hello"); r.StopReason != "end_turn" {
			t.Errorf("after %q: %+v", text, r)
		}
	}
}

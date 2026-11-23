package pi

import (
	"context"
	"strings"
	"testing"
)

// The Context widget names the agent the chat runs: PiG's chats say PiG,
// as they share Pi's bridge (ADR 0078).
func TestContextNamesTheFlavor(t *testing.T) {
	call := func(_ context.Context, _ string, _, result any) error {
		result.(*stats).AssistantMessages = 3 // Context asks for its stats
		return nil
	}
	for _, f := range []Flavor{Pi, PiG} {
		u, err := Harness{f}.Context(t.Context(), call, "s1")
		if want := "3 from " + f.Title + "\n"; err != nil || !strings.Contains(u.Markdown, want) {
			t.Errorf("%s: %q, %v", f.Name, u.Markdown, err)
		}
	}
}

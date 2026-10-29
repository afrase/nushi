package knownagents

import (
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/features/chats"
)

// Each agent is whole: named once, its chats named and titled as it is,
// started, with its skills and trust; Claude first; what reads this Mac
// only in Local.
func TestEveryAgentIsWhole(t *testing.T) {
	all := All(t.TempDir())
	var names []string
	for _, a := range all {
		n := a.Agent.Name
		names = append(names, n)
		if a.Chats.Name != n || a.Chats.Title != a.Agent.Title || a.Agent.Title == "" {
			t.Errorf("%s: chats %q %q, agent %q", n, a.Chats.Name, a.Chats.Title, a.Agent.Title)
		}
		if a.Start == nil || a.Skills == nil || a.Trust == nil || a.Chats.Resume == "" {
			t.Errorf("%s isn't whole: %+v", n, a)
		}
		if a.Chats.MCP != (a.MCP != nil) {
			t.Errorf("%s: Chats.MCP %v with MCP %v", n, a.Chats.MCP, a.MCP != nil)
		}
		if k := a.Chats; k.Launch != nil || k.Explain != nil || k.Ready != nil || k.OpenElsewhere != nil || k.Forked != nil || k.HistoryGone != nil {
			t.Errorf("%s: Chats has what main or Local adds", n)
		}
		if a.Local != nil {
			var k chats.Kind
			a.Local(&k)
			if k.OpenElsewhere == nil && k.Forked == nil && k.HistoryGone == nil {
				t.Errorf("%s: Local adds nothing", n)
			}
		}
	}
	if !slices.Equal(names, []string{"claude", "codex", "ante", "omp", "pig"}) {
		t.Errorf("agents %v", names)
	}
}

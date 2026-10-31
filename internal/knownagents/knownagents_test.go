package knownagents

import (
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/features/chats"
)

// Each agent is whole: named once, its chats named and titled as it is,
// started, with its skills and trust; Claude first; what reads this Mac
// only in Local.
func TestEveryAgentIsWhole(t *testing.T) {
	all := All(t.TempDir(), func() bool { return false })
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
		if takes := n == "claude" || n == "codex"; a.Chats.ClientMCP != takes {
			t.Errorf("%s: Chats.ClientMCP %v, want %v (ADR 0043)", n, a.Chats.ClientMCP, takes)
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

// Claude runs through the adapter unless the setting, or the daemon's
// environment (a dev override), says Nushi's Go agent, asked each time.
func TestClaudesAgentIsTheAdapterUnlessToldGo(t *testing.T) {
	for _, tc := range []struct {
		env     string
		setting bool
		goes    bool
	}{{"", false, false}, {"node", false, false}, {"Go", false, false}, {"go", false, true}, {"", true, true}, {"node", true, true}} {
		t.Setenv(claude.AdapterChoice, tc.env)
		setting := tc.setting
		c := All(t.TempDir(), func() bool { return setting })[0]
		if c.Agent.Adapter == nil || len(c.Agent.Tested) == 0 || c.Start == nil {
			t.Fatalf("Claude without its adapter: %+v", c.Agent)
		}
		if got := c.Agent.Own(); got != tc.goes {
			t.Errorf("env %q, setting %v: own %v", tc.env, tc.setting, got)
		}
		setting = !setting
		if got := c.Agent.Own(); tc.env != "go" && got == tc.goes {
			t.Errorf("env %q: the setting's change wasn't seen", tc.env)
		}
	}
}

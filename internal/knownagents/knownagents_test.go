package knownagents

import (
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/claude"
	"github.com/afrase/nushi/internal/features/chats"
)

// Each agent is whole: named once, its setup named and titled as its
// harness, with its skills and trust; Claude first.
func TestEveryAgentIsWhole(t *testing.T) {
	all := All(t.TempDir(), func() bool { return false })
	var names []string
	for _, a := range all {
		info, n := a.Harness.Info(), a.Agent.Name
		names = append(names, n)
		if info.Name != n || info.Title != a.Agent.Title || a.Agent.Title == "" || a.Local.Info() != info {
			t.Errorf("%s: harness %q %q, agent %q", n, info.Name, info.Title, a.Agent.Title)
		}
		if a.Skills == nil || a.Trust == nil || info.Resume == "" {
			t.Errorf("%s isn't whole: %+v", n, a)
		}
		if takes := n == "claude" || n == "codex"; info.ClientMCP != takes {
			t.Errorf("%s: ClientMCP %v, want %v (ADR 0043)", n, info.ClientMCP, takes)
		}
	}
	if !slices.Equal(names, []string{"claude", "codex", "ante", "omp", "pig"}) {
		t.Errorf("agents %v", names)
	}
}

// capabilities are the harness interfaces, by name.
var capabilities = map[string]func(chats.Harness) bool{
	"Meta": has[chats.Meta], "Forker": has[chats.Forker], "ToolReader": has[chats.ToolReader],
	"OtherReader": has[chats.OtherReader], "DefaultReader": has[chats.DefaultReader], "Transcript": has[chats.Transcript],
	"Subagents": has[chats.Subagents], "BackgroundTasks": has[chats.BackgroundTasks], "ContextCommander": has[chats.ContextCommander],
	"ContextAsker": has[chats.ContextAsker], "GoneReader": has[chats.GoneReader], "HistoryCopier": has[chats.HistoryCopier],
	"OpenFinder": has[chats.OpenFinder], "ForkFinder": has[chats.ForkFinder], "HistoryChecker": has[chats.HistoryChecker], "MessageDater": has[chats.MessageDater],
}

func has[T any](h chats.Harness) bool { _, ok := h.(T); return ok }

// listed is what h can do, sorted.
func listed(h chats.Harness) []string {
	out := []string{}
	for name, can := range capabilities {
		if can(h) {
			out = append(out, name)
		}
	}
	slices.Sort(out)
	return out
}

// Each harness has what capabilities.go says and nothing more (which the
// compiler can't check), and what reads this Mac is only in Local: the e2e
// tests run Harness, so they can never read the owner's files.
func TestEachHarnessHasWhatItHasAndNoMore(t *testing.T) {
	want := map[string]struct{ harness, local []string }{
		"claude": {[]string{"BackgroundTasks", "ContextCommander", "DefaultReader", "Forker", "GoneReader", "Meta", "OtherReader", "Subagents", "ToolReader", "Transcript"},
			[]string{"ForkFinder", "HistoryChecker", "HistoryCopier", "MessageDater", "OpenFinder"}},
		"codex": {[]string{"Forker", "GoneReader", "HistoryCopier", "OtherReader", "ToolReader"}, []string{"ForkFinder", "OpenFinder"}},
		"ante":  {[]string{"ContextAsker", "Forker", "OtherReader"}, []string{"MessageDater", "OpenFinder"}},
		"omp":   {[]string{"OtherReader", "ToolReader"}, []string{"ForkFinder", "OpenFinder"}},
		"pig":   {[]string{"ContextAsker", "Forker", "GoneReader"}, nil},
	}
	for _, a := range All("", func() bool { return false }) {
		w := want[a.Agent.Name]
		if got := listed(a.Harness); !slices.Equal(got, w.harness) {
			t.Errorf("%s has %v, want %v", a.Agent.Name, got, w.harness)
		}
		local := slices.Sorted(slices.Values(append(slices.Clone(w.harness), w.local...)))
		if got := listed(a.Local); !slices.Equal(got, local) {
			t.Errorf("%s's Local has %v, want %v", a.Agent.Name, got, local)
		}
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
		if c.Agent.Adapter == nil || len(c.Agent.Tested) == 0 {
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

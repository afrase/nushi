package knownagents

import (
	"go/ast"
	"go/parser"
	"go/token"
	"reflect"
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/skills"
)

// Each agent is whole: named once, its setup named and titled as its
// harness, with its skills and trust; Claude first.
func TestEveryAgentIsWhole(t *testing.T) {
	all := All(t.TempDir())
	var names []string
	for _, a := range all {
		info, n := a.Harness.Info(), a.Agent.Name
		names = append(names, n)
		if info.Name != n || info.Title != a.Agent.Title || a.Agent.Title == "" || !reflect.DeepEqual(a.Local.Info(), info) {
			t.Errorf("%s: harness %q %q, agent %q", n, info.Name, info.Title, a.Agent.Title)
		}
		if a.Skills == nil || a.Trust == nil || info.Resume == "" {
			t.Errorf("%s isn't whole: %+v", n, a)
		}
		if takes := n == "claude" || n == "codex"; info.ClientMCP != takes {
			t.Errorf("%s: ClientMCP %v, want %v (ADR 0043)", n, info.ClientMCP, takes)
		}
		if moves := n == "claude" || n == "codex"; info.Moves != moves {
			t.Errorf("%s: Moves %v, want %v (ADR 0014)", n, info.Moves, moves)
		}
		// Claude's has all three; opencode's initialize alone asks for
		// its subagents' updates.
		claudes := n == "claude"
		if (info.InitMeta != nil) != (claudes || n == "opencode") || (info.SessionMeta != nil) != claudes || (info.UltracodeMeta != nil) != claudes {
			t.Errorf("%s: _meta %v, %v, %v, only Claude's and opencode's initialize has any", n, info.InitMeta, info.SessionMeta, info.UltracodeMeta)
		}
	}
	if !slices.Equal(names, []string{"claude", "codex", "ante", "omp", "opencode", "pi", "pig"}) {
		t.Errorf("agents %v", names)
	}
}

// capabilities are the harness interfaces, by name.
var capabilities = map[string]func(chats.Harness) bool{
	"Forker": has[chats.Forker], "ToolReader": has[chats.ToolReader],
	"OtherReader": has[chats.OtherReader], "DefaultReader": has[chats.DefaultReader], "Transcript": has[chats.Transcript],
	"Subagents": has[chats.Subagents], "SubagentMessages": has[chats.SubagentMessages], "BackgroundTasks": has[chats.BackgroundTasks], "ContextCommander": has[chats.ContextCommander], "ReadOnly": has[chats.ReadOnly],
	"ContextAsker": has[chats.ContextAsker], "GoneReader": has[chats.GoneReader],
	"OpenFinder": has[chats.OpenFinder], "ForkFinder": has[chats.ForkFinder], "HistoryChecker": has[chats.HistoryChecker], "MessageDater": has[chats.MessageDater],
	"TitleMaker": has[chats.TitleMaker], "TerminalCommands": has[chats.TerminalCommands], "WorktreeFinder": has[chats.WorktreeFinder],
	"SessionSearcher": has[chats.SessionSearcher], "CommandHider": has[chats.CommandHider],
}

// Every capability chats declares is in capabilities, so a harness can't
// gain one unchecked.
func TestCapabilitiesAreChats(t *testing.T) {
	f, err := parser.ParseFile(token.NewFileSet(), "../features/chats/harness.go", nil, parser.SkipObjectResolution)
	if err != nil {
		t.Fatal(err)
	}
	for _, d := range f.Decls {
		for _, spec := range d.(*ast.GenDecl).Specs {
			if ts, ok := spec.(*ast.TypeSpec); ok && ts.Name.Name != "Harness" && capabilities[ts.Name.Name] == nil {
				t.Errorf("chats.%s isn't in capabilities", ts.Name.Name)
			}
		}
	}
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
		"claude": {[]string{"BackgroundTasks", "ContextCommander", "DefaultReader", "Forker", "GoneReader", "OtherReader", "ReadOnly", "SubagentMessages", "Subagents", "TerminalCommands", "TitleMaker", "ToolReader", "Transcript"},
			[]string{"ForkFinder", "HistoryChecker", "MessageDater", "OpenFinder", "SessionSearcher", "WorktreeFinder"}},
		"codex":    {[]string{"Forker", "GoneReader", "OtherReader", "ReadOnly", "ToolReader"}, []string{"ForkFinder", "OpenFinder", "SessionSearcher"}},
		"ante":     {[]string{"ContextAsker", "Forker", "OtherReader", "Subagents", "ToolReader"}, []string{"MessageDater", "OpenFinder"}},
		"omp":      {[]string{"OtherReader", "ToolReader"}, []string{"ForkFinder", "OpenFinder"}},
		"opencode": {[]string{"CommandHider", "GoneReader", "OtherReader"}, nil},
		"pi":       {[]string{"ContextAsker", "Forker", "GoneReader"}, nil},
		"pig":      {[]string{"ContextAsker", "Forker", "GoneReader"}, nil},
	}
	for _, a := range All("") {
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

// What the app goes by instead of an agent's name is each agent's own:
// Claude's built-in skills, plugins and links, and Ante's plain MCP
// servers.
func TestWhatTheAppShowsIsOneAgentsAlone(t *testing.T) {
	for _, a := range All("") {
		claudes := a.Agent.Name == "claude"
		_, builtIn := a.Skills.(skills.BuiltIn)
		_, plugins := a.Skills.(skills.Plugins)
		_, linker := a.Skills.(skills.Linker)
		if builtIn != claudes || plugins != claudes || linker != claudes {
			t.Errorf("%s: built in %v, plugins %v, links %v", a.Agent.Name, builtIn, plugins, linker)
		}
		if a.MCP != nil {
			if got, want := a.MCP(nil).UserOnly(), a.Agent.Name == "ante"; got != want {
				t.Errorf("%s: user only: %v", a.Agent.Name, got)
			}
		}
	}
}

// Claude runs through Nushi's Go agent: no adapter to set up, so no Node,
// and no CLI version pinned (ADR 0066).
func TestClaudeHasNoAdapter(t *testing.T) {
	c := All(t.TempDir())[0]
	if c.Agent.Name != "claude" || c.Agent.Adapter != nil || len(c.Agent.Tested) != 0 {
		t.Errorf("Claude: %+v", c.Agent)
	}
}

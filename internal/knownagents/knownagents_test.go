package knownagents

import (
	"context"
	"encoding/json"
	"go/ast"
	"go/parser"
	"go/token"
	"io/fs"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/skills"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/testcheck"
)

// nushisCalls are a call of Nushi's own tool as each agent that is given
// them sends it, in every shape chats hands its harness: the call with its
// _meta and input, and with its title alone (a later update, an ask for a
// call not seen, a copy saved before the server and tool were kept). %s is
// the tool. An agent given Nushi's tools has its row here.
var nushisCalls = map[string][]struct {
	title string
	meta  string // JSON, "" for none
	input string // JSON, "" for none
	kind  string
}{
	"claude": {
		{title: "mcp__nushi__%s", meta: `{"claudeCode":{"toolName":"mcp__nushi__%s"}}`, input: `{"path":"a.html","name":"web"}`, kind: "other"},
		{title: "mcp__nushi__%s"},
	},
	"codex": {
		{title: "mcp.nushi.%s", meta: `{"is_mcp_tool_call":true}`, input: `{"server":"nushi","tool":"%s","arguments":{"path":"a.html","name":"web"}}`, kind: "execute"},
		{title: "mcp.nushi.%s", kind: "execute"},
		{title: "mcp.nushi.%s"},
	},
}

// An agent that is given Nushi's tools reads its calls of them: chats knows
// a show call, which must never count as the chat having written the file
// it names (ADR 0068), and a dev server's start, only by the server and
// tool the agent's harness reads (chats.ToolReader). So every agent with
// ClientMCP proves here that it reads them, in each shape.
func TestAnAgentGivenNushisToolsReadsItsCalls(t *testing.T) {
	for _, a := range All(t.TempDir(), nil) {
		n := a.Agent.Name
		if !a.Harness.Info().ClientMCP {
			continue
		}
		reader, ok := a.Harness.(chats.ToolReader)
		calls := nushisCalls[n]
		if !ok || len(calls) == 0 {
			t.Errorf("%s is given Nushi's tools: it needs a ToolReader (%v) and its calls' shapes in nushisCalls (%d)", n, ok, len(calls))
			continue
		}
		for _, tool := range []string{"show", "preview_start"} {
			for i, c := range calls {
				it := model.Item{Kind: model.ToolCall, Title: sprintf(c.title, tool), ToolKind: c.kind}
				var meta map[string]any
				if c.meta != "" {
					testcheck.NoErr(t, json.Unmarshal([]byte(sprintf(c.meta, tool)), &meta))
				}
				var input json.RawMessage
				if c.input != "" {
					input = json.RawMessage(sprintf(c.input, tool))
				}
				reader.ToolCall(&it, meta, input)
				if it.MCPServer != chats.ToolsServer || it.MCPTool != tool {
					t.Errorf("%s, %s, shape %d: read as %q, %q", n, tool, i, it.MCPServer, it.MCPTool)
				}
			}
		}
	}
}

// sprintf puts tool in format's %s, if it has one.
func sprintf(format, tool string) string { return strings.ReplaceAll(format, "%s", tool) }

// Each agent is whole: named once, its setup named and titled as its
// harness, with its skills and trust; Claude first.
func TestEveryAgentIsWhole(t *testing.T) {
	all := All(t.TempDir(), nil)
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
		// Only Ante's input takes in the cache's tokens; the rest report
		// theirs without (docs/facts/ante.md, ADR 0136's amendment).
		if holds := n == "ante"; info.CacheInInput != holds {
			t.Errorf("%s: CacheInInput %v, want %v", n, info.CacheInInput, holds)
		}
		if moves := n == "claude" || n == "codex"; info.Moves != moves {
			t.Errorf("%s: Moves %v, want %v (ADR 0014)", n, info.Moves, moves)
		}
		// Claude's sessions have theirs (its subagents' text comes with
		// the subagents capability); opencode's initialize alone asks for
		// its subagents' updates.
		claudes := n == "claude"
		if (info.InitMeta != nil) != (n == "opencode") || (info.SessionMeta != nil) != claudes || (info.UltracodeMeta != nil) != claudes {
			t.Errorf("%s: _meta %v, %v, %v, only Claude's sessions and opencode's initialize have any", n, info.InitMeta, info.SessionMeta, info.UltracodeMeta)
		}
	}
	if !slices.Equal(names, []string{"claude", "codex", "ante", "omp", "opencode", "pi", "pig"}) {
		t.Errorf("agents %v", names)
	}
}

// capabilities are the harness interfaces, by name.
var capabilities = map[string]func(chats.Harness) bool{
	"Forker": has[chats.Forker], "ToolReader": has[chats.ToolReader],
	"DefaultReader": has[chats.DefaultReader], "Transcript": has[chats.Transcript],
	"Subagents": has[chats.Subagents], "SubagentOutput": has[chats.SubagentOutput], "SubagentMessages": has[chats.SubagentMessages], "BackgroundTasks": has[chats.BackgroundTasks], "ReadOnly": has[chats.ReadOnly],
	"ContextAsker": has[chats.ContextAsker], "TaskStopper": has[chats.TaskStopper], "GoneReader": has[chats.GoneReader],
	"OpenFinder": has[chats.OpenFinder], "ForkFinder": has[chats.ForkFinder], "HistoryChecker": has[chats.HistoryChecker], "MessageDater": has[chats.MessageDater], "SentReader": has[chats.SentReader],
	"TitleMaker": has[chats.TitleMaker], "TerminalCommands": has[chats.TerminalCommands], "WorktreeFinder": has[chats.WorktreeFinder],
	"SessionSearcher": has[chats.SessionSearcher], "CommandHider": has[chats.CommandHider], "WorkflowReader": has[chats.WorkflowReader],
	"UsageReader": has[chats.UsageReader], "WorkReader": has[chats.WorkReader],
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
		"claude": {[]string{"BackgroundTasks", "ContextAsker", "DefaultReader", "Forker", "GoneReader", "ReadOnly", "SentReader", "SubagentMessages", "SubagentOutput", "Subagents", "TaskStopper", "TerminalCommands", "TitleMaker", "ToolReader", "Transcript", "UsageReader", "WorkReader"},
			[]string{"ForkFinder", "HistoryChecker", "OpenFinder", "SessionSearcher", "WorkflowReader", "WorktreeFinder"}},
		"codex":    {[]string{"Forker", "GoneReader", "ReadOnly", "ToolReader"}, []string{"ForkFinder", "OpenFinder", "SessionSearcher"}},
		"ante":     {[]string{"ContextAsker", "Forker", "Subagents", "ToolReader"}, []string{"MessageDater", "OpenFinder"}},
		"omp":      {[]string{"ToolReader"}, []string{"ForkFinder", "OpenFinder"}},
		"opencode": {[]string{"CommandHider", "GoneReader"}, nil},
		"pi":       {[]string{"ContextAsker", "Forker", "GoneReader"}, nil},
		"pig":      {[]string{"ContextAsker", "Forker", "GoneReader"}, nil},
	}
	for _, a := range All("", nil) {
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
	for _, a := range All("", nil) {
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
	c := All(t.TempDir(), nil)[0]
	if c.Agent.Name != "claude" || c.Agent.Adapter != nil || len(c.Agent.Tested) != 0 {
		t.Errorf("Claude: %+v", c.Agent)
	}
}

// Codex runs through codex-acp, set up, until the user's setting says the
// Go agent (ADR 0142): then a start has no adapter program, which
// codex.Harness takes for the Go agent, and needs no Node or Set up. The
// setting is asked at each start, so flipping it needs no restart.
func TestCodexFollowsItsGoAgentSetting(t *testing.T) {
	bin := t.TempDir()
	for _, p := range []string{"codex", "node"} {
		testcheck.Write(t, filepath.Join(bin, p), "#!/bin/sh\n")
		testcheck.NoErr(t, os.Chmod(filepath.Join(bin, p), 0o700))
	}
	t.Setenv("PATH", bin)
	on := false
	var found []agents.Agent
	for _, a := range All("", func(name string) bool { return on && name == "codex" }) {
		found = append(found, a.Agent)
	}
	svc := agents.New(found, func(context.Context, string, ...string) ([]byte, error) { return nil, nil }, shellenv.Off(os.Environ()), t.TempDir(), setUp{})
	if r, err := svc.Run("codex"); err != nil || r.Program != "/adapter/codex-acp" || r.Node != filepath.Join(bin, "node") {
		t.Errorf("off: %+v, %v", r, err)
	}
	on = true
	if r, err := svc.Run("codex"); err != nil || r.Program != "" || r.Node != "" || r.CLI != filepath.Join(bin, "codex") {
		t.Errorf("on: %+v, %v", r, err)
	}
	if err := svc.SetUp(context.Background(), "codex"); err == nil {
		t.Error("on: Codex had something to set up")
	}
}

// setUp is an installer whose every adapter is set up, at /adapter.
type setUp struct{}

func (setUp) Install(context.Context, fs.FS, string, func()) error { return nil }
func (setUp) Installed(_, _, bin string) (version, program string) {
	return "1.0.0", "/adapter/" + bin
}
func (setUp) Remove(string) error { return nil }

package e2e

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/mcp"
	"github.com/afrase/nushi/internal/features/skills"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
)

// noExtras is an agent's skills with no built-in ones or plugins.
type noExtras struct{}

func (noExtras) List(context.Context, string) (model.Skills, error) { return model.Skills{}, nil }
func (noExtras) SetSkillOn(context.Context, string, string, string, bool) error {
	return nil
}
func (noExtras) Own(string) (project, yours []string) { return nil, nil }

// fileSkill is an agent's skills with one, a shared skill in one file.
type fileSkill struct{ noExtras }

func (fileSkill) List(context.Context, string) (model.Skills, error) {
	return model.Skills{Skills: []model.Skill{{Name: "notes", Source: "shared", Path: "/r/.agents/skills/notes.md", OneFile: true}}}, nil
}

// builtInPlugins is an agent's skills with both.
type builtInPlugins struct{ noExtras }

func (builtInPlugins) SetBuiltInOn(context.Context, string, bool) error        { return nil }
func (builtInPlugins) SetPluginOn(context.Context, string, string, bool) error { return nil }
func (builtInPlugins) Uninstall(context.Context, string, string) error         { return nil }
func (builtInPlugins) PluginScope(string, model.Plugin) string                 { return "" }

// agentFacts is what testdata/agents.json says of each agent, in the order
// ListAgents lists them: the facts the app's FakeDaemon lists them with.
type agentFacts struct {
	Name          string `json:"name"`
	Title         string `json:"title"`
	McpUserOnly   bool   `json:"mcpUserOnly"`
	GoAgentSwitch bool   `json:"goAgentSwitch"`
	SignIn        string `json:"signIn"`
	Expires       string `json:"expires"`
	Adapter       string `json:"adapter"` // its package; "" for none
}

// What the app asks of an agent instead of going by its name: what
// deletes its sessions (the removed chats' bar), the plain MCP view, from the agents as main lists
// them, and what its skills view shows; and of a skill instead of going
// by its path: that it is one file, and that Delete and Link would refuse
// it. Nothing runs: the probe is fake.
func TestTheAppHearsWhatEachAgentHas(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	data := t.TempDir()
	st := store.New(data)
	all := knownagents.All("", st.GoAgent)
	var kinds []chats.Kind
	var found []agents.Agent
	servers := map[string]*mcp.Service{}
	for _, a := range all {
		kinds = append(kinds, chats.Kind{Harness: a.Harness, MCP: a.MCP != nil})
		found = append(found, a.Agent)
		if a.MCP != nil {
			servers[a.Agent.Name] = mcp.New(a.Agent.Name, a.MCP(nil), nil)
		}
	}
	svc := chats.New(t.Context(), kinds, chats.Options{Remembered: st, Sessions: st, Worktrees: git.Worktrees{}, Scratch: filepath.Join(data, "scratch")})
	agentSvc := agents.New(found, func(context.Context, string, ...string) ([]byte, error) { return nil, nil }, shellenv.Off(os.Environ()), t.TempDir(), setUp{})
	agentSvc.UseChats(svc)
	shown := skills.New([]string{"claude", "codex"}, map[string]skills.Reader{"claude": builtInPlugins{}, "codex": fileSkill{}},
		func(_, _ []string, path string) error { return fmt.Errorf("%s is a file", path) }, nil)
	srv := httptest.NewServer(api.WithToken("tok", api.New(api.Services{Chats: svc, Agents: agentSvc, MCP: servers, Skills: shown, Settings: st})))
	defer srv.Close()
	c := nushiv1connect.NewNushiServiceClient(&http.Client{Transport: bearer{}}, srv.URL)
	ctx := context.Background()

	listed := must(c.ListAgents(ctx, connect.NewRequest(&nushiv1.ListAgentsRequest{}))).Agents
	if len(listed) != len(all) {
		t.Fatalf("%d agents listed, want %d", len(listed), len(all))
	}
	expires := map[string]string{}
	for _, a := range all {
		expires[a.Agent.Name] = a.Harness.Info().Expires
	}
	if expires["claude"] == "" {
		t.Error("Claude's harness says nothing deletes its sessions")
	}
	for _, a := range listed {
		if a.Expires != expires[a.Name] {
			t.Errorf("%s: expires %q, want %q", a.Name, a.Expires, expires[a.Name])
		}
		if want := a.Name == "ante"; a.McpUserOnly != want {
			t.Errorf("%s: mcp_user_only %v, want %v", a.Name, a.McpUserOnly, want)
		}
		if want := a.Name == "codex"; a.GoAgentSwitch != want || (want && a.Adapter == nil) {
			t.Errorf("%s: go_agent_switch %v, want %v; adapter %v", a.Name, a.GoAgentSwitch, want, a.Adapter)
		}
	}
	// The app's FakeDaemon lists the agents from the same facts
	// (app/test/fake_daemon.dart's readyAgents), so they can't drift.
	b, err := os.ReadFile(filepath.Join("testdata", "agents.json"))
	testcheck.NoErr(t, err)
	var facts []agentFacts
	testcheck.NoErr(t, json.Unmarshal(b, &facts))
	var got []agentFacts
	for _, a := range listed {
		got = append(got, agentFacts{Name: a.Name, Title: a.Title, McpUserOnly: a.McpUserOnly, GoAgentSwitch: a.GoAgentSwitch,
			SignIn: a.SignIn, Expires: a.Expires, Adapter: a.GetAdapter().GetPackage()})
	}
	if !slices.Equal(got, facts) {
		t.Errorf("listed agents' facts\n%v\nwant testdata/agents.json's\n%v", got, facts)
	}
	// Codex's Go agent on (Settings, TestCodexGoAgentSetting): Codex is
	// listed with no adapter, its switch still there.
	testcheck.NoErr(t, st.SetGoAgent("codex", true))
	for _, a := range must(c.ListAgents(ctx, connect.NewRequest(&nushiv1.ListAgentsRequest{}))).Agents {
		if a.Name == "codex" && (a.Adapter != nil || !a.GoAgentSwitch) {
			t.Errorf("codex with its Go agent on: %v", a)
		}
	}
	for agent, want := range map[string]bool{"claude": true, "codex": false} {
		r := must(c.ListSkills(ctx, connect.NewRequest(&nushiv1.ListSkillsRequest{Agent: agent, Folder: t.TempDir()})))
		if r.HasBuiltIn != want || r.HasPlugins != want {
			t.Errorf("%s: built in %v, plugins %v, want %v", agent, r.HasBuiltIn, r.HasPlugins, want)
		}
		// The file's place refuses it, and Nushi links nothing for Codex;
		// Claude's fake has no Link either.
		if len(r.Skills) != 1 || !r.Skills[0].OneFile || !r.Skills[0].NoTrash || !r.Skills[0].NoLink {
			t.Errorf("%s: skills %v, want one in one file with no Delete or Link", agent, r.Skills)
		}
	}
}

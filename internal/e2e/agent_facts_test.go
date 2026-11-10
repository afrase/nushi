package e2e

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
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
)

// noExtras is an agent's skills with no built-in ones or plugins.
type noExtras struct{}

func (noExtras) List(context.Context, string) (model.Skills, error) { return model.Skills{}, nil }
func (noExtras) SetSkillOn(context.Context, string, string, string, bool) error {
	return nil
}
func (noExtras) CanTrash(context.Context, string, string) error { return nil }
func (noExtras) Trash(context.Context, string, string) error    { return nil }

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

// What the app asks of an agent instead of going by its name: the plain
// MCP view, from the agents as main lists
// them, and what its skills view shows; and of a skill instead of going
// by its path: that it is one file, and that Delete and Link would refuse
// it. Nothing runs: the probe is fake.
func TestTheAppHearsWhatEachAgentHas(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	all := knownagents.All("")
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
	data := t.TempDir()
	st := store.New(data)
	svc := chats.New(t.Context(), kinds, chats.Options{Remembered: st, Sessions: st, Worktrees: git.Worktrees{}, Scratch: filepath.Join(data, "scratch")})
	agentSvc := agents.New(found, func(context.Context, string, ...string) ([]byte, error) { return nil, nil }, shellenv.Off(os.Environ()), t.TempDir(), setUp{})
	agentSvc.UseChats(svc)
	shown := skills.New([]string{"claude", "codex"}, map[string]skills.Reader{"claude": builtInPlugins{}, "codex": fileSkill{}},
		func(_, _ []string, path string) error { return fmt.Errorf("%s is a file", path) }, nil)
	srv := httptest.NewServer(api.WithToken("tok", api.New(api.Services{Chats: svc, Agents: agentSvc, MCP: servers, Skills: shown, Transcripts: st})))
	defer srv.Close()
	c := nushiv1connect.NewNushiServiceClient(&http.Client{Transport: bearer{}}, srv.URL)
	ctx := context.Background()

	listed := must(c.ListAgents(ctx, connect.NewRequest(&nushiv1.ListAgentsRequest{}))).Agents
	if len(listed) != len(all) {
		t.Fatalf("%d agents listed, want %d", len(listed), len(all))
	}
	for _, a := range listed {
		if want := a.Name == "ante"; a.McpUserOnly != want {
			t.Errorf("%s: mcp_user_only %v, want %v", a.Name, a.McpUserOnly, want)
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

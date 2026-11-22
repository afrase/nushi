package e2e

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/gen/nushi/v1/nushiv1connect"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/testcheck"
)

// The Go agent's setting is kept by agent (go_agents, API 142) for each
// agent with the switch, and an app older than that still reads and sets
// Codex's through codex_go_agent (ADR 0004). An app sends back all it got,
// so each request below carries the other field as it was read: an older
// app go_agents (a field it doesn't know, kept), a newer one
// codex_go_agent. Nothing runs: the probe is fake.
func TestGoAgentsBothWays(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("PATH", t.TempDir()) // no agent is found: only the adapter counts
	data := t.TempDir()
	st := store.New(data)
	var kinds []chats.Kind
	var found []agents.Agent
	for _, a := range knownagents.All("", st.GoAgent) {
		kinds = append(kinds, chats.Kind{Harness: a.Harness})
		found = append(found, a.Agent)
	}
	svc := chats.New(t.Context(), kinds, chats.Options{Remembered: st, Sessions: st, Sleep: st})
	agentSvc := agents.New(found, func(context.Context, string, ...string) ([]byte, error) { return nil, nil }, shellenv.Off(os.Environ()), t.TempDir(), setUp{})
	agentSvc.UseChats(svc)
	srv := httptest.NewServer(api.WithToken("tok", api.New(api.Services{Chats: svc, Agents: agentSvc, GoAgents: st})))
	defer srv.Close()
	c := nushiv1connect.NewNushiServiceClient(&http.Client{Transport: bearer{}}, srv.URL)
	ctx := context.Background()
	get := func() *nushiv1.Settings {
		return must(c.GetSettings(ctx, connect.NewRequest(&nushiv1.GetSettingsRequest{}))).Settings
	}
	set := func(s *nushiv1.Settings) error {
		_, err := c.SetSettings(ctx, connect.NewRequest(&nushiv1.SetSettingsRequest{Settings: s}))
		return err
	}
	codexOn := func() bool {
		for _, a := range must(c.ListAgents(ctx, connect.NewRequest(&nushiv1.ListAgentsRequest{}))).Agents {
			if a.Name == "codex" {
				return a.Adapter == nil
			}
		}
		t.Fatal("codex isn't listed")
		return false
	}

	got := get()
	if len(got.GoAgents) != 1 || got.GoAgents["codex"] || got.CodexGoAgent == nil || got.GetCodexGoAgent() {
		t.Fatalf("by default: %v", got)
	}

	// A newer app turns it on by go_agents, its stale codex_go_agent beside.
	got.GoAgents["codex"] = true
	testcheck.NoErr(t, set(got))
	if got = get(); !got.GoAgents["codex"] || !got.GetCodexGoAgent() || !codexOn() {
		t.Fatalf("on by go_agents: %v", got)
	}

	// An older app turns it off by codex_go_agent, go_agents as it got it.
	off := false
	got.CodexGoAgent = &off
	testcheck.NoErr(t, set(got))
	if got = get(); got.GoAgents["codex"] || got.GetCodexGoAgent() || codexOn() {
		t.Fatalf("off by codex_go_agent: %v", got)
	}

	// An older app that never got go_agents turns it on.
	on := true
	testcheck.NoErr(t, set(&nushiv1.Settings{SleepAfterMinutes: 30, CodexGoAgent: &on}))
	if got = get(); !got.GoAgents["codex"] || !codexOn() {
		t.Fatalf("on by codex_go_agent alone: %v", got)
	}

	// A request with neither leaves it; one naming an agent without the
	// switch is refused, and changes nothing.
	testcheck.NoErr(t, set(&nushiv1.Settings{SleepAfterMinutes: 30}))
	if !get().GoAgents["codex"] {
		t.Error("a request without it turned it off")
	}
	if err := set(&nushiv1.Settings{SleepAfterMinutes: 5, GoAgents: map[string]bool{"claude": true}}); connect.CodeOf(err) != connect.CodeInvalidArgument {
		t.Errorf("claude's Go agent: %v", err)
	}
	if got := get().SleepAfterMinutes; got != 30 {
		t.Errorf("a refused request still set sleep_after_minutes to %d", got)
	}
}

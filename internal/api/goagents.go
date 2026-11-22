package api

import (
	"fmt"
	"log/slog"
	"maps"
	"slices"

	"connectrpc.com/connect"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// GoAgentPref keeps, by agent, whether its chats run through Nushi's Go
// agent rather than its adapter (internal/store; ADR 0142). The agents
// feature reads it each time an agent's chat starts it, so a change needs
// no restart.
type GoAgentPref interface {
	GoAgent(name string) bool
	SetGoAgent(name string, on bool) error
}

// oldGoAgent is the agent Settings.codex_go_agent is for, which an older
// app sends (API 138 to 141; ADR 0004).
const oldGoAgent = "codex"

// goAgents fills set with each agent's Go agent: go_agents for each agent
// that has the switch, and codex_go_agent for an older app.
func (s *server) goAgents(set *nushiv1.Settings) {
	if s.GoAgents == nil {
		return
	}
	on := s.GoAgents.GoAgent(oldGoAgent)
	set.CodexGoAgent = &on
	if s.Agents == nil {
		return
	}
	for _, name := range s.Agents.WithOwn() {
		if set.GoAgents == nil {
			set.GoAgents = map[string]bool{}
		}
		set.GoAgents[name] = s.GoAgents.GoAgent(name)
	}
}

// setGoAgents sets what SetSettings gives of them, where given and
// changed. An app sends back all it got: an older app go_agents as it was
// (a field it doesn't know, kept) beside the codex_go_agent it changed,
// a newer one codex_go_agent as it was beside go_agents. So of the two
// for the same agent, the one that differs from what's set is the change.
// checkGoAgents is checked first.
func (s *server) setGoAgents(set *nushiv1.Settings) error {
	if s.GoAgents == nil {
		return nil
	}
	want := map[string]bool{}
	for _, name := range slices.Sorted(maps.Keys(set.GoAgents)) {
		if on := set.GoAgents[name]; on != s.GoAgents.GoAgent(name) {
			want[name] = on
		}
	}
	if old := set.CodexGoAgent; old != nil && *old != s.GoAgents.GoAgent(oldGoAgent) {
		if _, changed := want[oldGoAgent]; !changed {
			want[oldGoAgent] = *old
		}
	}
	for _, name := range slices.Sorted(maps.Keys(want)) {
		if err := s.GoAgents.SetGoAgent(name, want[name]); err != nil {
			return connect.NewError(connect.CodeInternal, err)
		}
		slog.Info("go agent", "agent", name, "on", want[name])
	}
	return nil
}

// checkGoAgents refuses (InvalidArgument) go_agents naming an agent
// without the switch. SetSettings asks it before setting anything, so a
// refused request changes nothing.
func (s *server) checkGoAgents(set *nushiv1.Settings) error {
	if s.GoAgents == nil || s.Agents == nil {
		return nil
	}
	for name := range set.GetGoAgents() {
		if !slices.Contains(s.Agents.WithOwn(), name) {
			return invalid(fmt.Errorf("%s has no Go agent to switch to", name))
		}
	}
	return nil
}

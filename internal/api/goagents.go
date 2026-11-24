package api

import (
	"fmt"
	"slices"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// oldGoAgent is the agent Settings.codex_go_agent is for, which an older
// app sends (API 138 to 141; ADR 0004): v0.52.0's app on a beta's daemon,
// going back (ADR 0108). Delete after the v0.53.0 tag, with
// codex_go_agent's read below and in setGoAgents.
const oldGoAgent = "codex"

// goAgents fills set with each agent's Go agent: go_agents for each agent
// that has the switch, and codex_go_agent for an older app.
func (s *server) goAgents(set *nushiv1.Settings) {
	on := s.Settings.GoAgent(oldGoAgent)
	set.CodexGoAgent = &on
	for _, name := range s.Agents.WithOwn() {
		if set.GoAgents == nil {
			set.GoAgents = map[string]bool{}
		}
		set.GoAgents[name] = s.Settings.GoAgent(name)
	}
}

// goAgentsChange is what SetSettings gives of them that differs from
// what's set. An app sends back all it got: an older app go_agents as it
// was (a field it doesn't know, kept) beside the codex_go_agent it
// changed, a newer one codex_go_agent as it was beside go_agents. So of
// the two for the same agent, the one that differs from what's set is the
// change. checkGoAgents is checked first.
func (s *server) goAgentsChange(set *nushiv1.Settings) map[string]bool {
	want := map[string]bool{}
	for name, on := range set.GetGoAgents() {
		if on != s.Settings.GoAgent(name) {
			want[name] = on
		}
	}
	if old := set.CodexGoAgent; old != nil && *old != s.Settings.GoAgent(oldGoAgent) {
		if _, changed := want[oldGoAgent]; !changed {
			want[oldGoAgent] = *old
		}
	}
	return want
}

// checkGoAgents refuses (InvalidArgument) go_agents naming an agent
// without the switch. SetSettings asks it before setting anything, so a
// refused request changes nothing.
func (s *server) checkGoAgents(set *nushiv1.Settings) error {
	for name := range set.GetGoAgents() {
		if !slices.Contains(s.Agents.WithOwn(), name) {
			return invalid(fmt.Errorf("%s has no Go agent to switch to", name))
		}
	}
	return nil
}

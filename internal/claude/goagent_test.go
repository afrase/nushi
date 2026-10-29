package claude

import (
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeacp"
)

// Fork-at goes to the adapter and to Nushi's Go agent, which read the same
// extension, and to no other agent.
func TestForkAtIsTheAdaptersAndTheGoAgents(t *testing.T) {
	for _, tc := range []struct {
		info *acp.Implementation
		want bool
	}{
		{&acp.Implementation{Name: AdapterPackage}, true},
		{&acp.Implementation{Name: claudeacp.Name}, true},
		{&acp.Implementation{Name: "@agentclientprotocol/codex-acp"}, false},
		{nil, false},
	} {
		at := ForkAt(&acp.InitializeResponse{AgentInfo: tc.info})
		if (at != nil) != tc.want {
			t.Errorf("%+v: fork-at %v, want %v", tc.info, at != nil, tc.want)
		}
	}
}

// The Go agent is this executable's subcommand, in the daemon's folder,
// with the chat's environment and claude's path as the adapter reads it.
func TestTheGoAgentsCommand(t *testing.T) {
	env := []string{"PATH=/bin", "HOME=/h"}
	cmd := goCommand("/x/nushid", "/data", "/bin/claude", env)
	if !slices.Equal(cmd.Args, []string{"/x/nushid", "claude-acp"}) || cmd.Dir != "/data" {
		t.Errorf("args %q in %q", cmd.Args, cmd.Dir)
	}
	if want := []string{"PATH=/bin", "HOME=/h", "CLAUDE_CODE_EXECUTABLE=/bin/claude"}; !slices.Equal(cmd.Env, want) {
		t.Errorf("env %q", cmd.Env)
	}
	if len(env) != 2 {
		t.Errorf("the chat's environment changed: %q", env)
	}
}

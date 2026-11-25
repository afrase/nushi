package claude

import (
	"os"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/claude-acp-go/claudeacp"
)

// Fork-at goes to whatever agent the harness started: Nushi's Go agent,
// which takes the extension from any client (docs/facts/claude.md), so
// its name isn't asked.
func TestForkAtNeedsNoName(t *testing.T) {
	for _, info := range []*acp.Implementation{{Name: claudeacp.Name}, {Name: "another"}, nil} {
		at := harness.ForkAt(&acp.InitializeResponse{AgentInfo: info})
		if at == nil {
			t.Fatalf("%+v: no fork-at", info)
		}
		air, _ := at("m1")["jetbrains"].(map[string]any)["air"].(map[string]any)
		if fork, _ := air["fork"].(map[string]any); fork["messageId"] != "m1" || fork["version"] != 1 {
			t.Errorf("%+v: fork-at's _meta %v", info, at("m1"))
		}
	}
}

// The Go agent is this executable's subcommand, in the daemon's folder,
// with the chat's environment and claude's path as the agent reads it.
func TestTheGoAgentsCommand(t *testing.T) {
	env := []string{"PATH=/bin", "HOME=/h"}
	cmd, err := goCommand("/data", "/bin/claude", env)
	self, _ := os.Executable()
	if err != nil || !slices.Equal(cmd.Args, []string{self, "claude-acp"}) || cmd.Dir != "/data" {
		t.Errorf("args %q in %q", cmd.Args, cmd.Dir)
	}
	if want := []string{"PATH=/bin", "HOME=/h", "CLAUDE_CODE_EXECUTABLE=/bin/claude"}; !slices.Equal(cmd.Env, want) {
		t.Errorf("env %q", cmd.Env)
	}
	if len(env) != 2 {
		t.Errorf("the chat's environment changed: %q", env)
	}
}

package claude

import (
	"log/slog"
	"os"
	"os/exec"
	"slices"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeacp"
	"github.com/afrase/nushi/internal/agentproc"
)

// AdapterChoice is the daemon's environment variable that picks Claude's
// ACP agent: "go" runs Nushi's own (claudeacp, StartGo), anything else the
// adapter. It is read once, when the daemon builds its agents, so a change
// takes a restart; the adapter stays the default until the Go agent has
// proved itself in use.
const AdapterChoice = "NUSHI_CLAUDE_ADAPTER"

// UsesGo says the daemon runs Claude through Nushi's Go agent.
func UsesGo() bool { return os.Getenv(AdapterChoice) == "go" }

// StartGo starts Nushi's Go agent for Claude, as Start does the adapter:
// this executable's claudeacp.Command, in dir (the daemon's folder) and
// env, running cli, the user's Claude Code. It needs no Node and nothing
// set up. Its stderr goes to log.
func StartGo(dir, cli string, env []string, client acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
	self, err := os.Executable()
	if err != nil {
		return nil, err
	}
	return agentproc.Start(goCommand(self, dir, cli, env), client, log)
}

// goCommand is the Go agent's command, self being this executable. The
// agent reads claude's path from the variable the adapter reads.
func goCommand(self, dir, cli string, env []string) *exec.Cmd {
	cmd := exec.Command(self, claudeacp.Command) //nolint:gosec,noctx // lives until Stop or Close, not a context; this nushid as Claude's agent
	cmd.Dir = dir
	cmd.Env = append(slices.Clone(env), "CLAUDE_CODE_EXECUTABLE="+cli)
	return cmd
}

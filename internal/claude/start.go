package claude

import (
	"log/slog"
	"os"
	"os/exec"
	"slices"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
)

// AgentCommand is the subcommand nushid runs Claude's Go agent under
// (claudeacp.Main): `nushid claude-acp`.
const AgentCommand = "claude-acp"

// startGo starts Nushi's Go agent for Claude: this executable's
// AgentCommand, in dir (the daemon's folder) and env, running cli,
// the user's Claude Code. It needs no Node and nothing set up. Its stderr
// goes to log.
func startGo(dir, cli string, env []string, client acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
	self, err := os.Executable()
	if err != nil {
		return nil, err
	}
	return agentproc.Start(goCommand(self, dir, cli, env), client, log)
}

// goCommand is the Go agent's command, self being this executable. The
// agent reads claude's path from CLAUDE_CODE_EXECUTABLE, as
// claude-agent-acp did.
func goCommand(self, dir, cli string, env []string) *exec.Cmd {
	cmd := exec.Command(self, AgentCommand) //nolint:noctx // lives until Stop or Close, not a context; this nushid as Claude's agent
	cmd.Dir = dir
	cmd.Env = append(slices.Clone(env), "CLAUDE_CODE_EXECUTABLE="+cli)
	return cmd
}

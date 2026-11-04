package claude

import (
	"os/exec"
	"slices"

	"github.com/afrase/nushi/internal/agentproc"
)

// AgentCommand is the subcommand nushid runs Claude's Go agent under
// (claudeacp.Main): `nushid claude-acp`.
const AgentCommand = "claude-acp"

// goCommand is Nushi's Go agent for Claude: this executable's
// AgentCommand, in dir (the daemon's folder) and env, running cli, the
// user's Claude Code. It needs no Node and nothing set up. The agent reads
// claude's path from CLAUDE_CODE_EXECUTABLE, as claude-agent-acp did.
func goCommand(dir, cli string, env []string) (*exec.Cmd, error) {
	return agentproc.SelfCommand(AgentCommand, dir, append(slices.Clone(env), "CLAUDE_CODE_EXECUTABLE="+cli))
}

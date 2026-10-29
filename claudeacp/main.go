package claudeacp

import (
	"log/slog"
	"os"
)

// Command is the subcommand name a program that embeds the agent can run
// it under, as Nushi's daemon does (nushid claude-acp).
const Command = "claude-acp"

// Main runs the agent on stdin and stdout, logging to stderr; it returns
// once the client has gone and every claude has exited. The claude it
// runs is $CLAUDE_CODE_EXECUTABLE, the variable claude-agent-acp reads
// too, else claude on PATH.
func Main() {
	log := slog.New(slog.NewTextHandler(os.Stderr, nil))
	Serve(os.Stdin, os.Stdout, Config{CLIPath: os.Getenv("CLAUDE_CODE_EXECUTABLE"), Log: log})
}

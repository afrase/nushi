// Package omp knows what oh-my-pi (omp 18.12.6, `omp --mode acp`) does
// beyond ACP: how to start it, and its quirks. `main` hands these to the
// chats feature, which knows nothing of omp.
package omp

import (
	"encoding/json"
	"log/slog"
	"os/exec"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/model"
)

// Start starts the user's omp (cli) in its ACP mode, in dir (the
// daemon's folder), its stderr to log; its `#!/usr/bin/env
// bun` finds the user's Bun on PATH. omp reads its own config and keys
// (~/.omp, the environment); Nushi never does.
func Start(dir, cli string, client acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
	cmd := exec.Command(cli, "--mode", "acp") //nolint:noctx // lives until Stop or Close, not a context
	cmd.Dir = dir
	return agentproc.Start(cmd, client, log)
}

// CLI is omp's program, which runs under Bun (Needs); Page is where to
// get both.
const (
	CLI   = "omp"
	Needs = "bun"
	Page  = "https://github.com/can1357/oh-my-pi"
)

// Tested are the omp versions Nushi was run with.
var Tested = []string{"18.12.6"}

// Resume is the terminal command that opens an omp session by its id.
const Resume = "omp --resume"

// Other says field is the free-text answer omp puts after a question with
// choices: `<id>__other`, "Other (type your own)".
func Other(field, before model.Field) bool {
	return len(field.Options) == 0 && strings.HasPrefix(field.ID, before.ID+"__other")
}

// ToolCall drops the "$ " omp puts before a command's title: the app marks
// commands itself.
func ToolCall(it *model.Item, _ map[string]any, _ json.RawMessage) (ownText bool) {
	if it.ToolKind == "execute" {
		it.Title = strings.TrimPrefix(it.Title, "$ ")
	}
	return false
}

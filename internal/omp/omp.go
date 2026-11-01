// Package omp knows what oh-my-pi (omp 18.12.6, `omp --mode acp`) does
// beyond ACP: how to start it, and its quirks, as its Harness; the chats
// feature, which knows nothing of omp, takes that through its interfaces.
package omp

import (
	"encoding/json"
	"log/slog"
	"os/exec"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/model"
)

// Harness is omp as Nushi runs it, for the chats feature's interfaces.
// Nothing here reads omp's files: Local adds that.
type Harness struct{}

// Local is Harness with what reads omp's files on this Mac (sessions.go).
// Tests use Harness alone.
type Local struct{ Harness }

// Info is what Harness is.
func (Harness) Info() model.HarnessInfo {
	return model.HarnessInfo{Name: "omp", Title: "oh-my-pi", Resume: "omp --resume", OneWriter: true}
}

// Start starts the user's omp (r's CLI) in its ACP mode, in dir (the
// daemon's folder) and r's environment (the login shell's, ADR 0048), its
// stderr to log; its `#!/usr/bin/env bun` finds the user's Bun on that
// PATH. omp reads its own config and keys (~/.omp, the environment); Nushi
// never does.
func (Harness) Start(dir string, r agents.Run, client acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
	cmd := exec.Command(r.CLI, "--mode", "acp") //nolint:gosec,noctx // lives until Stop or Close, not a context; the omp found on PATH
	cmd.Dir, cmd.Env = dir, r.Env
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

// Other says field is the free-text answer omp puts after a question with
// choices: `<id>__other`, "Other (type your own)".
func (Harness) Other(field, before model.Field) bool {
	return len(field.Options) == 0 && strings.HasPrefix(field.ID, before.ID+"__other")
}

// ToolCall drops the "$ " omp puts before a command's title: the app marks
// commands itself.
func (Harness) ToolCall(it *model.Item, _ map[string]any, _ json.RawMessage) (ownText bool) {
	if it.ToolKind == "execute" {
		it.Title = strings.TrimPrefix(it.Title, "$ ")
	}
	return false
}

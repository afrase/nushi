// Package opencode knows what OpenCode (opencode 2.2.6, `opencode acp`)
// does beyond ACP: how to start and stop it, and its quirks, as its
// Harness; the chats feature, which knows nothing of opencode, takes that
// through its interfaces. What it does, as seen, is in
// docs/facts/opencode.md.
package opencode

import (
	"errors"
	"log/slog"
	"os/exec"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/model"
)

// Harness is opencode as Nushi runs it, for the chats feature's
// interfaces. Nothing here reads opencode's files.
type Harness struct{}

// Local is Harness as the daemon runs it, the place for what reads
// opencode's files on this machine; nothing does yet. Tests use Harness
// alone.
type Local struct{ Harness }

// Info is what Harness is. The initialize _meta asks for a subagent's
// updates apart from its parent's: without it opencode mixes a subagent's
// text and tool calls into the parent session's updates, told apart only
// by their _meta, and they would read as the parent's reply. With it they
// come as opencode/session/child_update notifications, which the ACP
// library ignores, and the parent's subagent tool call still shows, with
// its result.
//
// The rest is as opencode is: it takes no lock on a session and refuses
// nobody (no OneWriter), reopens one only from the session's own folder
// (no Moves), sends no title, and its session/delete deletes.
func (Harness) Info() model.HarnessInfo {
	return model.HarnessInfo{
		Name: "opencode", Title: "OpenCode", Resume: "opencode --session",
		InitMeta: map[string]any{"opencode/child-session-updates": true},
	}
}

// Start starts the user's opencode (r's CLI) as an ACP agent, in dir (the
// daemon's folder) and r's environment (the login shell's, ADR 0048), its
// stderr to log. opencode reads its own config, data and keys (its
// folders under ~/.config and ~/.local, the environment); Nushi never
// does.
//
// It is stopped by signal: when its input closes opencode exits at once
// and leaves the shell commands it was running, a turn's and the
// background ones, while a SIGTERM cancels its turn and takes its server
// and every command with it.
func (Harness) Start(dir string, r model.AgentRun, client acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
	cmd := exec.Command(r.CLI, "acp") //nolint:gosec,noctx // lives until Stop or Close, not a context; the opencode found on PATH
	cmd.Dir, cmd.Env = dir, r.Env
	a, err := agentproc.Start(cmd, client, log)
	if err != nil {
		return nil, err
	}
	a.StopBySignal()
	return a, nil
}

// CLI is opencode's program, Min the first whose ACP this is (opencode 1,
// npm's opencode-ai, speaks another), and Page where to get it.
const (
	CLI  = "opencode"
	Min  = "2.0.0"
	Page = "https://opencode.ai"
)

// Tested are the opencode versions Nushi was run with.
var Tested = []string{"2.2.6"}

// Other says field is the free-text answer opencode puts after a question
// with choices: `<id>_custom`, "Type your own answer".
func (Harness) Other(field, before model.Field) bool {
	return len(field.Options) == 0 && field.ID == before.ID+"_custom"
}

// Gone says a session/load error means opencode has no such session:
// Invalid params (-32602), "session not found: <id>", not ACP's Resource
// not found. A session of another folder ("session <id> does not belong to
// cwd: <folder>") is still opencode's, so it isn't gone.
func (Harness) Gone(err error) bool {
	e, ok := errors.AsType[*acp.Error](err)
	return ok && e.Code == acp.ErrorCodeInvalidParams && strings.Contains(e.Message, "session not found")
}

// HidesCommand says the command isn't one to offer in a chat: every one
// but compact. Over ACP the others opencode advertises (init, review,
// goal, and the user's own from its config) answer end_turn at once and
// run their turn unseen; a permission asked in it never reaches Nushi, and
// the next prompt can hang.
func (Harness) HidesCommand(name string) bool { return name != "compact" }

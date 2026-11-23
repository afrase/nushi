// Package codex knows what Codex's ACP adapter (codex-acp 2.2.2, which
// runs Codex 0.160.1) does beyond ACP: how to start it, and its quirks, as
// its Harness; the chats feature, which knows nothing of Codex, takes that
// through its interfaces.
package codex

import (
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"os/exec"
	"slices"
	"strings"
	"unicode/utf8"

	acp "github.com/afrase/acp-go/unstable"
	"github.com/afrase/codex-acp-go/codexacp"

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/toolcall"
)

// Harness is Codex as Nushi runs it, for the chats feature's interfaces.
// Nothing here reads Codex's files: Local adds that.
type Harness struct{}

// Local is Harness with what reads Codex's files on this Mac (sessions.go).
// Tests use Harness alone.
type Local struct{ Harness }

// Info is what Harness is. The adapter's session/delete archives the thread
// ($CODEX_HOME/archived_sessions); codex resume offers to unarchive it.
// Codex finds a session by its id whatever the folder, so it Moves.
func (Harness) Info() model.HarnessInfo {
	return model.HarnessInfo{Name: "codex", Title: "Codex", Resume: "codex resume", ClientMCP: true, DeleteArchives: true, OneWriter: true, Moves: true,
		OtherSuffix: "_note"} // "Additional answer or note" after a question
}

// Start starts the adapter, as claude.Harness does Claude's, running r's
// CLI, the user's Codex (codex-acp's CODEX_PATH): codex-acp set up in the
// data folder, which runs it as it is, or Nushi's Go agent when r has no
// adapter program (the user's setting, agents.Agent.Own; ADR 0142), which
// runs its native binary when npm installed it (Native). Codex reads its own config and login
// ($CODEX_HOME, else ~/.codex); Nushi never does.
func (Harness) Start(dir string, r model.AgentRun, client acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
	if r.Program == "" {
		cmd, err := goCommand(dir, r.CLI, r.Env)
		if err != nil {
			return nil, err
		}
		return agentproc.Start(cmd, client, log)
	}
	return agentproc.Start(adapterCommand(dir, r), client, log)
}

// adapterCommand is codex-acp, set up in the data folder, in dir with r's
// environment and r's CLI as CODEX_PATH: npm's launcher stays in front of
// Codex there, as before the Go agent, since it is what tells Codex how it
// was installed (Native).
func adapterCommand(dir string, r model.AgentRun) *exec.Cmd {
	cmd := exec.Command(r.Node, r.Program) //nolint:gosec,noctx // lives until Stop or Close, not a context; the adapter set up in the data folder (ADR 0037)
	cmd.Dir = dir
	cmd.Env = append(slices.Clone(r.Env), "CODEX_PATH="+r.CLI)
	return cmd
}

// Adapter is Codex's ACP adapter, as Nushi pins it: adapter/'s
// package.json names the version, its lockfile every package's (make
// adapters writes it again, and says the sizes). Its own Codex (the platforms' optional dependencies) is left out: it
// runs the user's. Only a 20 KB launcher of @openai/codex, a dependency,
// comes along, unused.
var Adapter, _ = fs.Sub(adapterFiles, "adapter")

const (
	AdapterPackage  = "@agentclientprotocol/codex-acp"
	AdapterBin      = "codex-acp"
	AdapterDownload = 2_337_235
	AdapterDisk     = 18_599_936
)

//go:embed adapter
var adapterFiles embed.FS

// CLI is Codex's program.
const CLI = "codex"

// NoSignIn are the sign-in methods codex-acp and the Go agent may offer
// that Nushi doesn't (ADR 0145): an API key ("api-key", from the request or
// the environment) and a model gateway ("gateway"), which are the user's
// keys, and ChatGPT's device code ("chat-gpt-device-code"), whose code and
// page the agent shows through a URL elicitation Nushi doesn't take.
// "chat-gpt" stays: the agent opens the browser and waits on its own.
var NoSignIn = []string{"api-key", "chat-gpt-device-code", "gateway"}

// Tested are the Codex versions the adapter was run with: its own (until
// milestone Z), then the user's.
var Tested = []string{"0.160.1", "0.163.0"}

// ReadOnlyMode is Codex's read-only sandbox (docs/facts/codex.md).
func (Harness) ReadOnlyMode() string { return "read-only" }

// Gone says a session/load error means Codex has no rollout of the
// session (deleted, or never written): codex-acp 2.2.2 answers Internal
// error (-32603) with data.details "no rollout found for thread id <id>".
// An archived session ("session <id> is archived. Run `codex unarchive
// <id>`…") is still Codex's, so it isn't gone.
func (Harness) Gone(err error) bool {
	e, ok := errors.AsType[*acp.Error](err)
	if !ok || e.Code != acp.ErrorCodeInternalError {
		return false
	}
	var d struct {
		Details string `json:"details"`
	}
	_ = json.Unmarshal(e.Data, &d)
	return strings.HasPrefix(d.Details, "no rollout found for thread id ")
}

// ForkAt says how to fork a session at a message, if the agent is the
// adapter or the Go agent (codex-acp-go's codexacp, which reads the same
// meta): the same vendor meta as Claude's adapter takes
// (`_meta.jetbrains.air.fork`, ADR 0020), which codex-acp honors for any
// client. Codex cuts the fork after the whole turn that has the message.
func (Harness) ForkAt(init *acp.InitializeResponse) func(messageID string) map[string]any {
	if init.AgentInfo == nil || (init.AgentInfo.Name != "@agentclientprotocol/codex-acp" && init.AgentInfo.Name != codexacp.Name) {
		return nil
	}
	return func(messageID string) map[string]any {
		return map[string]any{"jetbrains": map[string]any{"air": map[string]any{
			"fork": map[string]any{"version": 1, "messageId": messageID}}}}
	}
}

// ToolCall reads a command's output, which the adapter sends a client
// without terminals (Nushi) in pieces, as `_meta.terminal_output_delta`,
// and how it ended, `_meta.terminal_exit`. The call's content is then only
// a reference to a terminal: its text is the output in a fence, after
// "Exit code N" when it failed. Only the output's last 64 KiB is kept,
// said so above it. A call without either is left as it is. An MCP call gets
// its server and tool, and kind "other" (readMCP).
func (Harness) ToolCall(it *model.Item, meta map[string]any, input json.RawMessage) (ownText bool) {
	readMCP(it, input)
	out, _ := meta["terminal_output_delta"].(map[string]any)
	exit, ok := meta["terminal_exit"].(map[string]any)
	if out == nil && !ok {
		return false
	}
	data, _ := out["data"].(string)
	it.Output = keep(it.Output + data)
	body, cut := strings.CutPrefix(it.Output, notShown+"\n")
	it.Text = toolcall.Fence(body)
	if cut {
		it.Text = notShown + "\n\n" + it.Text
	}
	switch code, isCode := exit["exit_code"].(float64); {
	case isCode && code != 0:
		it.Text = fmt.Sprintf("Exit code %d\n\n%s", int(code), it.Text)
	case ok && !isCode && exit["signal"] != nil:
		it.Text = fmt.Sprintf("Ended by signal %v\n\n%s", exit["signal"], it.Text)
	}
	return true
}

// keptOutput is how much of a command's output a call keeps: a build or
// a test run can print for an hour, and each piece rewrites the call's
// text and sends the whole call to every client again, so a MiB a piece
// left a slow client (the phone, through the relay) behind the events
// hub. 64 KiB is what Claude's background commands keep.
const keptOutput = 64 << 10

// notShown is the line output let go of starts with.
const notShown = "… (earlier output not shown)"

// keep is output's last keptOutput bytes from a line's start (a
// character's, in a line that long) after notShown's line, or output
// whole when it's no longer.
func keep(output string) string {
	if len(output) <= keptOutput+len(notShown)+1 {
		return output
	}
	s := output[len(output)-keptOutput:]
	if i := strings.IndexByte(s, '\n'); i >= 0 && i < len(s)-1 {
		s = s[i+1:]
	} else {
		for s != "" && !utf8.RuneStart(s[0]) {
			s = s[1:]
		}
	}
	return notShown + "\n" + s
}

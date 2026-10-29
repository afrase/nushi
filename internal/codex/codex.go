// Package codex knows what Codex's ACP adapter (codex-acp 2.2.2, which
// runs Codex 0.160.1) does beyond ACP: how to start it, and its quirks.
// `main` hands these to the chats feature, which knows nothing of Codex.
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

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/toolcall"
)

// Start starts the adapter, as claude.Start does Claude's (node, env), running cli,
// the user's Codex (codex-acp's CODEX_PATH). Codex reads its own config
// and login ($CODEX_HOME, else ~/.codex); Nushi never does.
func Start(dir, node, program, cli string, env []string, client acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
	cmd := exec.Command(node, program) //nolint:gosec,noctx // lives until Stop or Close, not a context; the adapter set up in the data folder (ADR 0037)
	cmd.Dir = dir
	cmd.Env = append(slices.Clone(env), "CODEX_PATH="+cli)
	return agentproc.Start(cmd, client, log)
}

// Adapter is Codex's ACP adapter, as Nushi pins it (see claude.Adapter).
// Its own Codex (the platforms' optional dependencies) is left out: it
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

// CLI is Codex's program, and Page where to get it.
const (
	CLI  = "codex"
	Page = "https://developers.openai.com/codex/cli"
)

// Tested are the Codex versions the adapter was run with: its own (until
// milestone Z), then the user's.
var Tested = []string{"0.160.1", "0.163.0"}

// Resume is the terminal command that opens a Codex session by its id.
const Resume = "codex resume"

// DeleteArchives says the adapter's session/delete archives the thread
// ($CODEX_HOME/archived_sessions); codex resume offers to unarchive it.
const DeleteArchives = true

// Gone says a session/load error means Codex has no rollout of the
// session (deleted, or never written): codex-acp 2.2.2 answers Internal
// error (-32603) with data.details "no rollout found for thread id <id>".
// An archived session ("session <id> is archived. Run `codex unarchive
// <id>`…") is still Codex's, so it isn't gone.
func Gone(err error) bool {
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

// History makes a session ready to fork into another folder: nothing to
// do, since Codex finds a session by its id whatever the folder, and forks
// it with another cwd.
func History(_, _, _ string) (remove func() error, err error) {
	return func() error { return nil }, nil
}

// ForkAt says how to fork a session at a message, if the agent is the
// adapter: the same vendor meta as Claude's adapter takes
// (`_meta.jetbrains.air.fork`, ADR 0020), which codex-acp honors for any
// client. Codex cuts the fork after the whole turn that has the message.
func ForkAt(init *acp.InitializeResponse) func(messageID string) map[string]any {
	if init.AgentInfo == nil || init.AgentInfo.Name != "@agentclientprotocol/codex-acp" {
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
// "Exit code N" when it failed. Only the output's last MiB is kept, said
// so above it. A call without either is left as it is.
func ToolCall(it *model.Item, meta map[string]any, _ json.RawMessage) (ownText bool) {
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
// text (Claude's shells keep 64 KB).
const keptOutput = 1 << 20

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

// Other says field is the free-text note that the adapter puts after a
// question with choices: `<id>_note`, "Additional answer or note".
func Other(field, before model.Field) bool {
	return len(field.Options) == 0 && strings.HasPrefix(field.ID, before.ID+"_note")
}

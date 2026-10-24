// Package codex knows what Codex's ACP adapter (codex-acp 2.2.2, which
// runs Codex 0.160.1) does beyond ACP: how to start it, and its quirks.
// `main` hands these to the chats feature, which knows nothing of Codex.
package codex

import (
	"encoding/json"
	"fmt"
	"log"
	"os/exec"
	"strings"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// adapter is the pinned Codex ACP adapter; it brings its own Codex.
const adapter = "@agentclientprotocol/codex-acp@2.2.2"

// Start starts the adapter, as claude.Start does Claude's: in dir (the
// daemon's own folder), its stderr to the daemon log. Codex reads its own
// config and login ($CODEX_HOME, else ~/.codex); Nushi never does.
func Start(dir string, h acp.Handler) (*acp.Client, error) {
	cmd := exec.Command("npx", "--yes", adapter)
	cmd.Dir = dir
	cmd.Stderr = log.Writer()
	return acp.Start(cmd, h)
}

// Resume is the terminal command that opens a Codex session by its id.
const Resume = "codex resume"

// History makes a session ready to fork into another folder: nothing to
// do, since Codex finds a session by its id whatever the folder, and forks
// it with another cwd.
func History(sessionID, from, to string) (remove func() error, err error) {
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
// "Exit code N" when it failed. A call without either is left as it is.
func ToolCall(it *model.Item, meta map[string]any, _ json.RawMessage) (ownText bool) {
	out, _ := meta["terminal_output_delta"].(map[string]any)
	exit, ok := meta["terminal_exit"].(map[string]any)
	if out == nil && !ok {
		return false
	}
	data, _ := out["data"].(string)
	it.Output += data
	it.Text = fence(it.Output)
	switch code, isCode := exit["exit_code"].(float64); {
	case isCode && code != 0:
		it.Text = fmt.Sprintf("Exit code %d\n\n%s", int(code), it.Text)
	case ok && !isCode && exit["signal"] != nil:
		it.Text = fmt.Sprintf("Ended by signal %v\n\n%s", exit["signal"], it.Text)
	}
	return true
}

// fence puts output in a code fence longer than any run of backticks in it.
func fence(output string) string {
	if output == "" {
		return ""
	}
	longest, run := 0, 0
	for _, r := range output {
		if r == '`' {
			run++
			longest = max(longest, run)
		} else {
			run = 0
		}
	}
	f := strings.Repeat("`", max(3, longest+1))
	return f + "\n" + strings.TrimSuffix(output, "\n") + "\n" + f
}

// Other says field is the free-text note that the adapter puts after a
// question with choices: `<id>_note`, "Additional answer or note".
func Other(field, before model.Field) bool {
	return len(field.Options) == 0 && strings.HasPrefix(field.ID, before.ID+"_note")
}

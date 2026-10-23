// Package claude knows what Claude Code's ACP adapter (claude-agent-acp
// 0.94.0) does beyond ACP: how to start it, the _meta it reads and sends,
// and its quirks. `main` hands these to the chats feature, which knows
// nothing of Claude. Claude's files are read in claudehistory, claudemcp
// and claudetrust.
package claude

import (
	"cmp"
	"encoding/json"
	"log"
	"os/exec"
	"strings"
	"time"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// adapter is the pinned Claude Code ACP adapter.
const adapter = "@agentclientprotocol/claude-agent-acp@0.94.0"

// Start starts the adapter. It runs in dir (the daemon's own folder), so
// npx never resolves the adapter or npm settings from a project; a chat's
// folder reaches the agent only as the session's cwd. Its stderr goes to
// the daemon log.
func Start(dir string, h acp.Handler) (*acp.Client, error) {
	cmd := exec.Command("npx", "--yes", adapter)
	cmd.Dir = dir
	cmd.Stderr = log.Writer()
	return acp.Start(cmd, h)
}

// InitMeta is initialize's client _meta: the adapter then sends a
// subagent's text and thinking too.
var InitMeta = map[string]any{"subagent-transcript": true}

// ForkAt says how to fork a session at a message, if the agent is the
// adapter. ACP's session/fork copies a whole conversation; the adapter cuts
// the copy after an agent message (its ACP messageId, the message included)
// only given a vendor extension meant for JetBrains AIR,
// `_meta.jetbrains.air.fork` (ADR 0020). Drop it when ACP has a standard
// way.
func ForkAt(init *acp.InitializeResponse) func(messageID string) map[string]any {
	if init.AgentInfo == nil || init.AgentInfo.Name != "@agentclientprotocol/claude-agent-acp" {
		return nil
	}
	return func(messageID string) map[string]any {
		return map[string]any{"jetbrains": map[string]any{"air": map[string]any{
			"fork": map[string]any{"version": 1, "messageId": messageID}}}}
	}
}

// Parent reads the subagent tool call an update comes from (the subagent's
// own tool calls, text and thinking), from _meta.claudeCode.
func Parent(meta map[string]any) string { return claudeCode(meta, "parentToolUseId") }

func claudeCode(meta map[string]any, key string) string {
	cc, _ := meta["claudeCode"].(map[string]any)
	s, _ := cc[key].(string)
	return s
}

// ToolCall adds what Claude tells about a tool call: the subagent it comes
// from, its tool's name, for one that starts a subagent (Agent, Task) the
// subagent's type, and for a subagent's SubagentHandback, which ends it,
// the report it hands back as its text: true then, since the call's own
// output is only an acknowledgement. Claude may send the input in a later
// update than the name.
func ToolCall(it *model.Item, meta map[string]any, input json.RawMessage) (ownText bool) {
	it.Parent, it.Tool = cmp.Or(it.Parent, Parent(meta)), cmp.Or(claudeCode(meta, "toolName"), it.Tool)
	var in struct {
		Type    string `json:"subagent_type"`
		Message string `json:"message"`
	}
	json.Unmarshal(input, &in)
	switch it.Tool {
	case "Agent", "Task":
		it.Agent = cmp.Or(in.Type, it.Agent, "Agent")
	case "SubagentHandback":
		it.Text = cmp.Or(in.Message, it.Text)
		return true
	}
	return false
}

// Background says an Agent call's output tells that Claude started the
// subagent in the background: it then completes the call at once, and the
// subagent runs until its SubagentHandback.
func Background(output string) bool { return strings.HasPrefix(output, "Async agent launched") }

// Other says field is the free-text "Other" answer that Claude's
// AskUserQuestion form puts after a question: `<id>_custom`.
func Other(field, before model.Field) bool {
	return len(field.Options) == 0 && field.ID == before.ID+"_custom"
}

// Default says v is the model list's "Default (recommended)": Claude
// picks the model then.
func Default(o model.ConfigOption, v model.ConfigValue) bool {
	return o.Category == "model" && strings.HasPrefix(strings.ToLower(v.Name), "default")
}

// ForkTitle says whether title is Claude's for a fork of a session titled
// of: "<title> (fork)", for a fork of a fork "<title> (fork) (fork)".
func ForkTitle(title, of string) bool {
	rest, ok := strings.CutPrefix(title, of)
	return ok && rest != "" && strings.Trim(strings.ReplaceAll(rest, " (fork)", ""), " ") == ""
}

// ContextCommand says what fills the context. The adapter answers it
// itself, without the model, but Claude keeps the answer in the
// conversation (ADR 0017).
const ContextCommand = "context"

// ReadContext reads /context's reply: its last message, since the adapter
// sends the output twice, as two messages.
func ReadContext(messages []string) model.ContextUsage {
	md := messages[len(messages)-1]
	cats, _ := Parse(md) // the app shows the markdown when there are none
	return model.ContextUsage{Markdown: md, Categories: cats}
}

// Redelete is how long after deleting a session that nobody will see again
// it is deleted once more: deleting closes it first, but Claude writes a
// little of the session back as it ends.
const Redelete = 3 * time.Second

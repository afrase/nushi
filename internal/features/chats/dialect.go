package chats

import (
	"encoding/json"
	"time"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// Dialect is what the agent does beyond ACP, and how Nushi reads it: `main`
// fills it for Claude (internal/claude). A nil field means the agent has
// none of it, as a plain ACP agent.
type Dialect struct {
	// InitMeta goes in initialize's client capabilities, as _meta.
	InitMeta map[string]any
	// ForkAt, given the agent's initialize answer, returns session/fork's
	// _meta to fork a session at one of the agent's messages (its ACP
	// messageId), the message included; nil when the agent can't.
	ForkAt func(*acp.InitializeResponse) func(messageID string) map[string]any
	// Parent reads the subagent tool call an update comes from, from its
	// _meta.
	Parent func(meta map[string]any) string
	// ToolCall adds what a tool call's _meta and raw input tell of it (its
	// subagent, tool, the subagent it starts, whether it is a subagent's
	// report, its command's output); ownText says it set the call's text,
	// so the call's content isn't its output.
	ToolCall func(it *model.Item, meta map[string]any, input json.RawMessage) (ownText bool)
	// Background says a subagent call's output tells it started the
	// subagent in the background: it runs on past the call, until its
	// report.
	Background func(output string) bool
	// ReportElsewhere says a subagent call's output only points at its
	// report, which then isn't its result.
	ReportElsewhere func(output string) bool
	// Shell says a tool call left its command running in the background:
	// the task's id and the file its output goes to;
	// ReadShell reads that file: the output so far, and how the command
	// ended ("" while it runs).
	Shell     func(it model.Item) (id, file string, ok bool)
	ReadShell func(id, file string) (output, end string, err error)
	// SubagentID reads the agent's id for a subagent from its call's output
	// (Claude's ToolCall sets it while the call runs; a replayed call has
	// only its output). Relay wraps a message for a subagent into a prompt
	// that asks the agent to pass it on unchanged; Relayed reads such a
	// prompt back: the subagent's type and the message.
	SubagentID func(output string) string
	Relay      func(agent, agentID, text string) string
	Relayed    func(prompt string) (agent, text string, ok bool)
	// Other says a form field is the free-text "Other" answer of the field
	// before it.
	Other func(field, before model.Field) bool
	// Default says a config value is the agent's "use the default" choice.
	Default func(model.ConfigOption, model.ConfigValue) bool
	// ForkTitle says whether title is the agent's own for a fork of a
	// session titled of: a moved or rewound chat keeps its title.
	ForkTitle func(title, of string) bool
	// ContextCommand is the slash command that says what fills the
	// context, run unseen in a throwaway fork; ReadContext reads its reply
	// (the reply's messages, in order, at least one).
	ContextCommand string
	ReadContext    func(messages []string) model.ContextUsage
	// Redelete is how long after deleting a session nobody will see again
	// to delete it once more, for an agent that writes a little of it back
	// as it ends; 0 for once.
	Redelete time.Duration
}

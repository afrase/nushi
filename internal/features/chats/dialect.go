package chats

import (
	"context"
	"encoding/json"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// Dialect is what the agent does beyond ACP, and how Nushi reads it: `main`
// fills it for Claude (internal/claude). A nil field means the agent has
// none of it, as a plain ACP agent.
type Dialect struct {
	// InitMeta goes in initialize's client capabilities, as _meta.
	InitMeta map[string]any
	// SessionMeta goes in session/new's, session/load's and session/fork's
	// _meta.
	SessionMeta map[string]any
	// UltracodeMeta joins SessionMeta (merged, key by key) in the sessions
	// of a chat with Ultracode on: the agent's standing multi-agent
	// workflows (Claude Code's ultracode). Nil when the agent has none:
	// the chat then has no Ultracode option.
	UltracodeMeta map[string]any
	// TurnDone says a usage update reports the end of the running turn's
	// own work: an agent that holds the prompt open for subagents it left
	// running in the background (Claude) answers it only once they end,
	// so the chat counts as idle from here while one runs.
	TurnDone func(*acp.UsageUpdate) bool
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
	// prompt back: the subagent's type and id, and the message. Relaying
	// says a tool call is the agent passing a message on, to the subagent
	// with that id.
	SubagentID func(output string) string
	Relay      func(agent, agentID, text string) string
	Relayed    func(prompt string) (agent, agentID, text string, ok bool)
	Relaying   func(call model.Item) (agentID string)
	// Subagents says the agent can show its subagents as sessions of
	// their own (ACP's subagents RFD, which initialize advertises): it then
	// says when each ends, and stops one when its session is cancelled.
	Subagents bool
	// StopTask asks the agent to stop one of its background tasks (a
	// subagent, or a command it left running), by the agent's id for it,
	// when Nushi can't stop it itself; StopRelayed reads such a prompt
	// back (label is what it names the task, "" when only its id). Stopped
	// says a tool call stopped one of the agent's tasks, or found it
	// already ended: the task's id.
	StopTask    func(taskID string) string
	StopRelayed func(prompt string) (label, taskID string, ok bool)
	Stopped     func(call model.Item) string
	// RunsShell says a process the agent runs (its command line) is the
	// shell running the command of call, a tool call that left it running
	// in the background (see Shell): Nushi then stops the command itself,
	// by its process group, without a turn (children.go).
	RunsShell func(call model.Item, args []string) bool
	// Other says a form field is the free-text "Other" answer of the field
	// before it.
	Other func(field, before model.Field) bool
	// Default says a config value is the agent's "use the default" choice.
	Default func(model.ConfigOption, model.ConfigValue) bool
	// ForkTitle says whether title is the agent's own for a fork of a
	// session titled of: a moved or rewound chat keeps its title.
	ForkTitle func(title, of string) bool
	// NamesSessions says the agent titles a session itself, soon after its
	// first prompt (Claude, with a model call of its own that may end after
	// a short first turn): a worktree's branch waits for that title, a
	// turn at most, rather than take the prompt's line.
	NamesSessions bool
	// ContextCommand is the slash command that says what fills the
	// context, run unseen in a throwaway fork; ReadContext reads its reply
	// (the reply's messages, in order, at least one).
	ContextCommand string
	ReadContext    func(messages []string) model.ContextUsage
	// Context asks the agent itself what fills a session's context, with
	// call (an extension of the agent's: Agent.Call), leaving nothing
	// behind: no fork, no command. An agent with it needs no
	// ContextCommand.
	Context func(ctx context.Context, call func(ctx context.Context, method string, params, result any) error, sessionID string) (model.ContextUsage, error)
	// Compacted says an item is part of a compaction of the conversation:
	// its call, or the summary the agent's replay starts with after one,
	// when it replays only what follows (see merge).
	Compacted func(model.Item) bool
	// Redelete is how long after deleting a session nobody will see again
	// to delete it once more, for an agent that writes a little of it back
	// as it ends; 0 for once.
	Redelete time.Duration
	// Notice reads a message chunk that is a notice of the agent's own,
	// not its model's words (Claude Code's, which it sends as agent text):
	// it shows as a notice line, not in a message.
	Notice func(meta map[string]any, text string) (model.AgentNotice, bool)
}

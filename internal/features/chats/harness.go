package chats

import (
	"context"
	"encoding/json"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// Harness is an agent Nushi runs, as this feature needs it: what it is
// (model.HarnessInfo, plain data), and, through the small interfaces below,
// what it does beyond ACP. A harness has what it implements and no more: one
// with none of them is a plain ACP agent. Each agent's package has its
// concrete type (claude.Harness…), which meets these by shape: an agent
// package doesn't import this one. newKind asks a harness what it can do,
// once; knownagents writes down which harness has what (ADR 0077).
type Harness interface {
	Info() model.HarnessInfo
}

// Forker forks a session at a message: given the agent's initialize answer,
// ForkAt returns session/fork's _meta to fork a session at one of the agent's
// messages (its ACP messageId), the message included; nil when the agent
// can't.
type Forker interface {
	ForkAt(init *acp.InitializeResponse) func(messageID string) map[string]any
}

// ToolReader reads more of a tool call than ACP says: ToolCall adds what its
// _meta and raw input tell of it (its subagent, tool, the subagent it starts,
// whether it is a subagent's report, its command's output); ownText says it
// set the call's text, so the call's content isn't its output.
type ToolReader interface {
	ToolCall(it *model.Item, meta map[string]any, input json.RawMessage) (ownText bool)
}

// DefaultReader says a config value is the agent's "use the default" choice.
type DefaultReader interface {
	Default(model.ConfigOption, model.ConfigValue) bool
}

// Transcript is what in the agent's updates and replays isn't what it seems.
type Transcript interface {
	// TurnDone says a usage update reports the end of the running turn's
	// own work: an agent that holds the prompt open for subagents it left
	// running in the background (Claude) answers it only once they end,
	// so the chat counts as idle from here while one runs.
	TurnDone(*acp.UsageUpdate) bool
	// OwnTurnEnded says a usage update ends the agent's own turn: one that
	// sends usage after each model call in a turn ends it with only one of
	// them (Claude: the result's, the one with the cost). An agent without
	// a Transcript ends it with any.
	OwnTurnEnded(*acp.UsageUpdate) bool
	// Notice reads a message chunk that is a notice of the agent's own,
	// not its model's words (Claude Code's, which it sends as agent text):
	// it shows as a notice line, not in a message.
	Notice(meta map[string]any, text string) (model.AgentNotice, bool)
	// Interrupted says a replayed user message's text is the agent's mark
	// of a turn the user stopped, not the user's words: it's left out, as
	// the chat's own notice says the turn stopped.
	Interrupted(text string) bool
	// Compacted says an item is part of a compaction of the conversation:
	// its call, or the summary the agent's replay starts with after one,
	// when it replays only what follows (see merge).
	Compacted(model.Item) bool
	// ForkTitle says whether title is the agent's own for a fork of a
	// session titled of: a moved or rewound chat keeps its title.
	ForkTitle(title, of string) bool
}

// UsageReader reads what an agent's usage reports say beyond ACP's
// (usage.go, ADR 0136): another agent's limits plug in here.
type UsageReader interface {
	// UsageModel is the model a usage report's _meta names; "" when it
	// names none.
	UsageModel(meta map[string]any) string
	// Limits are the account limits a usage report's _meta carries, as the
	// agent reported them (Agent and Seen left to the chat); none when it
	// carries none.
	Limits(meta map[string]any) []model.Limit
}

// Subagents tells of the agent's subagents.
type Subagents interface {
	// Parent reads the subagent tool call an update comes from, from its
	// _meta.
	Parent(meta map[string]any) string
}

// SubagentOutput reads what a subagent call's output tells of its
// subagent (Claude's), beyond Subagents.
type SubagentOutput interface {
	// Background says a subagent call's output tells it started the
	// subagent in the background: it runs on past the call, until its
	// report.
	Background(output string) bool
	// ReportElsewhere says a subagent call's output only points at its
	// report, which then isn't its result.
	ReportElsewhere(output string) bool
	// SubagentID reads the agent's id for a subagent from its call's output
	// (Claude's ToolCall sets it while the call runs; a replayed call has
	// only its output).
	SubagentID(output string) string
}

// SubagentMessages passes the user's messages on to the agent's subagents.
// An agent meets it only with a real way to reach a subagent (Claude's
// SendMessage); without it a subagent has no message box.
type SubagentMessages interface {
	// ToSubagent wraps a message to a subagent, and the paths of the files
	// it names, into a prompt that asks the agent to pass it on unchanged.
	ToSubagent(agent, agentID, text string, files []string) string
	// ReadToSubagent reads such a prompt back: the subagent's type and id,
	// and the message.
	ReadToSubagent(prompt string) (agent, agentID, text string, ok bool)
	// PassesToSubagent says a tool call is the agent passing a message on,
	// to the subagent with that id.
	PassesToSubagent(call model.Item) (agentID string)
}

// BackgroundTasks follows and stops what the agent leaves running: its
// commands, and through it its subagents.
type BackgroundTasks interface {
	// BackgroundCommand says a tool call left its command running in the
	// background: the task's id and the file its output goes to.
	BackgroundCommand(it model.Item) (id, file string, ok bool)
	// ReadBackgroundCommand reads that file: the output so far, how the
	// command ended ("" while it runs) and so its state ("done", "failed",
	// "stopped"; "" while it runs), as the file says; only a sign until
	// its shell is gone, and only where the agent hasn't said
	// (followCommand).
	ReadBackgroundCommand(id, file string) (output, end, state string, err error)
	// StatBackgroundCommand is that file's size and when it last changed,
	// without opening it, by the same rules: a file whose both are as
	// at its last read isn't read again (followCommand).
	StatBackgroundCommand(id, file string) (size int64, modified time.Time, err error)
	// CommandTask reads the agent's own word on such a command, from an
	// update of the call that started it (its _meta): the task's id, its
	// state ("running", "done", "failed" or "stopped") and how it ended in
	// the file's words ("exited with code 0", "killed"; "" unsaid). ok is
	// false for an update that says nothing of one. Once heard, it is the
	// source of truth for whether the command runs (ADR 0130).
	CommandTask(meta map[string]any) (id, state, end string, ok bool)
	// TaskWord says an update's _meta is the agent's word on one of its
	// tasks of any kind, a command's or not (Claude's foreground command
	// and workflow are tasks too): an update of a call that carries only
	// that is no step of the agent's work, whether Nushi reads the word
	// (CommandTask) or passes over it.
	TaskWord(meta map[string]any) bool
	// RunsBackgroundCommand says a process the agent runs (its command
	// line) is the shell running the command of call, a tool call that left
	// it running in the background: Nushi then stops the command itself, by
	// its process group, without a turn (children.go).
	RunsBackgroundCommand(call model.Item, args []string) bool
	// StopTask asks the agent to stop one of its background tasks (a
	// subagent, or a command it left running), by the agent's id for it,
	// when Nushi can't stop it itself.
	StopTask(taskID string) string
	// ReadStopTask reads such a prompt back (label is what it names the
	// task, "" when only its id).
	ReadStopTask(prompt string) (label, taskID string, ok bool)
	// Stopped says a tool call stopped one of the agent's tasks, or found
	// it already ended: the task's id; unknown when the agent knows no task
	// of that id, which ends only a command Nushi shows running (a subagent
	// could be named wrongly).
	Stopped(call model.Item) (taskID string, unknown bool)
}

// ReadOnly is an agent with a mode that can't change anything. Its name is
// the value of its mode option.
type ReadOnly interface {
	ReadOnlyMode() string
}

// TerminalCommands are slash commands only the agent's terminal runs (its
// headless CLI refuses them) that set one of the chat's options, which Nushi
// runs in its place: Claude's /plan (docs/facts/claude.md, ADR 0088).
type TerminalCommands interface {
	// TerminalCommands are those commands, offered with the agent's own.
	TerminalCommands() []model.Command
	// TerminalCommand reads a prompt's text as one of them.
	TerminalCommand(text string) (model.OptionCommand, bool)
}

// CommandHider says which of the slash commands the agent lists it can't
// run for Nushi: HidesCommand says the one named name, as the agent lists
// it, isn't to be offered. opencode lists its terminal's commands, but over
// ACP it answers a prompt of any but /compact at once and runs the turn
// unseen: nothing of it shows, a permission it asks never arrives, and the
// next prompt can hang (docs/facts/opencode.md).
type CommandHider interface {
	HidesCommand(name string) bool
}

// ContextCommander has a slash command that says what fills the context:
// ContextCommand, run unseen in a throwaway fork; ReadContext reads its reply
// (the reply's messages, in order, at least one).
type ContextCommander interface {
	ContextCommand() string
	ReadContext(messages []string) model.ContextUsage
}

// ContextAsker can be asked what fills the context, and needs no
// ContextCommander: Context asks, with call (an extension of the agent's:
// Agent.Call), leaving nothing behind: no fork, no command.
type ContextAsker interface {
	Context(ctx context.Context, call func(ctx context.Context, method string, params, result any) error, sessionID string) (model.ContextUsage, error)
}

// TitleMaker makes a short title for a piece of a session's text (a pinned
// message, ADR 0085) with its model, through call (an extension of the
// agent's: Agent.Call), leaving the session as it was: its own title, its
// transcript and any running turn. "" when the agent made none.
type TitleMaker interface {
	MessageTitle(ctx context.Context, call func(ctx context.Context, method string, params, result any) error, sessionID, text string) (string, error)
}

// GoneReader says a session/load error means the agent no longer has the
// session (it deleted it).
type GoneReader interface {
	Gone(error) bool
}

// The agent's own files and processes on this Mac: the interfaces below are
// met only by an agent package's Local type, never by the Harness tests run,
// so a test can't read the owner's sessions.

// OpenFinder says which of sessions ids a process of the agent's holds open
// now, one this daemon didn't start (a terminal's): by session id, where ("a
// terminal", "another app").
type OpenFinder interface {
	OpenElsewhere(ids []string) map[string]string
}

// ForkFinder says which of sessions ids are forks of another session, so
// Find leaves them out (only top-level sessions are listed; subagents' the
// agents leave out themselves).
type ForkFinder interface {
	Forked(ids []string) map[string]bool
}

// SessionSearcher finds which of the agent's sessions say some text in
// what the user and the agent said, reading the agent's own files (ADR
// 0035): the newest first, s.Max at most (more: some files weren't read),
// passing over what Find leaves out besides chats (forks, subagents').
// When ctx ends it returns what it found so far, with ctx's error.
type SessionSearcher interface {
	SearchSessions(ctx context.Context, s model.SessionSearch) (hits []model.SessionHit, more bool, err error)
}

// WorktreeFinder says which worktree the agent's own files say each
// subagent of session sid of folder has, by the tool call that started it.
// Those files are the agent's to write: a path here only says whose a
// worktree is, once git lists it (related.go).
type WorktreeFinder interface {
	SubagentWorktrees(sid, folder string) map[string]string
}

// HistoryChecker says, from the agent's own files alone, that it no longer
// has session sid of folder, for certain: false whenever that can't be told
// (its files for the folder missing or unreadable). Without one a chat's
// sessions are found gone only by reopening them (GoneReader).
type HistoryChecker interface {
	HistoryGone(sid, folder string) bool
}

// WorkflowReader follows the runs the agent's tool calls launch, which go
// on past the call (Claude's Workflow, ADR 0127), from the agent's own
// files: LaunchedWorkflow says whether a completed call launched a run, and
// reads it from the call when nothing else told of it (a replay); nil for
// any other call; ReadWorkflow reads the run w names, of session sid of
// folder (fs.ErrNotExist: none of its files is there yet); WorkflowAgents
// lists its agents, and WorkflowAgentItems reads one's steps, the last
// limit of them, and how many came before.
type WorkflowReader interface {
	LaunchedWorkflow(call model.Item) *model.Workflow
	ReadWorkflow(sid, folder string, w model.Workflow) (model.Workflow, error)
	WorkflowAgents(sid, folder string, w model.Workflow) ([]model.WorkflowAgent, error)
	WorkflowAgentItems(sid, folder string, w model.Workflow, agentID string, limit int) ([]model.Item, int, error)
}

// MessageDater says when the agent's own files say session sid's messages of
// folder were sent, by item id: a replay doesn't tell, so a message Nushi
// never saw gets its time from here.
type MessageDater interface {
	MessageTimes(sid, folder string) map[string]time.Time
}

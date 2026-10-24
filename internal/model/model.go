// Package model holds the plain types that features and the API share.
package model

import "time"

// Session is what Nushi keeps of a chat, to list and reopen it. The agent
// keeps the rest.
type Session struct {
	ID string // Nushi's id for the chat
	// SessionID is the agent's session id. It changes when a chat without
	// messages moves to another folder (a new session starts there).
	SessionID string
	Agent     string
	Folder    string
	Title     string // the agent's title, or else the first prompt's first line
	Name      string // the title the user set, which wins over Title
	Mode      string // the mode it was last in
	Created   time.Time
	// Archived chats have no agent running; they reopen when unarchived.
	Archived bool
	// HasMessages says the chat's session has had a message: it is in the
	// agent's history and can be reopened, forked and moved with it.
	HasMessages bool
	// Earlier are the agent's sessions the chat had before it moved, oldest
	// first.
	Earlier []AgentSession `json:",omitempty"`
	// Worktree is the git worktree Nushi made for the chat, if it runs in
	// one; Folder is in it.
	Worktree *Worktree `json:",omitempty"`
	// EarlierWorktrees are the worktrees Nushi made for the chat before it
	// moved out of them, oldest first. They stay until the chat is deleted.
	EarlierWorktrees []Worktree `json:",omitempty"`
	// Scratch says Folder is a scratch folder of the chat's own (the chat
	// has no folder yet); worked out from the folder, not stored.
	Scratch bool `json:"-"`
}

// Worktree is a git worktree of a repository, on a branch of its own.
type Worktree struct {
	Repo   string // the repository's folder (its main worktree)
	Path   string // the worktree's folder
	Branch string // its branch, made for it
	Base   string // the branch it started from (a commit, if HEAD was detached)
	// BaseCommit is the commit it started from; empty for worktrees made
	// before Nushi kept it.
	BaseCommit string `json:",omitempty"`
}

// WorktreeState is what removing a worktree and deleting its branch would
// lose.
type WorktreeState struct {
	Gone       bool // its folder was removed outside Nushi
	Changed    int  // files with uncommitted changes, untracked ones included
	Ignored    int  // files and folders git ignores, which removing it deletes too
	Commits    int  // commits on its branch that its base doesn't have
	BranchGone bool // its branch was deleted outside Nushi
}

// AgentSession is one of the agent's sessions: its id and folder (cwd).
type AgentSession struct {
	ID, Folder string
}

type ItemKind int

const (
	UserMessage ItemKind = iota + 1
	AgentMessage
	ToolCall
	// Permission is the agent asking to run a tool call. Status is "pending"
	// until it is answered ("answered") or the agent stops waiting ("cancelled").
	Permission
	// Question is a form the agent asks the user to fill in (Claude's
	// AskUserQuestion). Text is its message. Status is "pending" until it is
	// "answered", "declined" or "cancelled".
	Question
	// Thought is the agent's thinking, streamed like a message.
	Thought
	// Plan is the agent's plan as a checklist (Plan), updated in place.
	Plan
	// Notice says how a turn ended when it didn't end normally, or an error.
	// Status is the reason ("cancelled", "refusal", "error", ...).
	Notice
)

// PlanEntry is a step of the agent's plan; Status is ACP's ("pending",
// "in_progress", "completed").
type PlanEntry struct {
	Content, Status string
}

// Item is one entry of a chat's transcript.
type Item struct {
	ID   string // unique in its chat
	Kind ItemKind
	// Text is the message, or a tool call's output as markdown.
	Text string
	// Title, ToolKind and Status describe a tool call, in the agent's words
	// (ToolKind and Status use ACP's values, such as "execute" and "completed").
	Title    string
	ToolKind string
	Status   string
	// Paths are the files a tool call works on, relative to the chat's
	// folder when inside it, and Diffs the edits it makes (Path, Old, New).
	Paths []string
	Diffs []FileChange
	// Plan holds a plan's entries.
	Plan []PlanEntry
	// Options are a permission prompt's choices, and Answer the ID of the one picked.
	Options []Option
	Answer  string
	// Fields are a question's form, in the agent's order.
	Fields []Field
	// Images are a message's or a tool call's images.
	Images []Image
	// Parent is the subagent tool call whose subagent made it, if one did.
	Parent string
	// Agent is the subagent's type ("Explore") when the item is a tool call
	// that starts a subagent; Prompt is the task it was given, Model and
	// Effort what it was asked to use ("" when it uses the chat's), and
	// RanModel the model it ran on, once the agent says.
	Agent, Prompt, Model, Effort, RanModel string
	// AgentID is the agent's id for the subagent, when it can pass it
	// messages.
	AgentID string
	// RelayTo is, for a user message, the type of the subagent the agent
	// was asked to pass it to (see Message.To).
	RelayTo string
	// Tool is a tool call's tool, when the agent names it ("Read").
	Tool string
	// ForkAt is, for a user message, the agent's message the conversation
	// before it ends with: where a rewind to it forks the session.
	// Rewindable says a rewind to it can fork there (or it is the first).
	ForkAt     string
	Rewindable bool
	// Subagent is how the subagent a tool call starts goes.
	Subagent *Subagent
	// Report says the tool call is a subagent's report to its chat: the
	// subagent's result, not one of its steps.
	Report bool
	// Shell is the command a tool call left running in the background.
	Shell *Shell
}

// Shell is a command the agent runs in the background. State is "running"
// while the daemon sees it run, then "done", "failed" or "stopped";
// "started" when its end can't be known (its agent is gone, or it started
// before the chat reopened, and it hasn't said it ended). Started and Ended
// are when the daemon saw that; Output is what it wrote (the end of it),
// End how it ended, in the agent's words ("exited with code 0").
type Shell struct {
	ID, State      string
	Started, Ended time.Time
	Output, End    string
}

// Subagent is how a subagent goes: State is "running", "done" or "failed";
// Started and Ended are when the daemon saw that (zero when it didn't: a
// replayed chat); Result is what it found, once it ended.
type Subagent struct {
	State          string
	Started, Ended time.Time
	Result         string
}

// Image is an image in a message or a tool call's output.
type Image struct {
	MimeType string
	Data     []byte
}

// Option is a choice the agent offers. Kind is ACP's hint for a permission
// option, such as "allow_once" or "reject_always".
type Option struct {
	ID, Name, Kind, Description string
}

// FieldType is how a question's field is answered.
type FieldType int

const (
	Text    FieldType = iota + 1
	Choice            // one of Options
	Choices           // any of Options
	Number
	Integer
	Boolean
)

// Field is one entry of a question's form. Values holds the answer: one value,
// or several for Choices.
type Field struct {
	ID, Title, Description string
	Type                   FieldType
	Options                []Option
	Required               bool
	Values                 []string
	OtherFor               string // the field this free-text one is the "Other" answer of
}

// Message is what the user sends: text, the files it mentions (relative
// to the chat's folder) and images. ID names one waiting in a chat's queue.
type Message struct {
	ID     string
	Text   string
	Files  []string
	Images []Image
	// To is the tool call of a subagent the message is for: the agent is
	// asked to pass it on. Relay is that subagent, once the chat found it.
	To    string
	Relay *Relay
}

// Relay is a subagent a message goes to through the agent: its type and the
// agent's id for it.
type Relay struct {
	Agent, AgentID string
}

// Event is a change to one chat. Exactly one of Item, Status, Config,
// Session, Commands, Removed, Usage, Queue, Cut and Terminals is set.
type Event struct {
	ChatID string
	// Seq numbers the chat's events from 1; a Chat snapshot says which
	// events it already includes.
	Seq     int64
	Session *Session // the chat was opened, or its title or mode changed
	Item    *Item
	// Append means Item.Text continues the item's text rather than replacing it.
	Append bool
	Status *Status
	// Config is the chat's whole set of config options.
	Config []ConfigOption
	// Commands, when not nil, are the agent's slash commands, all of them.
	Commands []Command
	Removed  bool   // the chat was removed
	Usage    *Usage // the chat's usage, all of it
	// Queue, when not nil, is every message waiting for the agent.
	Queue *[]Message
	// Cut is the item the transcript was cut back before: it and every
	// item after it are gone.
	Cut string
	// Terminals, when not nil, are the chat's terminals, all of them. These
	// events aren't numbered (Seq is 0).
	Terminals *[]Terminal
}

// Terminal is a shell the user runs beside a chat, in the daemon.
type Terminal struct {
	ID, ChatID string
	Folder     string // where it started
	Name       string // the name the user gave it, if any
	Shell      string // the shell's name, such as "zsh"
	// Program is the foreground program's command line while it isn't the
	// shell.
	Program  string
	Exited   bool
	ExitCode int // -1: killed by a signal
}

// Usage is what the agent last reported of a chat's usage; what it hasn't
// reported is zero. Nushi keeps it only while the agent runs.
type Usage struct {
	// Context tokens in use, and the context window's size.
	Used, Size int64
	// The session's cost so far.
	Cost     float64
	Currency string
	// The last turn's tokens.
	Input, Output, CachedRead, CachedWrite int64
}

// ContextUsage is what the agent says fills its context: its answer as
// markdown, and the categories read from it (none when they couldn't be).
type ContextUsage struct {
	Markdown   string
	Categories []ContextCategory
}

// ContextCategory is one kind of thing in the context: "Messages", 15,900
// tokens, 1.6%.
type ContextCategory struct {
	Name    string
	Tokens  int64
	Percent float64
	Kind    string // "free" for free space, "deferred" for what loads on demand, else ""
}

// Command is a slash command the agent offers.
type Command struct {
	Name, Description, Hint string
}

// ConfigOption is one of the agent's session settings (mode, model, ...).
// Category is ACP's ("mode", "model", "thought_level", ...); Type is
// "select" or "boolean", whose Current is "true" or "false".
type ConfigOption struct {
	ID, Name, Description, Category, Type, Current string
	Values                                         []ConfigValue
}

// ConfigValue is one value of a select option; Group names its group, if any.
type ConfigValue struct {
	Value, Name, Description, Group string
	Default                         bool // the agent's "use the default" choice
}

// Chat is a snapshot of a chat: everything its events have built so far.
type Chat struct {
	Session  Session
	Items    []Item
	Config   []ConfigOption
	Commands []Command
	Usage    Usage
	Status   Status
	Queue    []Message // waiting for the agent, in order
	Seq      int64     // the last event the snapshot includes
}

// Status is whether a chat is running a turn, and how the last one ended.
type Status struct {
	Busy    bool
	Started time.Time // when the running turn started
	Waiting bool      // a permission prompt or question waits on the user
	CanFork bool      // the agent can fork the chat into side chats
	Images  bool      // the agent takes images in prompts
	// CanRewind says the agent can rewind the chat to a user message.
	CanRewind bool
	// MCPChanged says MCP servers changed since the agent started; a reload
	// picks them up.
	MCPChanged bool
	// CanAskContext says ContextUsage can ask the agent what fills its
	// context, once the chat is idle.
	CanAskContext bool
}

// FileChange is one file's uncommitted change: its text at HEAD and now.
// Status is "added", "modified", "deleted", "renamed" (from OldPath) or
// "untracked". Skipped says why the texts are left out ("binary", "too
// large"), if they are. Added and Removed count its lines.
type FileChange struct {
	Path, OldPath, Status, Old, New, Skipped string
	Added, Removed                           int
}

// FolderStatus sums up a git folder's uncommitted changes. Branch is the
// branch checked out, or the commit when none is.
type FolderStatus struct {
	Branch                string
	Files, Added, Removed int
}

// FolderRun is something a folder has the agent run on its own: an MCP
// server, a hook, an env block or a helper command, and the file that says
// so.
type FolderRun struct {
	File    string
	What    string // "MCP server github", "Hook on SessionStart"
	Command string // the command line (an env block: the names it sets)
}

// MCPServer is an MCP server the agent's config gives a folder.
type MCPServer struct {
	Name string
	// Scope is where it is configured: "user", "project", "local",
	// "plugin", "claudeai" (a claude.ai connector), or "other".
	Scope string
	// Source is the file (or, for local scope, the project folder) that
	// has it.
	Source string
	// Config is its config as JSON, with env and header values masked.
	Config string
	// State is how connecting to it went, once checked: "connected",
	// "failed", "needs_auth", "pending" (approval), "disabled" or
	// "unknown". Detail is the agent's words on it.
	State, Detail string
	// Shadowed says a server of the same name in a scope that wins hides it.
	Shadowed bool
	// Off says a project server is turned off (rejected) for the folder;
	// OffBy names a file that does it other than the one Nushi changes.
	Off   bool
	OffBy string
	// Approved says the project's local settings approve a project server.
	Approved bool
}

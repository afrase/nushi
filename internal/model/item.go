package model

import "time"

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
	// Status is the reason ("cancelled", "refusal", "turn_failed", "error", ...);
	// "agent_notice" and "agent_warning" are the agent's own (AgentNotice).
	Notice
)

// StoppedBySafeguards is the Status of an agent's message whose response
// the model's safeguards stopped (AgentNotice.Stopped): what streamed of
// it before, which the agent drops from its history.
const StoppedBySafeguards = "stopped_by_safeguards"

// SentMeta is the _meta key of a replayed message's first chunk that says
// when it was sent (RFC 3339), from a bridge of Nushi's that can tell.
const SentMeta = "nushi.sent"

// AgentNotice is a notice of the agent's own that it sends as message
// text (Claude Code's, as agent text to a client without ACP's notices):
// Text without its label; Warning says it warns; Stopped says the model's
// safeguards stopped the response just before it, and the agent goes on.
type AgentNotice struct {
	Text             string
	Warning, Stopped bool
}

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
	// Input is a tool call's input as the agent gave it (rawInput), as
	// indented JSON; RawOutput its result as the agent gave it (rawOutput),
	// as text or indented JSON, kept only while its content shows nothing.
	// Each is cut to about 8 KB.
	Input, RawOutput string
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
	// WorktreePath is the worktree the agent says it gave the subagent, if
	// it says (untrusted: chats' related.go checks it against git's list).
	WorktreePath string `json:",omitempty"`
	// AgentID is the agent's id for the subagent, when it can pass it
	// messages; for a call that passes one a message (SubagentMessages.PassesToSubagent in chats),
	// that subagent's.
	AgentID string
	// A message to a subagent is a user message the agent was asked to pass
	// on: ToSubagentName is the subagent's type, and ToSubagent its tool
	// call (Message.To; after a replay, when the agent's id for it is
	// known). ToSubagentState says how it goes: "sending", "relayed" once
	// the agent's call that passes it on (PassedOnBy) completes, "failed"
	// when that call fails or the turn ends without one; "" unknown
	// (replayed). ToSubagentStop says it asked the agent to stop that
	// subagent or background command (ToSubagentName names it), not to pass
	// anything on. Their JSON names, and the state "relayed", are from
	// before the glossary's word (Nushi's copies keep them).
	ToSubagentName  string   `json:"RelayTo"`
	ToSubagent      string   `json:"RelayCall"`
	ToSubagentState string   `json:"RelayState"`
	PassedOnBy      string   `json:"RelayedBy"`
	ToSubagentStop  bool     `json:"RelayStop"`
	Files           []string // a user message's mentioned and attached files (Message.Files)
	// Tool is a tool call's tool, when the agent names it ("Read").
	Tool string
	// TaskID is the agent's id for the command a tool call left running in
	// the background, when its result says (structured, not its text);
	// InBackground says its input asked for that.
	TaskID       string
	InBackground bool
	// Stops is, for a call that stops one of the agent's background tasks
	// (Claude's TaskStop), the task's id: a subagent's AgentID or a
	// background command's BackgroundCommand.ID.
	Stops string
	// ForkAt is, for a user message, the agent's message the conversation
	// before it ends with: where a rewind to it forks the session.
	// Rewindable says a rewind to it can fork there (or it is the first).
	ForkAt     string
	Rewindable bool
	// Steered says a user message was handed into a turn already running
	// (the agent was steered), not the prompt a turn began with. Only
	// Nushi's copy knows it: a replay doesn't say.
	Steered bool `json:",omitzero"`
	// Sent is when a message was sent: a user message through Nushi, an
	// agent's as it began to arrive, else what the replay (SentMeta) or
	// the agent's own files (chats' MessageDater) say. Zero when not known.
	Sent time.Time `json:",omitzero"`
	// Subagent is how the subagent a tool call starts goes.
	Subagent *Subagent
	// Report says the tool call is a subagent's report to its chat: the
	// subagent's result, not one of its steps.
	Report bool
	// BackgroundCommand is the command a tool call left running in the
	// background (its JSON name from before the glossary's word).
	BackgroundCommand *BackgroundCommand `json:"Shell"`
	// Findings is a code review's result, for a tool call that reports one.
	Findings *Findings
	// ServerCommand is, for the ask to run Nushi's preview_start tool, the
	// command the named launch file entry runs, as resolved when the ask
	// came, for the card (ADR 0100).
	ServerCommand string `json:",omitempty"`
	// Output is a command's output as the agent streams it in its _meta,
	// from which the harness makes Text; only the daemon has it.
	Output string `json:"-"`
}

// BackgroundCommand is a command the agent runs in the background. State is
// "running" while the daemon sees it run, then "done", "failed" or "stopped";
// "started" when its end can't be known (its agent is gone, or it started
// before the chat reopened, and it hasn't said it ended). Started and Ended
// are when the daemon saw that; Output is what it wrote (the end of it),
// End how it ended, in the agent's words ("exited with code 0"). Killed
// says Nushi stopped it itself, at the user's Stop: an end other than
// success then reads "stopped", whatever exit code the agent gives it.
type BackgroundCommand struct {
	ID, State      string
	Started, Ended time.Time
	Output, End    string
	Killed         bool `json:",omitzero"`
}

// Process is one of the processes an agent runs: its id, its process
// group's, when it started (with the id, which process it is) and its
// command line (nil when unreadable).
type Process struct {
	Pid, Pgid int
	Started   time.Time
	Args      []string
}

// Findings is a code review's result as the agent reports it (Claude's
// ReportFindings): the effort level the review ran at, if it says, and
// what it found, most severe first.
type Findings struct {
	Level string
	Items []Finding
}

// Finding is one thing a review found: its file (relative to the
// repository) and line (from 1; 0 when not given), a sentence saying what's
// wrong and a short label for it (up to 60 characters, maybe empty), how it
// fails, and, when given, its kind ("correctness"), the verdict of a check
// of it ("CONFIRMED", "PLAUSIBLE") and, after fixes, what came of it
// ("fixed", "skipped", "no_change_needed").
type Finding struct {
	File, Summary, ShortSummary, FailureScenario string
	Line                                         int
	Category, Verdict, Outcome                   string
}

// Subagent is how a subagent goes: State is "running", "done", "failed"
// or "stopped"; Started and Ended are when the daemon saw that (zero when
// it didn't: a replayed chat); Result is what it found, once it ended.
// Said is its state as the agent last said it, for one the agent shows
// as a session of its own (ACP's subagents): "running", "done",
// "stopped", "failed"; "" when it never said. Session is that session,
// through which it can be stopped.
type Subagent struct {
	State          string
	Started, Ended time.Time
	Result         string
	Said, Session  string
}

// Image is an image in a message or a tool call's output. Hash is the
// lowercase hex SHA-256 of Data, taken once as the image comes in (or read
// from the transcript copy's file name), so what names an image by it
// (ADR 0099) never reads Data again; "" when not taken. Data is never
// changed in place, so the two stay one. Size is Data's length, Width and
// Height its pixels when its header says (else 0), taken with Hash.
//
// An image of a chat's transcript copy past SmallImage is held as a
// reference (Ref): Hash and Size without Data, its bytes read back from
// the copy only when something needs them (ADR 0105).
type Image struct {
	MimeType      string
	Data          []byte
	Hash          string `json:"-"`
	Size          int64  `json:"-"`
	Width, Height int    `json:"-"`
}

// SmallImage is the largest image always held and sent with its bytes: a
// reference and a call of its own would cost more (ADR 0099, 0105).
const SmallImage = 64 << 10

// Ref says the image is held as a reference: its bytes are in its chat's
// transcript copy, under Hash, not here.
func (img Image) Ref() bool { return img.Data == nil && img.Size > 0 }

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

// Message is what the user sends: text, the files it mentions or attaches
// (relative to the chat's folder, or absolute for one outside it) and
// images. Uploads are files a device sent whole, which the chat saves and
// adds to Files before anything else. ID names one waiting in a chat's
// queue.
type Message struct {
	ID      string
	Text    string
	Files   []string
	Images  []Image
	Uploads []Upload
	// To is the tool call of a subagent the message is for: the agent is
	// asked to pass it on. ToSubagent is that subagent, once the chat found
	// it.
	To         string
	ToSubagent *ToSubagent
}

// Upload is a file sent whole with a message: its name and its bytes.
type Upload struct {
	Name string
	Data []byte
}

// ToSubagent is a subagent a message goes to through the agent: its type
// and the agent's id for it. With Stop, the message asks the agent to stop it, or
// the background command it names (Agent is the command then, AgentID its
// task's id).
type ToSubagent struct {
	Agent, AgentID string
	Stop           bool
}

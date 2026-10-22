// Package model holds the plain types that features and the API share.
package model

import "time"

// Session is what Nushi keeps of a chat, to list and reopen it. The agent
// keeps the rest.
type Session struct {
	ID      string // the agent's session id
	Agent   string
	Folder  string
	Title   string
	Mode    string // the mode it was last in
	Created time.Time
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
)

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
	// Options are a permission prompt's choices, and Answer the ID of the one picked.
	Options []Option
	Answer  string
	// Fields are a question's form, in the agent's order.
	Fields []Field
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
}

// Event is a change to one chat. Exactly one of Item, Status, Config and
// Session is set.
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
}

// Chat is a snapshot of a chat: everything its events have built so far.
type Chat struct {
	Session Session
	Items   []Item
	Config  []ConfigOption
	Status  Status
	Seq     int64 // the last event the snapshot includes
}

// Status is whether a chat is running a turn, and how the last one ended.
type Status struct {
	Busy  bool
	Error string
}

// FileChange is one file's uncommitted change: its text at HEAD and now.
// Status is "added", "modified" or "deleted". Skipped says why the texts
// are left out ("binary", "too large"), if they are.
type FileChange struct {
	Path, Status, Old, New, Skipped string
}

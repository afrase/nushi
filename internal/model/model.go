// Package model holds the plain types that features and the API share.
package model

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

// Event is a change to one chat. Exactly one of Item and Status is set.
type Event struct {
	ChatID string
	Item   *Item
	// Append means Item.Text continues the item's text rather than replacing it.
	Append bool
	Status *Status
}

// Status is whether a chat is running a turn, and how the last one ended.
type Status struct {
	Busy  bool
	Error string
}

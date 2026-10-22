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
}

// Option is one of the agent's answers to a permission prompt. Kind is ACP's
// hint, such as "allow_once" or "reject_always".
type Option struct {
	ID, Name, Kind string
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

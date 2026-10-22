// Package model holds the plain types that features and the API share.
package model

type ItemKind int

const (
	UserMessage ItemKind = iota + 1
	AgentMessage
	ToolCall
)

// Item is one entry of a chat's transcript.
type Item struct {
	ID   string
	Kind ItemKind
	// Text is the message, or a tool call's output as markdown.
	Text string
	// Title, ToolKind and Status describe a tool call, in the agent's words
	// (ToolKind and Status use ACP's values, such as "execute" and "completed").
	Title    string
	ToolKind string
	Status   string
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

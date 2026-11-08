package model

// Event is a change to one chat, or, with ChatID "", to remote access, the
// chats removed or the update check. Exactly one of Record, Item, Status,
// Config, Commands, Removed, Usage, Queue, Cut, Dropped, Terminals, Remote,
// RemovedChats, Update, Show and Servers is set.
type Event struct {
	ChatID string
	// Seq numbers the chat's events from 1; a Chat snapshot says which
	// events it already includes.
	Seq    int64
	Record *ChatRecord // the chat was opened, or its title or mode changed
	Item   *Item
	// Append means Item.Text continues the item's text rather than replacing it.
	Append bool
	// Index is the item's place in the chat (not with Append).
	Index  int
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
	// Dropped is an item that's gone (a message the agent never got); the
	// rest stay.
	Dropped string
	// Terminals, when not nil, are the chat's terminals, all of them. These
	// events aren't numbered (Seq is 0).
	Terminals *[]Terminal
	// Related, when not nil, are the chat's related worktrees, all of them.
	// These events aren't numbered (Seq is 0).
	Related *[]RelatedWorktree
	// Show is a file the chat's agent asked to show in the preview pane
	// (its show tool, ADR 0068), as the agent named it. These events aren't
	// numbered (Seq is 0).
	Show string
	// ShowURL is a page the chat's agent asked to show in a browser tab:
	// its show tool's url, or a dev server it started once that answers
	// (ADR 0100); loopback http or https only. Not numbered either.
	ShowURL string
	// Servers is a folder whose dev servers changed (ADR 0098): one
	// started, answered, failed or ended; ChatID is "".
	Servers string
	// Remote, when not nil, is remote access as it stands; ChatID is "".
	Remote *Remote
	// RemovedChats, when not nil, are all the chats removed because their
	// agent no longer has their sessions; ChatID is "".
	RemovedChats *[]RemovedChat
	// Update, when not nil, is what the check for a newer release found,
	// as it stands; ChatID is "".
	Update *Update
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

// OptionCommand is a prompt that is one of the agent's slash commands which
// Nushi runs itself by setting one of the chat's options, as its menu does:
// the option of Category to Value, with the notice Set, then Prompt sent as
// the message, unless it is "". When the option has Value already, Prompt
// goes alone, or with none the chat gets the notice Already.
type OptionCommand struct {
	Category, Value, Prompt string
	Set, Already            string
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

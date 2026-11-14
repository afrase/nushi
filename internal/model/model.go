// Package model holds the plain types that features and the API share.
package model

import "time"

// ChatRecord is what Nushi keeps of a chat, to list and reopen it (Chat is
// a snapshot of it with its items). The agent keeps the rest, its session.
type ChatRecord struct {
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
	// Updated is when a message was last sent to the chat or a turn of it
	// last ended: what a list sorts by "last updated". Zero for a chat
	// with neither since the daemon kept it.
	Updated time.Time `json:",omitzero"`
	// Archived chats have no agent running; they reopen when unarchived.
	Archived bool
	// HasMessages says the chat's session has had a message: it is in the
	// agent's history and can be reopened, forked and moved with it.
	HasMessages bool
	// Earlier are the agent's sessions the chat had before it moved, oldest
	// first.
	Earlier []AgentSession `json:",omitempty"`
	// Worktree is the git worktree the chat runs in, if it runs in one
	// that isn't its repository's own folder: one Nushi made for it, or
	// one that was there (Found); Folder is in it.
	Worktree *Worktree `json:",omitempty"`
	// EarlierWorktrees are the worktrees Nushi made for the chat before it
	// moved out of them, oldest first. They stay until the chat is deleted.
	EarlierWorktrees []Worktree `json:",omitempty"`
	// RelatedWorktrees are the worktrees the chat's subagents worked in
	// (ADR 0081), in the order Nushi found them. Nushi neither made them
	// nor removes them.
	RelatedWorktrees []RelatedWorktree `json:",omitempty"`
	// Throwaway are sessions the agent forked from the chat's that nobody
	// will see again (side chats, /context runs), until the agent has
	// deleted them: a daemon that stops or crashes first leaves them for
	// the next time the chat opens, or Delete.
	Throwaway []string `json:",omitempty"`
	// Issue is the Jira issue the chat was started from, if it was.
	Issue *ChatIssue `json:",omitempty"`
	// GitHub is the GitHub pull request or issue the chat was started
	// from, if it was.
	GitHub *ChatGitHub `json:",omitempty"`
	// Pull is the pull request whose head is the chat's branch, found or
	// linked by hand, unless the chat was started from one (GitHub).
	// NoPull is the pull request unlinked by hand, not found again.
	Pull   *ChatGitHub `json:",omitempty"`
	NoPull int         `json:",omitempty"`
	// Ultracode is the chat's Ultracode option (its agent's standing
	// multi-agent workflows), off by default.
	Ultracode bool `json:",omitempty"`
	// Picks are the chat's options the user picked, other than the mode
	// and Ultracode (the model, the effort, ...), by option ID, at what the
	// agent is on now: put back whenever its session opens again.
	Picks map[string]string `json:",omitempty"`
	// Moved says the chat moved to another folder since its last prompt,
	// which tells the agent where it is now (and clears it).
	Moved bool `json:",omitempty"`
	// BranchFrom is the folder's branch as the agent last had it, when
	// Nushi switched the folder to another since (SwitchBranch); the next
	// prompt tells the agent, if the branch is still another, and clears it.
	BranchFrom string `json:",omitempty"`
	// Done says a turn ended (it finished, or failed with an error to
	// read; not one the user stopped) while no client showed the chat: the
	// chat state done. A client showing it clears it, and so does
	// archiving. Kept under its old name, Unseen.
	Done bool `json:"Unseen,omitempty"`
	// Pin is the chat's place among the pinned chats, from 1 (the top); 0
	// when it isn't pinned. Archiving unpins.
	Pin int `json:",omitempty"`
	// Color is the name of the chat's color, "" for none: a stable name, so
	// each theme draws it its own way (chats.SetColor).
	Color string `json:",omitempty"`
	// Pins are the chat's pinned messages, in the order they were pinned
	// (chats.PinMessage, ADR 0085): the agent's alone.
	Pins []MessagePin `json:",omitempty"`
	// SideOf is where an archived side chat came from: a side chat with
	// messages is archived as it's closed (ADR 0115), and Undo makes it
	// that chat's side chat again. Unarchiving clears it.
	SideOf *SideOf `json:",omitempty"`
	// Scratch says Folder is a scratch folder of the chat's own (the chat
	// has no folder yet); worked out from the folder, not stored.
	Scratch bool `json:"-"`
}

// PullLink is the chat's pull request: the one it was started from, else
// the one of its branch; nil when it has none.
func (s ChatRecord) PullLink() *ChatGitHub {
	if s.GitHub != nil && s.GitHub.Pull {
		return s.GitHub
	}
	return s.Pull
}

// MessagePin is a message the user pinned: its item's id, and what finds it
// again where a reopen gives it another (ADR 0085): its kind, a hash of its
// opening (its first Runes runes) and how many messages of that kind with
// the same opening come before it. Title is what a client lists it by:
// made from the message's text at once, the agent's own when it can make
// one (chats' pin_titles.go); "" for a pin kept before titles were.
type MessagePin struct {
	Item  string
	Kind  ItemKind
	Start string
	Runes int
	Nth   int    `json:",omitempty"`
	Title string `json:",omitempty"`
}

// SideOf is the chat an archived side chat came from (its id), and how many
// of its items were that chat's when the side chat opened: the rest are
// the side chat's own.
type SideOf struct {
	Chat string
	Base int
}

// AgentSession is one of the agent's sessions: its id and folder (cwd).
type AgentSession struct {
	ID, Folder string
}

// Chat is a snapshot of a chat: everything its events have built so far.
type Chat struct {
	Record   ChatRecord
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
	// CanWriteCommit: the agent can write a commit message for it.
	CanWriteCommit bool
	Images         bool // the agent takes images in prompts
	// CanRewind says the agent can rewind the chat to a user message.
	CanRewind bool
	// MCPChanged says MCP servers changed since the agent started; a reload
	// picks them up.
	MCPChanged bool
	// CanAskContext says ContextUsage can ask the agent what fills its
	// context, once the chat is idle.
	CanAskContext bool
	// Asleep says no agent runs for the chat (it slept, or wasn't opened
	// since the daemon started): what needs the agent reopens the session.
	Asleep bool
	// ReopenFailed says no agent runs for the chat because its last reopen
	// failed (a notice says why); it isn't Asleep then.
	ReopenFailed bool
	// SessionGone says, of a chat whose reopen failed, that its agent no
	// longer has its session: the chat stays only for its worktree's or
	// scratch folder's work, and Delete is what's left.
	SessionGone bool
	// CanSleep says Sleep can stop its agent: the agent reopens sessions.
	CanSleep bool
	// Background is how many subagents and background commands its agent
	// started still run; a turn can end while they do.
	Background int
	// Ended is set only on the status published as a turn ends: how the
	// chat judged it, the one verdict push and every client go by.
	Ended TurnEnd
	// Failure is, with TurnFailed, what ended the turn: the agent's error,
	// or that it quit.
	Failure string
}

// TurnEnd is how a chat judged a turn that just ended.
type TurnEnd int

const (
	// NotEnded: the status isn't a turn's end.
	NotEnded TurnEnd = iota
	// TurnDone: the agent ended the turn (its answer, refusals and limits
	// included); the user may want to know.
	TurnDone
	// TurnStopped: the user stopped the turn, or Nushi was stopping the
	// chat's agent (sleep, archive, move, delete, the daemon closing):
	// nothing to tell.
	TurnStopped
	// TurnFailed: an error ended the turn, or the agent quit or crashed
	// mid-turn (the owner's call, 2026-11-05): the user should look.
	TurnFailed
)

// Hold is one thing a daemon's restart waits for: a chat that runs or
// waits, or (Terminal) a terminal running a command, in a chat.
type Hold struct {
	ChatID   string
	Why      string // "working", "waits on you", "a message queued", "in background", a side chat's ("a side chat is working"); a terminal's "running <program>"
	Terminal bool
}

// TranscriptCopy is Nushi's copy of a chat's transcript (ADR 0047): its
// size on disk, images included, and when it was last written.
type TranscriptCopy struct {
	Chat     string
	Bytes    int64
	Modified time.Time
}

// RemovedChat is a chat Nushi removed because its agent no longer has its
// session (Claude Code deletes old ones): what Nushi kept of it.
type RemovedChat struct {
	ID, Agent, Title, Folder string
	At                       time.Time
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

// ShellEnv is how reading the login shell's environment, which agents
// start with, went last (ADR 0048): the shell, when it ended, and why it
// failed ("" when it worked). Nothing of the environment itself.
type ShellEnv struct {
	Shell, Problem string
	Read           time.Time
}

package model

import "time"

// HarnessInfo is what an agent's harness is, as plain data; what it does
// beyond ACP is the interfaces of internal/features/chats/harness.go. Alone
// it is a harness with nothing beyond ACP.
type HarnessInfo struct {
	Name  string // as chats keep it, such as "claude"
	Title string // as people read it, such as "Claude"
	// Resume is the terminal command that opens one of its sessions, given
	// the session id.
	Resume string
	// ClientMCP says it takes the MCP servers a client names in session/new,
	// so its chats get Nushi's tools (ADR 0043).
	ClientMCP bool
	// DeleteArchives says its session/delete archives a session rather
	// than deleting it.
	DeleteArchives bool
	// OneWriter says the agent lets one process at a time write to a
	// session, so one open elsewhere isn't offered: Codex refuses a second
	// one, omp moves it to a new session.
	OneWriter bool
	// Expires says what deletes the agent's sessions on its own, such as
	// "Claude Code deletes sessions after 30 days by default"; "" if
	// nothing does.
	Expires string
	// NamesSessions says the agent titles a session itself, soon after its
	// first prompt (Claude, with a model call of its own that may end after
	// a short first turn): a worktree's branch waits for that title, a
	// turn at most, rather than take the prompt's line.
	NamesSessions bool
	// SubagentSessions says the agent can show its subagents as sessions
	// of their own (ACP's subagents RFD, which initialize advertises): it
	// then says when each ends, and stops one when its session is
	// cancelled.
	SubagentSessions bool
	// Redelete is how long after deleting a session nobody will see again
	// to delete it once more, for an agent that writes a little of it back
	// as it ends; 0 for once.
	Redelete time.Duration
	// InitMeta is its _meta beyond ACP in initialize's client capabilities.
	InitMeta map[string]any
	// SessionMeta is its _meta beyond ACP in session/new, session/load and
	// session/fork.
	SessionMeta map[string]any
	// UltracodeMeta joins SessionMeta (merged, key by key) in the sessions
	// of a chat with Ultracode on: the agent's standing multi-agent
	// workflows (Claude Code's ultracode). Nil when the agent has none: the
	// chat then has no Ultracode option.
	UltracodeMeta map[string]any
	// Moves says a chat's session can move to another folder: the agent's
	// session/fork with the new folder as its cwd finds the session
	// wherever it is (Claude's Go agent in any folder's history, Codex by
	// its id), so a moved chat forks it there (ADR 0014).
	Moves bool
	// OtherSuffix names the free-text "Other" answer the agent's forms put
	// after a question with choices: the field `<question's id><suffix>`,
	// with no choices of its own ("_custom": Claude's `color_custom`). ""
	// when its forms have none.
	OtherSuffix string
	// OtherNotes says how the agent reads that "Other" field's text beside
	// a pick (docs/facts): as an answer of its own, as a note on the pick
	// (on questions taking one choice, or on all of them), or in place of
	// a one-choice question's pick.
	OtherNotes OtherNotes
}

// OtherNotes is how an agent reads a question's "Other" text beside a
// pick (HarnessInfo.OtherNotes).
type OtherNotes int

// How a question's "Other" text is read beside a pick.
const (
	NotesOnNone   OtherNotes = iota // an answer of its own
	NotesOnOne                      // a note on a one-choice question's pick; with several, one more answer
	NotesOnAll                      // a note on the pick of any question with choices
	ReplacesOnOne                   // in place of a one-choice question's pick, which is dropped; with several, one more answer
)

// On says whether the "Other" text of a question of type t is a note on
// its pick.
func (n OtherNotes) On(t FieldType) bool {
	switch n {
	case NotesOnOne:
		return t == Choice
	case NotesOnAll:
		return t == Choice || t == Choices
	case NotesOnNone, ReplacesOnOne:
	}
	return false
}

// Replaces says whether the "Other" text of a question of type t, when
// not blank, takes the place of its pick.
func (n OtherNotes) Replaces(t FieldType) bool {
	return n == ReplacesOnOne && t == Choice
}

// Info is i itself, so a HarnessInfo is a harness.
func (i HarnessInfo) Info() HarnessInfo { return i }

// AgentRun is what starting an agent takes: its CLI, and with an adapter, the
// adapter's program and the Node on PATH that runs it; and the environment
// it starts with.
type AgentRun struct {
	CLI, Program, Node string
	Env                []string
}

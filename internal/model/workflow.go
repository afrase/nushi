package model

import "time"

// Workflow is a run a tool call launched: a script of the agent's that
// runs many subagents in phases, on past the call (Claude's Workflow tool,
// ADR 0127). Nothing here is the agent's: it is what Nushi read of the
// run's files, a summary small enough to ride on its item.
//
// State is "" while the run isn't followed (the call shows as a plain one),
// then "running", and at its end "done", "failed", "stopped" or "unknown"
// (it ended and didn't say how; End holds its word). End is the agent's own
// word for the end ("completed", "killed", "paused"…), or Nushi's when the
// agent gave none ("Claude quit while it ran").
//
// Started is when the run started, Ended when it ended (zero while it
// runs), Active when its files last changed. Phases are in the order
// first reached (or the agent's own list, at the end), 32 at most;
// Planned those its script plans (Claude's meta.phases) and it hasn't
// reached, in the script's order, with Phases 32 at most. Agents
// counts the run's agents, Done and Failed those that ended so; Running
// holds the labels of up to 8 that run now, RunningPhases the index in
// Phases of each one's phase (-1 for none), RunningCount how many do.
// Summary is how a failed run ended, in the agent's words (its error's
// first line), at most 2 KB. Tokens are what its agents used so far, as
// the agent counts a subagent's (Claude's totalTokens), 0 when not known;
// no agent reports a workflow's cost. Written are the files its agents
// wrote or edited with their file tools, the one changed last first,
// WorkflowWritten at most (WrittenFile). Worktrees are the worktrees
// Claude gave the run's subagents (WorkflowWorktree), WorkflowWorktrees at
// most: the daemon's own, never on the wire. Stalled says
// no file of the run changed for so long (an hour) that it no longer
// counts as working, though nothing says it ended; any change clears it.
//
// Session and Folder are where the run's files are: the agent's session
// and the chat's folder when the run was first followed. A Move or a
// rewind gives the chat another session, and the run's files stay with
// the one that launched it. Neither goes on the wire.
type Workflow struct {
	RunID, TaskID, Name, Description string
	Session, Folder                  string `json:",omitzero"`
	State                            RunState
	End                              string
	Started                          time.Time `json:",omitzero"`
	Ended                            time.Time `json:",omitzero"`
	Active                           time.Time `json:",omitzero"`
	Phases                           []WorkflowPhase
	Planned                          []WorkflowPhase `json:",omitempty"`
	Agents, Done, Failed             int
	Running                          []string
	RunningPhases                    []int `json:",omitempty"`
	RunningCount                     int
	Summary                          string
	Tokens                           int64              `json:",omitzero"`
	Stalled                          bool               `json:",omitzero"`
	Written                          []WrittenFile      `json:",omitempty"`
	Worktrees                        []WorkflowWorktree `json:",omitempty"`
}

// WorkflowWorktree is a worktree Claude gave one of a workflow's
// subagents, as the subagent's .meta.json names it (worktreePath, with
// spawnedWithWorktree true; docs/facts/claude.md): its path, absolute and
// cleaned, untrusted text Claude wrote (the sidecar keeps naming it after
// the worktree is gone), and Since, the time of the subagent's first
// transcript line (its transcript's time when that line has none).
type WorkflowWorktree struct {
	Path  string
	Since time.Time `json:",omitzero"`
}

// WrittenFile is a file a workflow's agents wrote or edited: its path as
// the agent's call named it, cleaned (relative to the chat's folder when
// inside it, as a chat's own calls name theirs; a relative one never
// leads out with ".."), untrusted plain text, and when
// the last call that changed it ended (zero when not known).
type WrittenFile struct {
	Path    string
	Changed time.Time `json:",omitzero"`
}

// WorkflowPhase is one phase of a workflow: its title and the agent's line
// on it, and how many of its agents started, ended well and failed.
type WorkflowPhase struct {
	Title, Detail         string
	Started, Done, Failed int
}

// WorkflowAgent is one agent of a workflow, as its pane lists it: never on
// an item and never kept. State is "running", "done", "failed" or
// "stopped". Prompt and Result are the starts of its task and its answer,
// as the agent kept them.
type WorkflowAgent struct {
	ID, Label, Phase, Model string
	State                   RunState
	Prompt, Result          string
	Started, Ended          time.Time
	Tokens, ToolCalls       int
}

// Limits of a workflow's summary on its item, so a run of a thousand agents
// stays small there (ADR 0127).
const (
	WorkflowPhases      = 32
	WorkflowRunning     = 8
	WorkflowLabel       = 60   // runes
	WorkflowSummaryText = 2048 // bytes
	WorkflowWritten     = 1000 // files, as a chat's own list has at most
	WorkflowWorktrees   = 256  // worktrees, a run's first
)

// Runs says the workflow runs and counts as the chat's work: running and
// not stalled.
func (w *Workflow) Runs() bool {
	return w != nil && w.State == RunRunning && !w.Stalled
}

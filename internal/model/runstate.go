package model

// RunState is how a run of the agent's goes: a subagent's (Subagent.State
// and Said), a background command's (BackgroundCommand.State), a
// workflow's and each of its agents' (Workflow.State, WorkflowAgent.State).
// It is a string on the wire, as the proto's comments list the values of
// each field; one set of names here, so each kind's code reads the same.
type RunState string

// The run states. Running, Done, Failed and Stopped are every kind's;
// Started is a background command's alone, Unknown a workflow's alone.
// "" is a kind's own "not yet": a subagent the agent never said of
// (Said), a workflow not followed.
const (
	RunRunning RunState = "running"
	RunDone    RunState = "done"
	RunFailed  RunState = "failed"
	RunStopped RunState = "stopped"
	// RunStarted is a background command whose end can't be known: its
	// agent is gone, or it started before the chat reopened, and it hasn't
	// said it ended. Not an end: it may still run.
	RunStarted RunState = "started"
	// RunUnknown is a workflow that ended without saying how (its End holds
	// the word).
	RunUnknown RunState = "unknown"
)

// Ended says the state is an end: done, failed, stopped or unknown.
func (s RunState) Ended() bool {
	switch s {
	case RunDone, RunFailed, RunStopped, RunUnknown:
		return true
	}
	return false
}

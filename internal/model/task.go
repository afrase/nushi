package model

// TaskUpdate is what an update of the agent's says of one of its tasks,
// in Nushi's words, whatever the agent calls them (ADR 0130, ADR 0127):
// the task's id; whose it is (Of); its State ("running", "done", "failed"
// or "stopped"; "" for a word Nushi doesn't know); End, how it ended, in
// the words its item keeps ("exited with code 0" or "killed" for a
// command, as its file's end line has them; "completed", "failed" or
// "killed" for a workflow, as Claude's snapshot has them; "" unsaid); and
// Summary, how a failed workflow ended, in the agent's words, secrets
// masked, at most WorkflowSummaryText bytes.
type TaskUpdate struct {
	ID      string
	Of      TaskOf
	State   RunState
	End     string
	Summary string
}

// TaskOf is whose a task is: a command left running in the background, a
// workflow's run, or "" for one Nushi doesn't read (Claude's foreground
// command that ran long is a command's).
type TaskOf string

// The kinds of task Nushi reads.
const (
	TaskCommand  TaskOf = "command"
	TaskWorkflow TaskOf = "workflow"
)

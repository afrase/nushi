package claude

import (
	"context"

	"github.com/afrase/claude-acp-go/claudeacp"
)

// EndTask stops one of Claude's tasks that has no session of its own (a
// background command, a workflow's run) through call, with the Go agent's
// _session/stopTask (claudeacp.StopTaskMethod): claude's stop_task, so no
// turn, no tokens and nothing in the conversation; claude itself tells
// the model of the stop at its next prompt (docs/facts/claude.md, ADR
// 0065). claude answers {} for any id, an ended task's too, so the answer
// isn't the task's end: its "killed", then "stopped", update on the call
// that started it is (Task), and it may come just after the answer.
func (Harness) EndTask(ctx context.Context, call func(ctx context.Context, method string, params, result any) error, sessionID, taskID string) error {
	return call(ctx, claudeacp.StopTaskMethod, claudeacp.StopTaskRequest{SessionID: sessionID, TaskID: taskID}, &claudeacp.StopTaskResponse{})
}

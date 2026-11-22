package claude

import (
	"regexp"
	"strings"
	"unicode/utf8"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/secrets"
)

// A workflow's ids as Claude writes them (docs/facts/claude.md): a run's
// "wf_" and a short hex id, its task's a few letters and digits. Both name
// files, so anything else is no workflow of Claude's.
var (
	runID  = regexp.MustCompile(`^wf_[A-Za-z0-9-]{1,64}$`)
	taskID = regexp.MustCompile(`^[A-Za-z0-9_-]{1,64}$`)
)

// ValidRunID says id is shaped as a workflow's run id: safe as a name in a
// path.
func ValidRunID(id string) bool { return runID.MatchString(id) }

// ValidTaskID says id is shaped as a task's id.
func ValidTaskID(id string) bool { return taskID.MatchString(id) }

// workflowCall reads a Workflow call's toolResponse (its PostToolUse hook's,
// in its _meta): the run it launched in the background. A response of
// another kind, or with ids not shaped as Claude's, is none: the call then
// shows as a plain one. Its transcriptDir and scriptPath are never used:
// the reader finds the files from the session (claudehistory).
func workflowCall(resp map[string]any) *model.Workflow {
	if s, _ := resp["taskType"].(string); s != "local_workflow" {
		return nil
	}
	str := func(k string) string { s, _ := resp[k].(string); return s }
	return launched(str("runId"), str("taskId"), str("workflowName"), str("summary"))
}

func launched(run, task, name, summary string) *model.Workflow {
	if !ValidRunID(run) || !ValidTaskID(task) {
		return nil
	}
	// The name and summary are the model's text: masked as a tool call's.
	return &model.Workflow{RunID: run, TaskID: task, Name: clip(secrets.MaskText(name), 200), Description: clip(secrets.MaskText(summary), model.WorkflowSummaryText)}
}

// LaunchedWorkflow reads the run a Workflow call launched from its output
// when no toolResponse came with it (a replay): "Workflow launched in
// background. Task ID: <id>", "Summary: <line>" and "Run ID: <id>" on lines
// of their own. Any other tool's call launched none, whatever its output
// says. The name isn't in it: the script's file says it, which isn't read
// here.
func (Harness) LaunchedWorkflow(call model.Item) *model.Workflow {
	if call.Tool != "Workflow" {
		return nil
	}
	output := call.Text
	if !strings.HasPrefix(strings.TrimSpace(output), "Workflow launched in background.") {
		return nil
	}
	var run, task, summary string
	for line := range strings.Lines(output) {
		line = strings.TrimSpace(line)
		switch {
		case strings.HasPrefix(line, "Run ID:"):
			run = strings.TrimSpace(strings.TrimPrefix(line, "Run ID:"))
		case strings.HasPrefix(line, "Summary:"):
			summary = strings.TrimSpace(strings.TrimPrefix(line, "Summary:"))
		case strings.HasPrefix(line, "Workflow launched in background."):
			_, after, _ := strings.Cut(line, "Task ID:")
			task = strings.TrimSpace(after)
		}
	}
	return launched(run, task, "", summary)
}

// clip cuts s to at most n bytes, at a rune's start.
func clip(s string, n int) string {
	if len(s) <= n {
		return s
	}
	for n > 0 && !utf8.RuneStart(s[n]) {
		n--
	}
	return s[:n]
}

package claude

import (
	"maps"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// launchText is a Workflow call's result as Claude 2.1.325 writes it (the
// workflow parity scenario), its paths shortened.
const launchText = "Workflow launched in background. Task ID: w9u1xb6ik\nSummary: Ask four helpers in two phases\n" +
	"Transcript dir: /x/subagents/workflows/wf_769a004c-2aa\nScript file: /x/workflows/scripts/two-phases-wf_769a004c-2aa.js\n" +
	"(Edit this file with Write/Edit and re-invoke Workflow with {scriptPath: \"/x\"} to iterate without resending the script.)\n" +
	"Run ID: wf_769a004c-2aa\nTo resume after editing the script: Workflow({scriptPath: \"/x\", resumeFromRunId: \"wf_769a004c-2aa\"})\n\n" +
	"You will be notified when it completes. Use /workflows to watch live progress."

func workflowMeta(resp map[string]any) map[string]any {
	return map[string]any{"claudeCode": map[string]any{"toolName": "Workflow", "toolResponse": resp}}
}

// The call's toolResponse names the run; each input form gives the same,
// and the paths in it are never kept.
func TestWorkflowCallReadsItsResponse(t *testing.T) {
	resp := map[string]any{"status": "async_launched", "taskId": "w9u1xb6ik", "taskType": "local_workflow", "workflowName": "two-phases",
		"runId": "wf_769a004c-2aa", "summary": "Ask four helpers", "transcriptDir": "/etc", "scriptPath": "/etc/passwd"}
	for _, in := range []string{`{"script":"export const meta = {}"}`, `{"scriptPath":"/x.js","resumeFromRunId":"wf_1"}`, `{"name":"review","args":[1]}`} {
		it := model.Item{}
		harness.ToolCall(&it, workflowMeta(resp), []byte(in))
		want := model.Workflow{RunID: "wf_769a004c-2aa", TaskID: "w9u1xb6ik", Name: "two-phases", Description: "Ask four helpers"}
		if it.Workflow == nil || it.Workflow.RunID != want.RunID || it.Workflow.TaskID != want.TaskID || it.Workflow.Name != want.Name ||
			it.Workflow.Description != want.Description || it.Workflow.State != "" || it.TaskID != "w9u1xb6ik" {
			t.Errorf("%s: got %+v (task %q)", in, it.Workflow, it.TaskID)
		}
	}
}

// A response of another kind, a failed call, ids not shaped as Claude's or
// another tool's response with the same task type are no workflow: the
// call stays a plain one.
func TestNoWorkflowWithoutARun(t *testing.T) {
	ok := map[string]any{"taskType": "local_workflow", "runId": "wf_abc", "taskId": "w1"}
	with := func(k string, v any) map[string]any {
		m := maps.Clone(ok)
		m[k] = v
		return m
	}
	for name, meta := range map[string]map[string]any{
		"agent task":  workflowMeta(with("taskType", "local_agent")),
		"no type":     workflowMeta(with("taskType", nil)),
		"failed":      workflowMeta(map[string]any{"status": "failed", "error": "Workflows are disabled"}),
		"path run":    workflowMeta(with("runId", "wf_../../etc")),
		"slash run":   workflowMeta(with("runId", "wf_a/b")),
		"bare run":    workflowMeta(with("runId", "wf_")),
		"upper run":   workflowMeta(with("runId", "WF_abc")),
		"long run":    workflowMeta(with("runId", "wf_"+strings.Repeat("a", 65))),
		"nul task":    workflowMeta(with("taskId", "w\x00")),
		"unicode":     workflowMeta(with("taskId", "wé")),
		"other tool":  {"claudeCode": map[string]any{"toolName": "Bash", "toolResponse": ok}},
		"no response": workflowMeta(nil),
	} {
		it := model.Item{}
		harness.ToolCall(&it, meta, nil)
		if it.Workflow != nil {
			t.Errorf("%s: a workflow %+v", name, it.Workflow)
		}
	}
}

// A replayed call has only its text: the ids come from its lines, in any
// order, with CRLF and trailing spaces; text that isn't a launch, or with a
// bad id, is none, and so is another tool's call whatever its output.
func TestLaunchedWorkflowFromItsText(t *testing.T) {
	call := func(text string) model.Item { return model.Item{Kind: model.ToolCall, Tool: "Workflow", Text: text} }
	w := harness.LaunchedWorkflow(call(launchText))
	if w == nil || w.RunID != "wf_769a004c-2aa" || w.TaskID != "w9u1xb6ik" || w.Description != "Ask four helpers in two phases" {
		t.Fatalf("got %+v", w)
	}
	crlf := "Workflow launched in background. Task ID: t1  \r\nRun ID: wf_x1  \r\nSummary: s\r\n"
	if w := harness.LaunchedWorkflow(call(crlf)); w == nil || w.RunID != "wf_x1" || w.TaskID != "t1" || w.Description != "s" {
		t.Errorf("CRLF: got %+v", w)
	}
	for _, text := range []string{"", "Async agent launched", strings.ReplaceAll(launchText, "wf_769a004c-2aa\nTo", "wf_../x\nTo"),
		"Workflow launched in background. Task ID: t1\n"} {
		if w := harness.LaunchedWorkflow(call(text)); w != nil {
			t.Errorf("%q: got %+v", text, w)
		}
	}
	echoed := model.Item{Kind: model.ToolCall, Tool: "Bash", Text: launchText}
	if w := harness.LaunchedWorkflow(echoed); w != nil {
		t.Errorf("a Bash call that printed a launch's words: got %+v", w)
	}
}

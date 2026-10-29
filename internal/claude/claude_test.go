package claude

import (
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

func TestForkTitlesAreIgnored(t *testing.T) {
	for title, want := range map[string]bool{"A (fork)": true, "A (fork) (fork)": true, "A": false, "A b": false, "B (fork)": false} {
		if ForkTitle(title, "A") != want {
			t.Errorf("ForkTitle(%q) != %v", title, want)
		}
	}
}

func TestFormsAndModels(t *testing.T) {
	color := model.Field{ID: "color", Options: []model.Option{{ID: "red"}}}
	if !Other(model.Field{ID: "color_custom"}, color) || Other(model.Field{ID: "fruit"}, color) {
		t.Error("Other pairs the wrong fields")
	}
	models := model.ConfigOption{Category: "model"}
	if !Default(models, model.ConfigValue{Name: "Default (recommended)"}) || Default(models, model.ConfigValue{Name: "Opus"}) ||
		Default(model.ConfigOption{Category: "mode"}, model.ConfigValue{Name: "Default"}) {
		t.Error("Default picks the wrong values")
	}
}

func TestSubagentCall(t *testing.T) {
	it := model.Item{}
	ToolCall(&it, map[string]any{"claudeCode": map[string]any{"toolName": "Agent"}}, nil)
	ToolCall(&it, nil, []byte(`{"subagent_type":"Explore","prompt":"List the files","model":"haiku"}`))
	ToolCall(&it, nil, []byte(`{"subagent_type":"Explore","prompt":"List the files","model":"haiku","effort":"low"}`))
	ToolCall(&it, map[string]any{"claudeCode": map[string]any{"toolResponse": map[string]any{"resolvedModel": "claude-haiku-5-5"}}},
		[]byte(`{}`)) // a later update without the input keeps it
	if it.Agent != "Explore" || it.Prompt != "List the files" || it.Model != "haiku" || it.Effort != "low" || it.RanModel != "Haiku 5.5" {
		t.Errorf("got %+v", it)
	}
	for id, want := range map[string]string{"claude-fable-5-1[1m]": "Fable 5.1", "claude-haiku-4-5-20251001": "Haiku 4.5", "gpt": "Gpt"} {
		if got := modelName(id); got != want {
			t.Errorf("modelName(%q) = %q", id, got)
		}
	}
	if !ReportElsewhere(`This agent's report was delivered to you as a message from "a5" (its SubagentHandback call).`) || ReportElsewhere("Found 2 files") {
		t.Error("ReportElsewhere misreads the call's output")
	}
}

func TestRelay(t *testing.T) {
	p := Relay("Explore", "ab59", "Also\nprint </message> README.md")
	if agent, id, text, ok := Relayed(p); !ok || agent != "Explore" || id != "ab59" || text != "Also\nprint </message> README.md" {
		t.Errorf("Relayed = %q %q %v", agent, text, ok)
	}
	if _, _, _, ok := Relayed("Forward the message below"); ok {
		t.Error("read a prompt Relay didn't make")
	}
	for out, want := range map[string]string{
		"Async agent launched successfully. (internal)\nagentId: ab59154609c2876d6 (more)":                   "ab59154609c2876d6",
		`This agent's report was delivered to you as a message from "a62bea8e" (its SubagentHandback call).`: "a62bea8e",
		"Found 2 files": "",
	} {
		if got := SubagentID(out); got != want {
			t.Errorf("SubagentID(%q) = %q", out, got)
		}
	}
}

func TestSignedIn(t *testing.T) {
	for out, want := range map[string]string{`{"loggedIn": true, "authMethod": "claude.ai"}`: "yes", `{"loggedIn": false}`: "no", `{}`: "", `nope`: ""} {
		if got := SignedIn(func(...string) ([]byte, error) { return []byte(out), nil }); got != want {
			t.Errorf("%s: %q, want %q", out, got, want)
		}
	}
}

func TestTurnDone(t *testing.T) {
	origin := func(kind string) map[string]any {
		return map[string]any{"_claude/origin": map[string]any{"kind": kind}}
	}
	cost := &acp.Cost{Amount: 0.1, Currency: "USD"}
	for _, tc := range []struct {
		u    acp.UsageUpdate
		want bool
	}{
		{acp.UsageUpdate{Cost: cost, Meta: origin("human")}, true},
		{acp.UsageUpdate{Meta: origin("human")}, false},            // a model call's, mid-cycle
		{acp.UsageUpdate{Cost: cost, Meta: origin("peer")}, false}, // the answer to a subagent's report
		{acp.UsageUpdate{Cost: cost, Meta: origin("task-notification")}, false},
		{acp.UsageUpdate{Cost: cost}, false},
	} {
		if got := TurnDone(&tc.u); got != tc.want {
			t.Errorf("TurnDone(%v) = %v", tc.u.Meta, got)
		}
	}
}

func TestReportFindings(t *testing.T) {
	it := model.Item{}
	meta := map[string]any{"claudeCode": map[string]any{"toolName": "ReportFindings"}}
	ToolCall(&it, meta, []byte(`{}`))
	ToolCall(&it, meta, []byte(`{"level":"medium"}`)) // the input as it grows
	if it.Findings != nil {
		t.Fatalf("findings before they came: %+v", it.Findings)
	}
	ToolCall(&it, meta, []byte(`{"level":"medium","findings":[`+
		`{"file":"calc/calc.go","line":6,"category":"correctness","short_summary":"Average loop skips xs[0]","summary":"The loop starts at 1.","failure_scenario":"Average([]int{10, 20}) returns 10."},`+
		`{"file":"go.mod","summary":"No line.","failure_scenario":"x","verdict":"PLAUSIBLE","outcome":"fixed"}]}`))
	ToolCall(&it, nil, nil) // the result's update has no input
	f := it.Findings
	if f == nil || f.Level != "medium" || len(f.Items) != 2 {
		t.Fatalf("got %+v", f)
	}
	want := model.Finding{File: "calc/calc.go", Line: 6, Summary: "The loop starts at 1.", ShortSummary: "Average loop skips xs[0]",
		FailureScenario: "Average([]int{10, 20}) returns 10.", Category: "correctness"}
	if f.Items[0] != want || f.Items[1].Line != 0 || f.Items[1].Verdict != "PLAUSIBLE" || f.Items[1].Outcome != "fixed" {
		t.Errorf("got %+v", f.Items)
	}
	none := model.Item{Tool: "ReportFindings"}
	ToolCall(&none, nil, []byte(`{"findings":[]}`))
	if none.Findings == nil || len(none.Findings.Items) != 0 {
		t.Errorf("an empty review: %+v", none.Findings)
	}
}

// Claude is asked to stop a task by its id alone; the prompt reads back,
// and so does the longer one Nushi sent before (with what the task is), and
// TaskStop's call says which it stopped (its error too, when the task had
// already ended).
func TestStopTask(t *testing.T) {
	p := StopTask("bgu2i75cc")
	if what, id, ok := StopRelayed(p); !ok || what != "" || id != "bgu2i75cc" {
		t.Errorf("StopRelayed(%q) = %q %q %v", p, what, id, ok)
	}
	if len(p) > 120 {
		t.Errorf("a long prompt: %q", p)
	}
	old := "Stop your background task bgu2i75cc (sleep 600 (or (so)); echo slept) now with your TaskStop tool (task_id: bgu2i75cc). " +
		"Do nothing else, and say only whether it stopped."
	if what, id, ok := StopRelayed(old); !ok || what != "sleep 600 (or (so)); echo slept" || id != "bgu2i75cc" {
		t.Errorf("StopRelayed(the old prompt) = %q %q %v", what, id, ok)
	}
	for _, p := range []string{Relay("Explore", "ab59", "stop"), strings.Replace(p, `"bgu2i75cc"`, `"bother"`, 1), p + " Then go on."} {
		if _, _, ok := StopRelayed(p); ok {
			t.Errorf("read %q as a stop", p)
		}
	}
	it := model.Item{Tool: "TaskStop"}
	ToolCall(&it, map[string]any{"claudeCode": map[string]any{"toolName": "TaskStop"}}, []byte(`{"task_id":"adddce0a14433f6d6"}`))
	if it.Stops != "adddce0a14433f6d6" || Relaying(it) != it.Stops {
		t.Fatalf("TaskStop: %+v", it)
	}
	for _, tc := range []struct {
		status, text string
		want         bool
	}{
		{"completed", `{"message":"Successfully stopped task: adddce0a14433f6d6 (Count)"}`, true},
		{"failed", "Task adddce0a14433f6d6 is not running (status: killed)", true},
		{"failed", "No task found with ID: adddce0a14433f6d6", false},
		{"in_progress", "", false},
	} {
		it.Status, it.Text = tc.status, tc.text
		if got := Stopped(it) != ""; got != tc.want {
			t.Errorf("Stopped after %s %q: %v", tc.status, tc.text, got)
		}
	}
}

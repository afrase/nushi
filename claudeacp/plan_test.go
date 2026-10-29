package claudeacp

import (
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// plans are the plan updates so far, each as status:content entries.
func (c *client) plans() []string {
	var out []string
	for _, u := range c.of("plan") {
		var es []string
		for _, e := range u.Plan.Entries {
			es = append(es, string(e.Status)+":"+e.Content)
		}
		out = append(out, strings.Join(es, ", "))
	}
	return out
}

// toolResult is claude's message with a tool's result; structured is its
// tool_use_result, if any.
func toolResult(id, content, structured string) claudetest.Step {
	line := `{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"` + id + `","content":` + content + `}]}`
	if structured != "" {
		line += `,"tool_use_result":` + structured
	}
	return sendf(line + "}")
}

// TodoWrite's list is the plan, an entry under way in its active form;
// the call isn't shown, unless a subagent makes it. The plan goes again
// as a prompt starts while some is left to do, and empties when the
// conversation starts over.
func TestTodoWrite(t *testing.T) {
	todos := `{"todos":[{"content":"Write tests","status":"completed","activeForm":"Writing tests"},` +
		`{"content":"Fix the bug","status":"in_progress","activeForm":"Fixing the bug"},{"content":"Ship","status":"pending","activeForm":"Shipping"}]}`
	read := make(chan struct{})
	f := fake(user("id2"), echo("id2"),
		event(`{"type":"message_start","message":{"id":"msg_1"}}`),
		event(`{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_1","name":"TodoWrite","input":{}}}`),
		delta("0", "input_json_delta", "partial_json", `{\"todos\":[]`),
		assistant(`{"type":"tool_use","id":"toolu_1","name":"TodoWrite","input":`+todos+`}`),
		hookCall("toolu_1", "TodoWrite", `{}`)[0], hookCall("toolu_1", "TodoWrite", `{}`)[1],
		toolResult("toolu_1", `"Todos have been modified"`, ""),
		claudetest.Send(`{"type":"assistant","parent_tool_use_id":"toolu_a","message":{"id":"msg_s","content":[{"type":"tool_use","id":"toolu_s","name":"TodoWrite","input":{"todos":[]}}]}}`),
		toolResult("toolu_s", `"ok"`, ""),
		result(names("id2")), claudetest.Send(idle),
		user("id3"), echo("id3"),
		claudetest.Send(`{"type":"conversation_reset","new_conversation_id":"c2","trigger":"clear"}`),
		result(names("id3")), claudetest.Send(idle), signal(read))
	p := start(t, nil, f)
	sid := p.open(t)
	if got := stopReason(p.prompt(t, sid, "go")); got != "end_turn" {
		t.Fatal(got)
	}
	stopReason(p.prompt(t, sid, "again"))
	wait(t, read, "the script")
	plan := "completed:Write tests, in_progress:Fixing the bug, pending:Ship"
	if got := p.plans(); !slices.Equal(got, []string{plan, plan, ""}) {
		t.Errorf("plans %q", got)
	}
	for _, u := range p.toolUpdates() {
		if !strings.Contains(u, `"toolCallId":"toolu_s"`) {
			t.Errorf("%s", u)
		}
	}
	if len(p.toolUpdates()) != 2 {
		t.Errorf("%q", p.toolUpdates())
	}
}

// The task tools make the plan from their results: a task created,
// changed, deleted, or the whole list listed. TaskGet changes nothing.
func TestTaskPlan(t *testing.T) {
	call := func(id, name, input string) claudetest.Step {
		return assistant(`{"type":"tool_use","id":"` + id + `","name":"` + name + `","input":` + input + `}`)
	}
	f := fake(user("id2"), echo("id2"),
		call("t1", "TaskCreate", `{"subject":"A","activeForm":"Doing A"}`),
		toolResult("t1", `"Task #1 created successfully: A"`, ""),
		call("t2", "TaskCreate", `{"subject":"B"}`),
		toolResult("t2", `"created"`, `{"task":{"id":2,"subject":"B"}}`),
		call("t3", "TaskUpdate", `{"taskId":"1","status":"in_progress"}`),
		toolResult("t3", `"Updated task #1 status"`, ""),
		call("t4", "TaskUpdate", `{"taskId":"2","status":"deleted"}`),
		toolResult("t4", `"Updated task #2 deleted"`, ""),
		call("t5", "TaskGet", `{"taskId":"1"}`),
		toolResult("t5", `"Task #1: A"`, ""),
		call("t6", "TaskList", `{}`),
		toolResult("t6", `[{"type":"text","text":"#1 [completed] A (main)\n#3 [pending] C [blocked by #1]"}]`, ""),
		result(names("id2")), claudetest.Send(idle))
	p := start(t, nil, f)
	if got := stopReason(p.prompt(t, p.open(t), "go")); got != "end_turn" {
		t.Fatal(got)
	}
	want := []string{
		"pending:A",
		"pending:A, pending:B",
		"in_progress:Doing A, pending:B",
		"in_progress:Doing A",
		"completed:A, pending:C",
	}
	if got := p.plans(); !slices.Equal(got, want) {
		t.Errorf("plans\n%q\nwant\n%q", got, want)
	}
	if got := p.toolUpdates(); len(got) != 0 {
		t.Errorf("%q", got)
	}
}

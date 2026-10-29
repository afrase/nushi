package claudeacp

import (
	"encoding/json"
	"errors"
	"maps"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// toolUpdates are the tool calls and their updates so far, as JSON.
func (c *client) toolUpdates() []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	var out []string
	for _, n := range c.updates {
		var v any
		switch u := n.Update; {
		case u.ToolCall != nil:
			v = u.ToolCall
		case u.ToolCallUpdate != nil:
			v = u.ToolCallUpdate
		default:
			continue
		}
		b, _ := json.Marshal(v)
		out = append(out, n.Update.SessionUpdate+" "+string(b))
	}
	return out
}

func sendf(frame string) claudetest.Step { return claudetest.Send(frame) }

// hookCall is claude running the PostToolUse hook for a tool, and taking
// its answer.
func hookCall(id, name, response string) []claudetest.Step {
	return []claudetest.Step{
		sendf(`{"type":"control_request","request_id":"h_` + id + `","request":{"subtype":"hook_callback","callback_id":"hook_0","tool_use_id":"` + id +
			`","input":{"hook_event_name":"PostToolUse","tool_name":"` + name + `","tool_use_id":"` + id + `","tool_response":` + response + `}}}`),
		claudetest.Expect(`{"type":"control_response","response":{"subtype":"success","request_id":"h_` + id + `"}}`),
	}
}

// An Agent call is shown as the model starts it, its input a field at a
// time as each completes, then whole with its content; the hook's update
// carries only claude's response; the result ends it. Each update sends
// what changed.
func TestToolLifecycle(t *testing.T) {
	steps := []claudetest.Step{user("id2"), echo("id2"),
		event(`{"type":"message_start","message":{"id":"msg_1","model":"m"}}`),
		event(`{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_1","name":"Agent","input":{}}}`),
		delta("0", "input_json_delta", "partial_json", `{\"description\":\"Look`),
		delta("0", "input_json_delta", "partial_json", `s, then\",\"subagent_type\":\"Explore\"`),
		delta("0", "input_json_delta", "partial_json", `,\"prompt\":\"find {x}\"`),
		delta("0", "input_json_delta", "partial_json", `}`),
		assistant(`{"type":"tool_use","id":"toolu_1","name":"Agent","input":{"description":"Looks, then","subagent_type":"Explore","prompt":"find {x}"}}`),
	}
	steps = append(steps, hookCall("toolu_1", "Agent", `{"agentId":"a1","resolvedModel":"claude-sonnet-5-5"}`)...)
	steps = append(steps,
		sendf(`{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":[{"type":"text","text":"Found.\n<usage>tokens: 5</usage>"}]}]}}`),
		result(names("id2")), claudetest.Send(idle))
	f := withTitle(claudetest.New(append([]claudetest.Step{
		claudetest.Expect(`{"type":"control_request","request":{"subtype":"initialize","hooks":{"PostToolUse":[{"hookCallbackIds":["hook_0"]}]}}}`),
		claudetest.Send(`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`),
	}, steps...)...), `null`)
	p := start(t, nil, f)
	if got := stopReason(p.prompt(t, p.open(t), "go")); got != "end_turn" {
		t.Fatal(got)
	}
	want := []string{
		`tool_call {"toolCallId":"toolu_1","title":"Agent","name":"Agent","kind":"think","status":"pending","rawInput":{},"_meta":{"claudeCode":{"toolName":"Agent"}}}`,
		`tool_call_update {"toolCallId":"toolu_1","title":"Looks, then","rawInput":{"description":"Looks, then"},"_meta":{"claudeCode":{"toolName":"Agent"}}}`,
		`tool_call_update {"toolCallId":"toolu_1","rawInput":{"description":"Looks, then","subagent_type":"Explore"},"_meta":{"claudeCode":{"toolName":"Agent"}}}`,
		`tool_call_update {"toolCallId":"toolu_1","content":[{"type":"content","content":{"type":"text","text":"find {x}"}}],"rawInput":{"description":"Looks, then","subagent_type":"Explore","prompt":"find {x}"},"_meta":{"claudeCode":{"toolName":"Agent"}}}`,
		`tool_call_update {"toolCallId":"toolu_1","_meta":{"claudeCode":{"toolName":"Agent","toolResponse":{"agentId":"a1","resolvedModel":"claude-sonnet-5-5"}}}}`,
		`tool_call_update {"toolCallId":"toolu_1","status":"completed","content":[{"type":"content","content":{"type":"text","text":"Found."}}],"rawOutput":[{"type":"text","text":"Found.\n\u003cusage\u003etokens: 5\u003c/usage\u003e"}],"_meta":{"claudeCode":{"toolName":"Agent"}}}`,
	}
	if got := p.toolUpdates(); !slices.Equal(got, want) {
		t.Errorf("got\n%s\nwant\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
}

// An edit's diff is the snippet until claude's response gives the hunks
// it made; a command's output is fenced, its progress shown once; a
// subagent's calls say whose they are; one claude refused fails.
func TestToolResults(t *testing.T) {
	steps := []claudetest.Step{user("id2"), echo("id2"),
		assistant(`{"type":"tool_use","id":"toolu_e","name":"Edit","input":{"file_path":"/w/a.go","old_string":"x","new_string":"y"}}`),
	}
	steps = append(steps, hookCall("toolu_e", "Edit", `{"filePath":"/w/a.go","structuredPatch":[{"oldStart":1,"lines":[" a","-x","+y"]}]}`)...)
	steps = append(steps,
		sendf(`{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_e","content":"ok"}]}}`),
		claudetest.Send(`{"type":"assistant","parent_tool_use_id":"toolu_p","message":{"id":"msg_2","content":[{"type":"tool_use","id":"toolu_b","name":"Bash","input":{"command":"go test"}}]}}`),
		sendf(`{"type":"tool_progress","tool_use_id":"toolu_b","tool_name":"Bash","elapsed_time_seconds":1}`),
		sendf(`{"type":"tool_progress","tool_use_id":"toolu_b","tool_name":"Bash","elapsed_time_seconds":2}`),
		sendf(`{"type":"user","parent_tool_use_id":"toolu_p","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_b","is_error":true,"content":"Exit code 1\nFAIL"}]}}`),
		assistant(`{"type":"tool_use","id":"toolu_w","name":"WebFetch","input":{"url":"https://x"}}`),
		sendf(`{"type":"system","subtype":"permission_denied","tool_use_id":"toolu_w","tool_name":"WebFetch","decision_reason":"a rule","message":"denied by a rule"}`),
		result(names("id2")), claudetest.Send(idle))
	p := start(t, nil, fake(steps...))
	if got := stopReason(p.prompt(t, p.open(t), "go")); got != "end_turn" {
		t.Fatal(got)
	}
	want := []string{
		`tool_call {"toolCallId":"toolu_e","title":"Edit /w/a.go","name":"Edit","kind":"edit","status":"pending","content":[{"type":"diff","path":"/w/a.go","oldText":"x","newText":"y"}],"locations":[{"path":"/w/a.go"}],"rawInput":{"file_path":"/w/a.go","old_string":"x","new_string":"y"},"_meta":{"claudeCode":{"toolName":"Edit"}}}`,
		`tool_call_update {"toolCallId":"toolu_e","content":[{"type":"diff","path":"/w/a.go","oldText":"a\nx","newText":"a\ny"}],"_meta":{"claudeCode":{"toolName":"Edit","toolResponse":{"filePath":"/w/a.go","structuredPatch":[{"lines":[" a","-x","+y"],"oldStart":1}]}}}}`,
		`tool_call_update {"toolCallId":"toolu_e","status":"completed","rawOutput":"ok","_meta":{"claudeCode":{"toolName":"Edit"}}}`,
		`tool_call {"toolCallId":"toolu_b","title":"go test","name":"Bash","kind":"execute","status":"pending","rawInput":{"command":"go test"},"_meta":{"claudeCode":{"parentToolUseId":"toolu_p","toolName":"Bash"}}}`,
		`tool_call_update {"toolCallId":"toolu_b","status":"in_progress","_meta":{"claudeCode":{"parentToolUseId":"toolu_p","toolName":"Bash"}}}`,
		"tool_call_update {\"toolCallId\":\"toolu_b\",\"status\":\"failed\",\"content\":[{\"type\":\"content\",\"content\":{\"type\":\"text\",\"text\":\"```console\\nExit code 1\\nFAIL\\n```\"}}],\"rawOutput\":\"Exit code 1\\nFAIL\",\"_meta\":{\"claudeCode\":{\"parentToolUseId\":\"toolu_p\",\"toolName\":\"Bash\"}}}",
		`tool_call {"toolCallId":"toolu_w","title":"Fetch https://x","name":"WebFetch","kind":"fetch","status":"pending","rawInput":{"url":"https://x"},"_meta":{"claudeCode":{"toolName":"WebFetch"}}}`,
		`tool_call_update {"toolCallId":"toolu_w","status":"failed","content":[{"type":"content","content":{"type":"text","text":"Permission denied: denied by a rule"}}],"_meta":{"claudeCode":{"toolName":"WebFetch","toolResponse":{"decisionReason":"a rule","decisionReasonType":"","message":"denied by a rule"}}}}`,
	}
	if got := p.toolUpdates(); !slices.Equal(got, want) {
		t.Errorf("got\n%s\nwant\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
}

// Calls a turn leaves open end with it: one the model never finished
// writing was never run; one claude ran with no result fails the turn;
// after a cancel, whether claude then goes idle or sends a result, each
// says the turn was cancelled.
func TestUnfinishedTools(t *testing.T) {
	started := event(`{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_1","name":"Read"}}`)
	for _, tc := range []struct {
		name   string
		steps  []claudetest.Step
		cancel bool
		want   string // the call's last update's text
		stop   string
	}{
		{"never ran", []claudetest.Step{started, result(names("id2"))}, false,
			"The model stopped before finishing this call; it never ran.", "end_turn"},
		{"no result", []claudetest.Step{started, assistant(`{"type":"tool_use","id":"toolu_1","name":"Read","input":{}}`), result(names("id2"))}, false,
			"The turn ended with no result for this call.", "error: Claude ended the turn without a tool's result."},
		{"cancelled", []claudetest.Step{started, claudetest.Expect(`{"type":"control_request","request":{"subtype":"interrupt"}}`),
			claudetest.Send(`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`),
			claudetest.Send(idle)}, true,
			"The turn was cancelled before this call had a result.", "cancelled"},
		{"cancelled, then a result", []claudetest.Step{started, claudetest.Expect(`{"type":"control_request","request":{"subtype":"interrupt"}}`),
			claudetest.Send(`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`),
			result(names("id2"))}, true,
			"The turn was cancelled before this call had a result.", "cancelled"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			at := make(chan struct{})
			steps := append([]claudetest.Step{user("id2"), echo("id2"),
				event(`{"type":"message_start","message":{"id":"msg_1"}}`), signal(at)}, tc.steps...)
			steps = append(steps, claudetest.Send(idle))
			f := withTitle(claudetest.New(append([]claudetest.Step{claudetest.Expect(initRequest),
				claudetest.Send(`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`)}, steps...)...), `null`)
			p := start(t, nil, f)
			sid := p.open(t)
			w := p.prompt(t, sid, "go")
			if tc.cancel {
				wait(t, at, "the message's start")
				eventually(t, "the call", func() bool { return len(p.of("tool_call")) == 1 })
				if err := p.Cancel(t.Context(), &acp.CancelNotification{SessionID: sid}); err != nil {
					t.Fatal(err)
				}
			}
			r, err := w()
			got := "error: "
			if e := (*acp.Error)(nil); errors.As(err, &e) {
				got += e.Message
			} else if err == nil {
				got = string(r.StopReason)
			}
			if got != tc.stop {
				t.Errorf("stop %q", got)
			}
			ups := p.of("tool_call_update")
			last := ups[len(ups)-1].ToolCallUpdate
			if last.Status != acp.ToolCallStatusFailed || last.Content[0].Content.Content.Text.Text != tc.want {
				t.Errorf("%+v", last)
			}
		})
	}
}

// A hook's report that comes while the call's input still streams waits
// for the whole input, and follows it.
func TestHookBeforeInput(t *testing.T) {
	at, release := make(chan struct{}), make(chan struct{})
	steps := []claudetest.Step{user("id2"), echo("id2"),
		event(`{"type":"message_start","message":{"id":"msg_1"}}`),
		event(`{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_1","name":"Bash","input":{}}}`),
		signal(at), claudetest.Until(release)}
	steps = append(steps, hookCall("toolu_1", "Bash", `{"stdout":"a"}`)...)
	steps = append(steps, assistant(`{"type":"tool_use","id":"toolu_1","name":"Bash","input":{"command":"ls"}}`),
		sendf(`{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"a"}]}}`),
		result(names("id2")), claudetest.Send(idle))
	p := start(t, nil, fake(steps...))
	w := p.prompt(t, p.open(t), "go")
	wait(t, at, "the call's start")
	eventually(t, "the call", func() bool { return len(p.of("tool_call")) == 1 })
	close(release)
	if got := stopReason(w); got != "end_turn" {
		t.Fatal(got)
	}
	ups := p.toolUpdates()
	whole := slices.IndexFunc(ups, func(u string) bool { return strings.Contains(u, `"rawInput":{"command":"ls"}`) })
	hook := slices.IndexFunc(ups, func(u string) bool { return strings.Contains(u, `"toolResponse"`) })
	if whole < 0 || hook < whole {
		t.Errorf("the whole input at %d, the hook's report at %d:\n%s", whole, hook, strings.Join(ups, "\n"))
	}
}

// A call a permission request showed whole stays so when its stream's
// start comes after.
func TestPermissionBeforeStream(t *testing.T) {
	f := fake(user("id2"), echo("id2"), canUseTool("toolu_1", "Bash", `{"command":"ls"}`, ""),
		answers("toolu_1", `{"behavior":"allow"}`),
		event(`{"type":"message_start","message":{"id":"msg_1"}}`),
		event(`{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_1","name":"Bash","input":{}}}`),
		assistant(`{"type":"tool_use","id":"toolu_1","name":"Bash","input":{"command":"ls"}}`),
		sendf(`{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"a"}]}}`),
		result(names("id2")), claudetest.Send(idle))
	p := start(t, nil, f)
	p.permit = pick(optAllowOnce)
	if got := stopReason(p.prompt(t, p.open(t), "go")); got != "end_turn" {
		t.Fatal(got)
	}
	for _, u := range p.toolUpdates() {
		if strings.Contains(u, `"rawInput":{}`) || strings.Contains(u, `"title":"Bash"`) {
			t.Errorf("the stream's start undid the request's call: %s", u)
		}
	}
}

// When claude exits every call still open ends saying so, a subagent's
// and a compaction's too: nothing else can end them now.
func TestExitEndsCalls(t *testing.T) {
	f := fake(user("id2"), echo("id2"),
		assistant(`{"type":"tool_use","id":"toolu_p","name":"Agent","input":{"prompt":"look"}}`),
		claudetest.Send(`{"type":"assistant","parent_tool_use_id":"toolu_p","message":{"id":"msg_2","content":[{"type":"tool_use","id":"toolu_s","name":"Bash","input":{"command":"ls"}}]}}`),
		sendf(`{"type":"system","subtype":"status","status":"compacting","uuid":"c1"}`),
		claudetest.Exit(1, ""))
	p := start(t, nil, f)
	if got := stopReason(p.prompt(t, p.open(t), "go")); !strings.Contains(got, "exited") {
		t.Error(got)
	}
	ended := map[string]string{}
	for _, u := range p.of("tool_call_update") {
		if c := u.ToolCallUpdate; c.Status == acp.ToolCallStatusFailed {
			ended[string(c.ToolCallID)] = c.Content[0].Content.Content.Text.Text
		}
	}
	if want := map[string]string{"toolu_p": exitedText, "toolu_s": exitedText, "c1": exitedText}; !maps.Equal(ended, want) {
		t.Errorf("%q", ended)
	}
}

// A cancel's backstop that comes once its turn has ended does nothing:
// the calls open since aren't its to end.
func TestLateBackstop(t *testing.T) {
	at, release := make(chan struct{}), make(chan struct{})
	f := fake(user("id2"), echo("id2"),
		event(`{"type":"message_start","message":{"id":"msg_1"}}`),
		event(`{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_1","name":"Read"}}`),
		signal(at), claudetest.Until(release), result(names("id2")), claudetest.Send(idle))
	p := start(t, nil, f)
	sid := p.open(t)
	w := p.prompt(t, sid, "go")
	wait(t, at, "the call's start")
	eventually(t, "the call", func() bool { return len(p.of("tool_call")) == 1 })
	s, err := p.agent.session(sid)
	if err != nil {
		t.Fatal(err)
	}
	over := newTurn("id0") // a cancelled turn that has since ended
	s.mu.Lock()
	s.settleLocked(over, cancelled(over))
	s.mu.Unlock()
	done := make(chan struct{})
	go func() {
		s.backstop(over)
		close(done)
	}()
	p.clock.fire(t, backstop)
	wait(t, done, "the backstop")
	s.tools.mu.Lock()
	call := s.tools.byID["toolu_1"]
	open := call != nil && !call.ended
	s.tools.mu.Unlock()
	if !open {
		t.Error("the backstop ended the call")
	}
	close(release)
	if got := stopReason(w); got != "end_turn" {
		t.Error(got)
	}
}

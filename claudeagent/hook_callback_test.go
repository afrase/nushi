package claudeagent_test

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

// Hooks go in initialize under their ids, and claude's callback by id
// reaches the hook with its input and gets the hook's answer; an id the
// session didn't register, or a hook's failure, is an error answer.
func TestHookCallback(t *testing.T) {
	inputs := make(chan claudeagent.HookInput, 1)
	post := func(_ context.Context, in claudeagent.HookInput) (claudeagent.HookOutput, error) {
		inputs <- in
		return claudeagent.HookOutput{Specific: map[string]any{"additionalContext": "seen"}}, nil
	}
	failing := func(context.Context, claudeagent.HookInput) (claudeagent.HookOutput, error) {
		return claudeagent.HookOutput{}, errors.New("hook broke")
	}
	f := claudetest.New(
		claudetest.Expect(`{"type":"control_request","request":{"subtype":"initialize","hooks":{`+
			`"PostToolUse":[{"hookCallbackIds":["hook_0"]}],"Stop":[{"hookCallbackIds":["hook_1"],"matcher":"x"}]}}}`),
		answer(`{}`),
		claudetest.Send(`{"type":"control_request","request_id":"c1","request":{"subtype":"hook_callback","callback_id":"hook_0","tool_use_id":"t1",`+
			`"input":{"hook_event_name":"PostToolUse","session_id":"s1","cwd":"/w","agent_id":"a1","tool_name":"Bash","tool_input":{"command":"ls"},"tool_response":{"stdout":"x","backgroundTaskId":"b1"}}}}`),
		expectAnswer(`{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"seen"}}`, ""),
		claudetest.Send(`{"type":"control_request","request_id":"c1","request":{"subtype":"hook_callback","callback_id":"hook_1","input":{"hook_event_name":"Stop"}}}`),
		expectAnswer("", "hook broke"),
		claudetest.Send(`{"type":"control_request","request_id":"c1","request":{"subtype":"hook_callback","callback_id":"hook_2","input":{}}}`),
		expectAnswer("", `claudeagent: no hook "hook_2"`),
	)
	s, err := claudeagent.Start(context.Background(), claudeagent.Options{
		CLIPath: "/claude", Env: []string{}, Spawner: f.Spawn,
		Hooks: map[claudeagent.HookEvent][]claudeagent.HookMatcher{
			claudeagent.HookPostToolUse: {{Fn: post}},
			claudeagent.HookStop:        {{Matcher: "x", Fn: failing}},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Close() })
	finish(t, s, f)
	var in claudeagent.HookInput
	select {
	case in = <-inputs:
	default:
		t.Fatal("the hook didn't run")
	}
	if in.Event != claudeagent.HookPostToolUse || in.SessionID != "s1" || in.Cwd != "/w" || in.AgentID != "a1" || in.ToolName != "Bash" ||
		in.ToolUseID != "t1" || string(in.ToolInput) != `{"command":"ls"}` || string(in.ToolResponse) != `{"stdout":"x","backgroundTaskId":"b1"}` {
		t.Errorf("%+v", in)
	}
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(in.Raw, &raw); err != nil || string(raw["tool_name"]) != `"Bash"` {
		t.Errorf("Raw %s", in.Raw)
	}
}

// A callback's deadline_ms ends the hook's ctx, since claude goes on
// without the answer rather than withdrawing the call; what the hook
// returns then isn't sent. A deadline still to come is the ctx's, and a
// call without one has none.
func TestHookDeadline(t *testing.T) {
	overran := make(chan error, 1)
	slow := func(ctx context.Context, _ claudeagent.HookInput) (claudeagent.HookOutput, error) {
		<-ctx.Done()
		overran <- ctx.Err()
		return claudeagent.HookOutput{Reason: "late"}, nil
	}
	deadlines := make(chan bool, 2)
	fast := func(ctx context.Context, _ claudeagent.HookInput) (claudeagent.HookOutput, error) {
		_, ok := ctx.Deadline()
		deadlines <- ok
		return claudeagent.HookOutput{}, nil
	}
	call := func(id, hook, deadline string) claudetest.Step {
		return claudetest.Send(`{"type":"control_request","request_id":"` + id + `","request":{"subtype":"hook_callback","callback_id":"` + hook + `"` +
			deadline + `,"input":{"hook_event_name":"Stop"}}}`)
	}
	answered := func(id string) claudetest.Step {
		return claudetest.Expect(`{"type":"control_response","response":{"subtype":"success","request_id":"` + id + `","response":{}}}`)
	}
	s, f := start(t, claudeagent.Options{Hooks: map[claudeagent.HookEvent][]claudeagent.HookMatcher{
		claudeagent.HookStop: {{Fn: slow}, {Fn: fast}},
	}},
		call("c1", "hook_0", `,"deadline_ms":1`),
		call("c2", "hook_1", `,"deadline_ms":600000`),
		answered("c2"),
		call("c3", "hook_1", ""),
		answered("c3"),
	)
	if err := <-overran; !errors.Is(err, context.DeadlineExceeded) {
		t.Errorf("the overrunning hook's ctx ended with %v", err)
	}
	finish(t, s, f) // the fake fails on an answer to c1, in the script or after it
	if a, b := <-deadlines, <-deadlines; !a || b {
		t.Errorf("deadlines seen: with deadline_ms %v, without %v", a, b)
	}
}

// A hook's ctx ends once its answer is written, with a deadline or
// without: what a context.AfterFunc of it writes reaches claude after the
// answer.
func TestHookContextEndsAfterAnswer(t *testing.T) {
	session := make(chan *claudeagent.Session, 1)
	ask := func(ctx context.Context, _ claudeagent.HookInput) (claudeagent.HookOutput, error) {
		context.AfterFunc(ctx, func() {
			s := <-session
			session <- s
			_, _ = s.Begin(context.WithoutCancel(ctx), "get_context_usage", struct{}{})
		})
		return claudeagent.HookOutput{}, nil
	}
	call := func(id, deadline string) []claudetest.Step {
		return []claudetest.Step{
			claudetest.Send(`{"type":"control_request","request_id":"` + id + `","request":{"subtype":"hook_callback","callback_id":"hook_0"` + deadline + `,"input":{}}}`),
			claudetest.Expect(`{"type":"control_response","response":{"subtype":"success","request_id":"` + id + `"}}`),
			claudetest.Expect(`{"type":"control_request","request":{"subtype":"get_context_usage"}}`),
		}
	}
	s, f := start(t, claudeagent.Options{Hooks: map[claudeagent.HookEvent][]claudeagent.HookMatcher{
		claudeagent.HookPostModelSwitch: {{Fn: ask}},
	}}, append(call("c1", ""), call("c2", `,"deadline_ms":600000`)...)...)
	session <- s
	finish(t, s, f)
}

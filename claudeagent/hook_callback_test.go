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

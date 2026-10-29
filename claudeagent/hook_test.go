package claudeagent

import (
	"context"
	"encoding/json"
	"testing"
	"time"
)

// Hooks are registered event by event in name order, each matcher under
// an id of its own; a matcher's empty pattern and zero timeout are left
// out.
func TestRegisterHooks(t *testing.T) {
	fn := func(name string) HookFunc {
		return func(_ context.Context, _ HookInput) (HookOutput, error) {
			return HookOutput{Reason: name}, nil
		}
	}
	wire, byID, err := registerHooks(map[HookEvent][]HookMatcher{
		HookPreToolUse:  {{Matcher: "Edit|Write", Timeout: 1500 * time.Millisecond, Fn: fn("pre")}},
		HookPostToolUse: {{Fn: fn("post all")}, {Matcher: "Bash", Timeout: 30 * time.Second, Fn: fn("post bash")}},
	})
	if err != nil {
		t.Fatal(err)
	}
	want := `{"PostToolUse":[{"hookCallbackIds":["hook_0"]},{"hookCallbackIds":["hook_1"],"matcher":"Bash","timeout":30}],` +
		`"PreToolUse":[{"hookCallbackIds":["hook_2"],"matcher":"Edit|Write","timeout":1.5}]}`
	if b, _ := json.Marshal(wire); string(b) != want {
		t.Errorf("%s", b)
	}
	for id, name := range map[string]string{"hook_0": "post all", "hook_1": "post bash", "hook_2": "pre"} {
		if out, _ := byID[id](context.Background(), HookInput{}); out.Reason != name {
			t.Errorf("%s runs %q", id, out.Reason)
		}
	}
	if len(byID) != 3 {
		t.Errorf("%d hooks", len(byID))
	}

	if wire, byID, err := registerHooks(nil); err != nil || len(wire) != 0 || len(byID) != 0 {
		t.Errorf("none: %v %v %v", wire, byID, err)
	}
	if _, _, err := registerHooks(map[HookEvent][]HookMatcher{HookStop: {{}}}); err == nil {
		t.Error("a hook with no Fn registered")
	}
}

// An answer has only what the hook set; an async one only that.
func TestHookAnswer(t *testing.T) {
	for _, tc := range []struct {
		name  string
		event HookEvent
		out   HookOutput
		want  string
	}{
		{"zero", HookPostToolUse, HookOutput{}, `{}`},
		{"stop", HookStop, HookOutput{Stop: true, StopReason: "done", SuppressOutput: true, SystemMessage: "careful"},
			`{"continue":false,"stopReason":"done","suppressOutput":true,"systemMessage":"careful"}`},
		{"block", HookPreToolUse, HookOutput{Decision: "block", Reason: "not here"}, `{"decision":"block","reason":"not here"}`},
		{"specific", HookPreToolUse, HookOutput{Specific: map[string]any{"permissionDecision": "deny", "hookEventName": "Wrong"}},
			`{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny"}}`},
		{"async", HookPostToolUse, HookOutput{Async: true, AsyncTimeout: 2 * time.Second, Reason: "dropped"}, `{"async":true,"asyncTimeout":2000}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if b, _ := json.Marshal(hookAnswer(tc.event, tc.out)); string(b) != tc.want {
				t.Errorf("%s", b)
			}
		})
	}
}

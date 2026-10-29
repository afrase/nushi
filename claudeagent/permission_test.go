package claudeagent

import (
	"context"
	"encoding/json"
	"testing"
)

// An answer always names the tool call; an allow always carries the
// input, a deny a message.
func TestPermissionAnswer(t *testing.T) {
	asked := PermissionRequest{ToolUseID: "t1", Input: json.RawMessage(`{"command":"ls"}`)}
	for _, tc := range []struct {
		name   string
		r      PermissionRequest
		result PermissionResult
		want   string
	}{
		{"allow", asked, Allow{}, `{"behavior":"allow","toolUseID":"t1","updatedInput":{"command":"ls"}}`},
		{"allow changed", asked, Allow{UpdatedInput: json.RawMessage(`{"command":"pwd"}`), UpdatedPermissions: []json.RawMessage{json.RawMessage(`{"type":"setMode","mode":"plan"}`)}, Classification: "user_permanent"},
			`{"behavior":"allow","decisionClassification":"user_permanent","toolUseID":"t1","updatedInput":{"command":"pwd"},"updatedPermissions":[{"type":"setMode","mode":"plan"}]}`},
		{"allow no input", PermissionRequest{ToolUseID: "t1"}, Allow{}, `{"behavior":"allow","toolUseID":"t1","updatedInput":{}}`},
		{"deny", asked, Deny{}, `{"behavior":"deny","message":"Permission denied","toolUseID":"t1"}`},
		{"deny and stop", asked, Deny{Message: "no", Interrupt: true, Classification: "user_reject"},
			`{"behavior":"deny","decisionClassification":"user_reject","interrupt":true,"message":"no","toolUseID":"t1"}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			a, err := permissionAnswer(tc.r, tc.result)
			if err != nil {
				t.Fatal(err)
			}
			if b, _ := json.Marshal(a); string(b) != tc.want {
				t.Errorf("%s", b)
			}
		})
	}
	if _, err := permissionAnswer(asked, nil); err == nil {
		t.Error("no result answered")
	}
}

// The request's fields reach CanUseTool, flags and the MCP server in
// either of their shapes.
func TestPermissionRequest(t *testing.T) {
	for _, tc := range []struct {
		raw  string
		want PermissionRequest
	}{
		{`{"tool_name":"Bash","input":{"a":1},"tool_use_id":"t1","permission_suggestions":[{"type":"addRules"}],"blocked_path":"/x","decision_reason":"r","agent_id":"a1","title":"T","display_name":"D","description":"d","matched_ask_rule":true,"default_to_no":true,"mcp_server":{"name":"jira","source":"user"}}`,
			PermissionRequest{ToolName: "Bash", ToolUseID: "t1", BlockedPath: "/x", DecisionReason: "r", AgentID: "a1", Title: "T", DisplayName: "D", Description: "d", MatchedAskRule: true, DefaultToNo: true, MCPServer: "jira"}},
		{`{"tool_name":"mcp__s__t","matched_ask_rule":{"rule":"x"},"suppress_always_allow_rule":false,"default_to_no":null,"mcp_server":"s"}`,
			PermissionRequest{ToolName: "mcp__s__t", MatchedAskRule: true, MCPServer: "s"}},
	} {
		var got PermissionRequest
		s := &Session{o: Options{CanUseTool: func(_ context.Context, r PermissionRequest) (PermissionResult, error) {
			got = r
			return Deny{}, nil
		}}}
		if _, err := s.canUseTool(context.Background(), json.RawMessage(tc.raw)); err != nil {
			t.Fatal(err)
		}
		if string(got.Raw) != tc.raw {
			t.Errorf("Raw %s", got.Raw)
		}
		got.Raw, got.Input, got.Suggestions = nil, nil, nil
		if g, w := pretty(got), pretty(tc.want); g != w {
			t.Errorf("got %s, want %s", g, w)
		}
	}
}

func pretty(v any) string {
	b, _ := json.Marshal(v)
	return string(b)
}

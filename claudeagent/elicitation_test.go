package claudeagent

import (
	"context"
	"encoding/json"
	"testing"
)

// The request's fields reach OnElicitation; a property order of another
// shape is passed over, not a failure.
func TestElicitationRequest(t *testing.T) {
	for _, tc := range []struct {
		raw  string
		want ElicitationRequest
	}{
		{`{"subtype":"elicitation","mcp_server_name":"jira","message":"Pick","mode":"form","requested_schema":{"type":"object"},"property_order":["b","a"],"title":"T","display_name":"D","description":"d"}`,
			ElicitationRequest{ServerName: "jira", Message: "Pick", Mode: "form", RequestedSchema: json.RawMessage(`{"type":"object"}`), PropertyOrder: []string{"b", "a"}, Title: "T", DisplayName: "D", Description: "d"}},
		{`{"subtype":"elicitation","mcp_server_name":"gh","message":"Sign in","mode":"url","url":"https://example.com/x","elicitation_id":"e1","property_order":{"odd":true}}`,
			ElicitationRequest{ServerName: "gh", Message: "Sign in", Mode: "url", URL: "https://example.com/x", ElicitationID: "e1"}},
	} {
		var got ElicitationRequest
		s := &Session{o: Options{OnElicitation: func(_ context.Context, r ElicitationRequest) (ElicitationResult, error) {
			got = r
			return ElicitationResult{Action: ElicitationCancel}, nil
		}}}
		a, err := s.elicitation(context.Background(), json.RawMessage(tc.raw))
		if err != nil {
			t.Fatal(err)
		}
		if b, _ := json.Marshal(a); string(b) != `{"action":"cancel"}` {
			t.Errorf("answered %s", b)
		}
		if string(got.Raw) != tc.raw {
			t.Errorf("Raw %s", got.Raw)
		}
		got.Raw = nil
		if g, w := pretty(got), pretty(tc.want); g != w {
			t.Errorf("got %s, want %s", g, w)
		}
	}
}

// An answer is its action, with a form's values only on an accept; an
// action that isn't one of MCP's is an error.
func TestElicitationAnswer(t *testing.T) {
	values := map[string]any{"question_0": "Yes", "n": 2}
	for _, tc := range []struct {
		name   string
		result ElicitationResult
		want   string
	}{
		{"accept", ElicitationResult{Action: ElicitationAccept, Content: values}, `{"action":"accept","content":{"n":2,"question_0":"Yes"}}`},
		{"accept url", ElicitationResult{Action: ElicitationAccept}, `{"action":"accept"}`},
		{"decline", ElicitationResult{Action: ElicitationDecline, Content: values}, `{"action":"decline"}`},
		{"cancel", ElicitationResult{Action: ElicitationCancel}, `{"action":"cancel"}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			a, err := elicitationAnswer(tc.result)
			if err != nil {
				t.Fatal(err)
			}
			if b, _ := json.Marshal(a); string(b) != tc.want {
				t.Errorf("%s", b)
			}
		})
	}
	for _, action := range []ElicitationAction{"", "maybe"} {
		if _, err := elicitationAnswer(ElicitationResult{Action: action}); err == nil {
			t.Errorf("%q answered", action)
		}
	}
}

package claudeacp

import (
	"context"
	"errors"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// An MCP server's form or page goes to a client that shows it, as it
// asked (a form's fields in its order), and the answer back; one the
// client can't show is declined, as is one it fails to. A page's end is
// passed on.
func TestMCPElicitation(t *testing.T) {
	form := `{"type":"control_request","request_id":"e1","request":{"subtype":"elicitation","mcp_server_name":"jira","message":"Which?","mode":"form",` +
		`"requested_schema":{"properties":{"b":{"type":"string"},"a":{"type":"boolean"}}},"property_order":["a","b"]}}`
	page := `{"type":"control_request","request_id":"e1","request":{"subtype":"elicitation","mcp_server_name":"jira","message":"Sign in","mode":"url","url":"https://sign.in","elicitation_id":"el1"}}`
	forms := &acp.ElicitationCapabilities{Form: &acp.ElicitationFormCapabilities{}}
	pages := &acp.ElicitationCapabilities{URL: &acp.ElicitationURLCapabilities{}}
	accept := &acp.CreateElicitationResponse{Accept: &acp.ElicitationAcceptAction{Content: map[string]acp.ElicitationContentValue{
		"a": {Boolean: new(true)}, "b": {String: new("x")}}}}
	for _, tc := range []struct {
		name, request, answer string
		caps                  *acp.ElicitationCapabilities
		resp                  *acp.CreateElicitationResponse
		err                   error
		want                  string // what the client was asked
	}{
		{"form", form, `{"action":"accept","content":{"a":true,"b":"x"}}`, forms, accept, nil, "form a b"},
		{"form declined", form, `{"action":"decline"}`, forms, &acp.CreateElicitationResponse{Decline: true}, nil, "form a b"},
		{"form cancelled", form, `{"action":"cancel"}`, forms, &acp.CreateElicitationResponse{Cancel: true}, nil, "form a b"},
		{"form failed", form, `{"action":"decline"}`, forms, nil, errors.New("no"), "form a b"},
		{"no forms", form, `{"action":"decline"}`, pages, nil, nil, ""},
		{"page", page, `{"action":"accept"}`, pages, &acp.CreateElicitationResponse{Accept: &acp.ElicitationAcceptAction{}}, nil, "url el1 https://sign.in"},
		{"no pages", page, `{"action":"decline"}`, forms, nil, nil, ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := fake(sendf(tc.request),
				claudetest.Expect(`{"type":"control_response","response":{"subtype":"success","request_id":"e1","response":`+tc.answer+`}}`),
				sendf(`{"type":"system","subtype":"elicitation_complete","mcp_server_name":"jira","elicitation_id":"el1"}`))
			p := start(t, &acp.ClientCapabilities{Elicitation: tc.caps}, f)
			var asked string
			p.elicit = func(_ context.Context, req *acp.CreateElicitationRequest) (*acp.CreateElicitationResponse, error) {
				switch {
				case req.Form != nil:
					names := []string{"form"}
					for _, p := range req.Form.RequestedSchema.Properties {
						names = append(names, p.Name)
					}
					asked = strings.Join(names, " ")
					if req.Form.RequestedSchema.Type != acp.ElicitationSchemaTypeObject {
						asked += " (no object)"
					}
				case req.URL != nil:
					asked = "url " + string(req.URL.ElicitationID) + " " + req.URL.URL
				}
				return tc.resp, tc.err
			}
			p.open(t)
			<-f.Played()
			if asked != tc.want {
				t.Errorf("asked %q", asked)
			}
			done := tc.caps == pages
			eventually(t, "the page's end", func() bool {
				p.mu.Lock()
				defer p.mu.Unlock()
				return !done || slices.Equal(p.completed, []acp.ElicitationID{"el1"})
			})
		})
	}
}

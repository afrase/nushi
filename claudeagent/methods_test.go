package claudeagent_test

import (
	"context"
	"encoding/json"
	"errors"
	"regexp"
	"testing"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

// Each method sends its request and reads its answer.
func TestRequests(t *testing.T) {
	ctx := context.Background()
	for _, tc := range []struct {
		name     string
		init     string // initialize's answer
		request  string // the request's fields, matched
		response string // the answer's payload
		call     func(*claudeagent.Session) (any, error)
		want     string // the result, as JSON; "" for none
	}{
		{"set_permission_mode", `{}`, `{"subtype":"set_permission_mode","mode":"plan"}`, `{}`,
			func(s *claudeagent.Session) (any, error) { return nil, s.SetPermissionMode(ctx, claudeagent.Plan) }, ""},
		{"set_model", `{}`, `{"subtype":"set_model","model":"opus"}`, `{}`,
			func(s *claudeagent.Session) (any, error) { return nil, s.SetModel(ctx, "opus") }, ""},
		{"set_model default", `{}`, `{"subtype":"set_model","model":null}`, `{}`,
			func(s *claudeagent.Session) (any, error) { return nil, s.SetModel(ctx, "") }, ""},
		{"apply_flag_settings", `{}`, `{"subtype":"apply_flag_settings","settings":{"effortLevel":"high","ultracode":true}}`, `{}`,
			func(s *claudeagent.Session) (any, error) {
				return nil, s.ApplyFlagSettings(ctx, map[string]any{"effortLevel": "high", "ultracode": true})
			}, ""},
		{"stop_task", `{}`, `{"subtype":"stop_task","task_id":"t1"}`, `{}`,
			func(s *claudeagent.Session) (any, error) { return nil, s.StopTask(ctx, "t1") }, ""},
		{"cancel_async_message", `{}`, `{"subtype":"cancel_async_message","message_uuid":"u1"}`, `{"cancelled":true}`,
			func(s *claudeagent.Session) (any, error) { return nil, s.CancelAsyncMessage(ctx, "u1") }, ""},
		{"mcp_toggle", `{}`, `{"subtype":"mcp_toggle","serverName":"jira","enabled":false}`, `{}`,
			func(s *claudeagent.Session) (any, error) { return nil, s.MCPToggle(ctx, "jira", false) }, ""},
		{"mcp_reconnect", `{}`, `{"subtype":"mcp_reconnect","serverName":"jira"}`, `{}`,
			func(s *claudeagent.Session) (any, error) { return nil, s.MCPReconnect(ctx, "jira") }, ""},
		{"mcp_status", `{}`, `{"subtype":"mcp_status"}`, `{"mcpServers":[{"name":"jira","status":"failed","error":"401","tools":[]}]}`,
			func(s *claudeagent.Session) (any, error) {
				st, err := s.MCPServers(ctx)
				return []string{st[0].Name, st[0].Status, st[0].Error, string(st[0].Raw)}, err
			}, `["jira","failed","401","{\"name\":\"jira\",\"status\":\"failed\",\"error\":\"401\",\"tools\":[]}"]`},
		{"get_context_usage", `{}`, `{"subtype":"get_context_usage","detail":"summary"}`, `{"categories":[{"name":"Messages","tokens":5}],"totalTokens":5,"rawMaxTokens":1000000}`,
			func(s *claudeagent.Session) (any, error) {
				u, err := s.ContextUsage(ctx, "summary")
				return []any{u.Categories[0].Name, u.TotalTokens, u.RawMaxTokens, len(u.Raw) > 0}, err
			}, `["Messages",5,1000000,true]`},
		{"rewind_files", `{}`, `{"subtype":"rewind_files","user_message_id":"u1","dry_run":true}`, `{"canRewind":true,"filesChanged":["a.go"],"insertions":2}`,
			func(s *claudeagent.Session) (any, error) {
				r, err := s.RewindFiles(ctx, "u1", true)
				return []any{r.CanRewind, r.FilesChanged, r.Insertions}, err
			}, `[true,["a.go"],2]`},
		{"interrupt with a receipt", `{"capabilities":["interrupt_receipt_v1"]}`, `{"subtype":"interrupt"}`, `{"still_queued":["u2"]}`,
			func(s *claudeagent.Session) (any, error) {
				r, err := s.Interrupt(ctx)
				return []any{r.Known, r.StillQueued}, err
			}, `[true,["u2"]]`},
		{"interrupt without", `{}`, `{"subtype":"interrupt"}`, `{"still_queued":["u2"]}`,
			func(s *claudeagent.Session) (any, error) {
				r, err := s.Interrupt(ctx)
				return []any{r.Known, r.StillQueued, string(r.Raw)}, err
			}, `[false,null,"{\"still_queued\":[\"u2\"]}"]`},
		{"any", `{}`, `{"subtype":"get_settings","sources":["user"]}`, `{"effective":{"model":"m"}}`,
			func(s *claudeagent.Session) (any, error) {
				var v struct{ Effective map[string]string }
				err := s.Request(ctx, "get_settings", map[string]any{"sources": []string{"user"}}, &v)
				return v.Effective, err
			}, `{"model":"m"}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s, f := startWith(t, claudeagent.Options{}, tc.init,
				claudetest.Expect(`{"type":"control_request","request":`+tc.request+`}`),
				answer(tc.response),
			)
			got, err := tc.call(s)
			if err != nil {
				t.Fatal(err)
			}
			if tc.want != "" {
				b, _ := json.Marshal(got)
				if string(b) != tc.want {
					t.Errorf("%s", b)
				}
			}
			finish(t, s, f)
		})
	}
}

// Send writes the user line as the SDKs do, a person's by default, and
// returns its uuid, which claude echoes.
func TestSend(t *testing.T) {
	s, f := start(t, claudeagent.Options{},
		claudetest.Expect(`{"type":"user","session_id":"","uuid":"u-1","origin":{"kind":"human"},"message":{"role":"user","content":"hi"},"parent_tool_use_id":null}`),
		claudetest.Expect(`{"type":"user","origin":{"kind":"peer","from":"x"},"priority":"now","shouldQuery":false,"parent_tool_use_id":"toolu_1","message":{"content":[{"type":"text","text":"a"},{"type":"image","source":{"type":"base64"}}]}}`),
		claudetest.Send(`{"type":"user","uuid":"$uuid","isReplay":true}`),
	)
	ctx := context.Background()
	if id, err := s.Send(ctx, claudeagent.UserInput{Text: "hi", UUID: "u-1"}); err != nil || id != "u-1" {
		t.Fatal(id, err)
	}
	id, err := s.Send(ctx, claudeagent.UserInput{
		Content: []claudeagent.Block{
			{Type: "text", Text: "a"},
			{Raw: json.RawMessage(`{"type":"image","source":{"type":"base64"}}`)},
		},
		Origin:   &claudeagent.Origin{Raw: json.RawMessage(`{"kind":"peer","from":"x"}`)},
		Priority: "now", NoQuery: true, ParentToolUseID: "toolu_1",
	})
	if err != nil || !regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`).MatchString(id) {
		t.Fatal(id, err)
	}
	if u, ok := next(t, s).(*claudeagent.User); !ok || u.UUID != id || !u.IsReplay {
		t.Errorf("%+v", u)
	}
	for _, in := range []claudeagent.UserInput{{}, {Text: "a", Content: []claudeagent.Block{{Type: "text"}}}} {
		if _, err := s.Send(ctx, in); err == nil {
			t.Errorf("%+v sent", in)
		}
	}
	finish(t, s, f)
	if _, err := s.Send(ctx, claudeagent.UserInput{Text: "a"}); !errors.Is(err, claudeagent.ErrClosed) {
		t.Errorf("after the close: %v", err)
	}
}

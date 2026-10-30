package claudeagent

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"
)

// decodeCase is a stdout line and the message it decodes to.
type decodeCase struct {
	line string
	want Message
}

// The lines are shaped as claude 2.1.312's schema says, with fields the
// package doesn't model left in to show they're kept in Raw.
func TestDecode(t *testing.T) {
	checkDecode(t, []decodeCase{
		{
			`{"type":"assistant","message":{"id":"msg_1","type":"message","role":"assistant","model":"claude-opus-5","content":[{"type":"text","text":"Hi"},{"type":"thinking","thinking":"hm","signature":"sig"},{"type":"tool_use","id":"tu_1","name":"Bash","input":{"command":"ls"}},{"type":"redacted_thinking","data":"abc"}],"stop_reason":null,"usage":{"input_tokens":3,"output_tokens":4}},"parent_tool_use_id":null,"uuid":"u1","session_id":"s1","request_id":"r1"}`,
			&Assistant{Message: APIMessage{ID: "msg_1", Role: "assistant", Model: "claude-opus-5", Content: Blocks{
				{Type: "text", Text: "Hi"}, {Type: "thinking", Thinking: "hm", Signature: "sig"},
				{Type: "tool_use", ID: "tu_1", Name: "Bash", Input: json.RawMessage(`{"command":"ls"}`)}, {Type: "redacted_thinking"},
			}, Usage: &Usage{InputTokens: 3, OutputTokens: 4}}},
		},
		{
			`{"type":"assistant","message":{"id":"msg_2","role":"assistant","model":"m","content":[],"stop_reason":"refusal","stop_details":{"explanation":"no"}},"parent_tool_use_id":"tu_9","error":"rate_limit","agent_id":"a1","uuid":"u2","session_id":"s1"}`,
			&Assistant{Message: APIMessage{ID: "msg_2", Role: "assistant", Model: "m", Content: Blocks{}, StopReason: "refusal",
				StopDetails: json.RawMessage(`{"explanation":"no"}`)}, ParentToolUseID: "tu_9", Error: "rate_limit", AgentID: "a1"},
		},
		{
			`{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"tu_1","content":"out","is_error":true}]},"parent_tool_use_id":null,"tool_use_result":{"stdout":"out"},"uuid":"u3","session_id":"s1"}`,
			&User{Message: struct {
				Role    string `json:"role"`
				Content Blocks `json:"content"`
			}{"user", Blocks{{Type: "tool_result", ToolUseID: "tu_1", Content: json.RawMessage(`"out"`), IsError: true}}},
				ToolUseResult: json.RawMessage(`{"stdout":"out"}`)},
		},
		{
			`{"type":"user","message":{"role":"user","content":"hello"},"isReplay":true,"origin":{"kind":"human","x":1},"timestamp":"2026-10-29T00:00:00Z","uuid":"u4","session_id":"s1"}`,
			&User{Message: struct {
				Role    string `json:"role"`
				Content Blocks `json:"content"`
			}{"user", Blocks{{Type: "text", Text: "hello"}}}, IsReplay: true, Origin: &Origin{Kind: "human"}, Timestamp: "2026-10-29T00:00:00Z"},
		},
		{
			`{"type":"result","subtype":"success","duration_ms":10,"duration_api_ms":8,"is_error":false,"num_turns":2,"result":"Done","stop_reason":"end_turn","total_cost_usd":0.25,"usage":{"input_tokens":1,"output_tokens":2,"cache_read_input_tokens":3,"cache_creation_input_tokens":4},"modelUsage":{"claude-opus-5[1m]":{"inputTokens":1,"outputTokens":2,"cacheReadInputTokens":3,"cacheCreationInputTokens":4,"contextWindow":1000000,"costUSD":0.25}},"permission_denials":[],"origin":{"kind":"human"},"user_message_uuids":["p1","p2"],"fast_mode_state":"off","ttft_ms":3,"uuid":"u5","session_id":"s1"}`,
			&Result{Result: "Done", StopReason: "end_turn", DurationMS: 10, DurationAPIMS: 8, NumTurns: 2, TotalCostUSD: 0.25,
				Usage: Usage{1, 2, 3, 4}, ModelUsage: map[string]ModelUsage{"claude-opus-5[1m]": {1, 2, 3, 4, 1000000, 0.25}},
				PermissionDenials: json.RawMessage(`[]`), Origin: &Origin{Kind: "human"}, UserMessageUUIDs: []string{"p1", "p2"}, FastModeState: "off"},
		},
		{
			`{"type":"result","subtype":"error_during_execution","duration_ms":1,"duration_api_ms":0,"is_error":true,"num_turns":0,"errors":["boom"],"terminal_reason":"x","user_message_uuid":"p3","uuid":"u6","session_id":"s1"}`,
			&Result{IsError: true, Errors: []string{"boom"}, TerminalReason: "x", DurationMS: 1, UserMessageUUID: "p3"},
		},
		{
			`{"type":"stream_event","event":{"type":"message_start","message":{"id":"msg_3","role":"assistant","model":"m","content":[],"usage":{"input_tokens":9,"output_tokens":0}}},"parent_tool_use_id":null,"uuid":"u7","session_id":"s1"}`,
			&StreamEvent{Event: Event{Type: "message_start", Message: &APIMessage{ID: "msg_3", Role: "assistant", Model: "m", Content: Blocks{}, Usage: &Usage{InputTokens: 9}}}},
		},
		{
			`{"type":"stream_event","event":{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"tu_2","name":"Read","input":{}}},"parent_tool_use_id":"tu_9","uuid":"u8","session_id":"s1"}`,
			&StreamEvent{Event: Event{Type: "content_block_start", Index: 1, ContentBlock: &Block{Type: "tool_use", ID: "tu_2", Name: "Read", Input: json.RawMessage(`{}`)}}, ParentToolUseID: "tu_9"},
		},
		{
			`{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\"pa"}},"uuid":"u9","session_id":"s1"}`,
			&StreamEvent{Event: Event{Type: "content_block_delta", Delta: &Delta{Type: "input_json_delta", PartialJSON: `{"pa`}}},
		},
		{
			`{"type":"stream_event","event":{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":7}},"uuid":"u10","session_id":"s1"}`,
			&StreamEvent{Event: Event{Type: "message_delta", Delta: &Delta{StopReason: "end_turn"}, Usage: &Usage{OutputTokens: 7}}},
		},
		{
			`{"type":"tool_progress","tool_use_id":"tu_1","tool_name":"Bash","parent_tool_use_id":null,"elapsed_time_seconds":1.5,"task_id":"t1","uuid":"u11","session_id":"s1"}`,
			&ToolProgress{ToolUseID: "tu_1", ToolName: "Bash", ElapsedTimeSeconds: 1.5, TaskID: "t1"},
		},
		{
			`{"type":"rate_limit_event","rate_limit_info":{"status":"allowed_warning","resetsAt":1},"uuid":"u12","session_id":"s1"}`,
			&RateLimit{Info: json.RawMessage(`{"status":"allowed_warning","resetsAt":1}`)},
		},
		{
			`{"type":"conversation_reset","new_conversation_id":"s2","trigger":"clear","uuid":"u13","session_id":"s1"}`,
			&ConversationReset{NewConversationID: "s2", Trigger: "clear"},
		},
		{
			`{"type":"auth_status","isAuthenticating":true,"output":["Opening a browser"],"uuid":"u14","session_id":"s1"}`,
			&AuthStatus{IsAuthenticating: true, Output: []string{"Opening a browser"}},
		},
	})
}

// checkDecode decodes each case's line and compares the message with its
// want, whose envelope it fills from the line.
func checkDecode(t *testing.T, cases []decodeCase) {
	t.Helper()
	for _, tc := range cases {
		got, err := Decode([]byte(tc.line))
		if err != nil {
			t.Errorf("%.60s: %v", tc.line, err)
			continue
		}
		var e Envelope
		if err := json.Unmarshal([]byte(tc.line), &e); err != nil {
			t.Fatal(err)
		}
		e.Raw = json.RawMessage(tc.line)
		*tc.want.Frame() = e
		clearRaw(got)
		if !reflect.DeepEqual(got, tc.want) {
			t.Errorf("%.60s:\n got %+v\nwant %+v", tc.line, got, tc.want)
		}
	}
}

// clearRaw drops the blocks', origins' and MCP servers' Raw, which the
// table leaves out.
func clearRaw(m Message) {
	noRaw := func(bs Blocks) {
		for i := range bs {
			bs[i].Raw = nil
		}
	}
	switch m := m.(type) {
	case *SystemInit:
		for i := range m.MCPServers {
			m.MCPServers[i].Raw = nil
		}
	case *Assistant:
		noRaw(m.Message.Content)
	case *User:
		noRaw(m.Message.Content)
		if m.Origin != nil {
			m.Origin.Raw = nil
		}
	case *Result:
		if m.Origin != nil {
			m.Origin.Raw = nil
		}
	case *StreamEvent:
		if m.Event.ContentBlock != nil {
			m.Event.ContentBlock.Raw = nil
		}
		if m.Event.Message != nil {
			noRaw(m.Event.Message.Content)
		}
	}
}

// What the package doesn't model, or doesn't decode as modelled, comes
// through as Unknown with every byte; only a line with no type fails.
func TestDecodeUnknown(t *testing.T) {
	for _, tc := range []struct {
		line, typ, subtype string
		decodeErr          bool
	}{
		{`{"type":"prompt_suggestion","suggestion":"Next?","uuid":"u1","session_id":"s1"}`, "prompt_suggestion", "", false},
		{`{"type":"system","subtype":"turn_duration","ms":4,"uuid":"u2"}`, "system", "turn_duration", false},
		{`{"type":"control_request","request_id":"r1","request":{"subtype":"can_use_tool"}}`, "control_request", "", false},
		{`{"type":"result","subtype":"success","is_error":"no"}`, "result", "success", true},
	} {
		m, err := Decode([]byte(tc.line))
		if err != nil {
			t.Fatalf("%s: %v", tc.line, err)
		}
		u, ok := m.(*Unknown)
		if !ok {
			t.Fatalf("%s: %T", tc.line, m)
		}
		if u.Type != tc.typ || u.Subtype != tc.subtype || string(u.Raw) != tc.line || (u.Err != nil) != tc.decodeErr {
			t.Errorf("%s: %+v", tc.line, u)
		}
	}
	for _, line := range []string{`{"subtype":"init"}`, `{"type":7}`, `[1]`, `{"type":"user"`, `nope`} {
		if m, err := Decode([]byte(line)); err == nil {
			t.Errorf("%s: %+v", line, m)
		}
	}
}

// Blocks and origins pass through unchanged, fields the package doesn't
// know included; a string's content is a text block.
func TestBlocksPassThrough(t *testing.T) {
	m, err := Decode([]byte(`{"type":"user","message":{"role":"user","content":[{"type":"image","source":{"type":"base64","data":"QQ=="},"cache_control":{"type":"ephemeral"}}]},"origin":{"kind":"peer","from":"x"}}`))
	if err != nil {
		t.Fatal(err)
	}
	u := m.(*User)
	b, _ := json.Marshal(u.Message.Content)
	if want := `[{"type":"image","source":{"type":"base64","data":"QQ=="},"cache_control":{"type":"ephemeral"}}]`; string(b) != want {
		t.Errorf("content %s", b)
	}
	if o, _ := json.Marshal(u.Origin); string(o) != `{"kind":"peer","from":"x"}` {
		t.Errorf("origin %s", o)
	}
	if o, _ := json.Marshal(Origin{Kind: "human"}); string(o) != `{"kind":"human"}` {
		t.Errorf("a new origin %s", o)
	}
	var bs Blocks
	if err := json.Unmarshal([]byte(`"hi"`), &bs); err != nil || len(bs) != 1 || bs[0].Text != "hi" || !strings.Contains(mustJSON(t, bs), `"text":"hi"`) {
		t.Errorf("%+v %v", bs, err)
	}
}

func mustJSON(t *testing.T, v any) string {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

package fakeapi

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

// sse is a server-sent event as a client reads it.
type sse struct {
	name string
	data map[string]any
}

// post sends a request for a reply to srv and returns the response.
func post(ctx context.Context, t *testing.T, url, key, body string) *http.Response {
	t.Helper()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url+"/v1/messages?beta=true", strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("X-Api-Key", key)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	return resp
}

// readSSE reads a stream's events, checking each is framed as the API
// frames them: an event line, a data line, a blank line.
func readSSE(t *testing.T, r io.Reader) []sse {
	t.Helper()
	var out []sse
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		name, ok := strings.CutPrefix(sc.Text(), "event: ")
		if !ok {
			t.Fatalf("not an event line: %q", sc.Text())
		}
		if !sc.Scan() {
			t.Fatal("an event without data")
		}
		data, ok := strings.CutPrefix(sc.Text(), "data: ")
		if !ok {
			t.Fatalf("not a data line: %q", sc.Text())
		}
		var d map[string]any
		if err := json.Unmarshal([]byte(data), &d); err != nil {
			t.Fatalf("data isn't JSON: %q", data)
		}
		if d["type"] != name {
			t.Fatalf("event %s has data of type %v", name, d["type"])
		}
		out = append(out, sse{name, d})
		if !sc.Scan() || sc.Text() != "" {
			t.Fatalf("event %s isn't ended by a blank line", name)
		}
	}
	return out
}

const withTools = `{"model":"claude-test","stream":true,"tools":[{"name":"Bash"}],"messages":[{"role":"user","content":"list the files"}]}`

func TestStream(t *testing.T) {
	s := &Script{Turns: []Turn{{Content: []Block{
		{Type: "thinking", Thinking: "Let me look."},
		{Type: "text", Deltas: []string{"Looking ", "now."}},
		{Type: "tool_use", Name: "Bash", Input: json.RawMessage(`{"command":"ls -l"}`)},
	}}}}
	srv := httptest.NewServer(New(s, nil))
	defer srv.Close()
	resp := post(context.Background(), t, srv.URL, "dummy", withTools)
	defer resp.Body.Close() //nolint:errcheck // a test's response
	if ct := resp.Header.Get("Content-Type"); ct != "text/event-stream" {
		t.Fatalf("Content-Type %q", ct)
	}
	evs := readSSE(t, resp.Body)
	var names []string
	for _, e := range evs {
		name := e.name
		if d, ok := e.data["delta"].(map[string]any); ok && e.name == "content_block_delta" {
			name += ":" + d["type"].(string)
		}
		names = append(names, name)
	}
	want := []string{"message_start", "ping",
		"content_block_start", "content_block_delta:thinking_delta", "content_block_delta:signature_delta", "content_block_stop",
		"content_block_start", "content_block_delta:text_delta", "content_block_delta:text_delta", "content_block_stop",
		"content_block_start", "content_block_delta:input_json_delta", "content_block_delta:input_json_delta", "content_block_stop",
		"message_delta", "message_stop"}
	if !reflect.DeepEqual(names, want) {
		t.Fatalf("events\n%v\nwant\n%v", names, want)
	}
	msg := evs[0].data["message"].(map[string]any)
	if msg["model"] != "claude-test" || msg["role"] != "assistant" || !strings.HasPrefix(msg["id"].(string), "msg_fake_") {
		t.Errorf("message_start %v", msg)
	}
	var input strings.Builder
	for _, e := range evs[11:13] {
		input.WriteString(e.data["delta"].(map[string]any)["partial_json"].(string))
	}
	if input.String() != `{"command":"ls -l"}` {
		t.Errorf("the input streamed as %q", input.String())
	}
	tool := evs[10].data["content_block"].(map[string]any)
	if tool["name"] != "Bash" || !strings.HasPrefix(tool["id"].(string), "toolu_fake_") {
		t.Errorf("tool_use start %v", tool)
	}
	delta := evs[14].data["delta"].(map[string]any)
	usage := evs[14].data["usage"].(map[string]any)
	if delta["stop_reason"] != "tool_use" || usage["output_tokens"].(float64) < 1 {
		t.Errorf("message_delta %v", evs[14].data)
	}
}

func TestPick(t *testing.T) {
	no := false
	s := &Script{
		Turns: []Turn{
			{Match: &Match{LastUserText: "hello"}, Content: []Block{{Type: "tool_use", Name: "Bash"}}},
			{Match: &Match{ToolResult: "Bash"}, Content: []Block{{Type: "text", Text: "done"}}},
			{Match: &Match{Tools: &no, System: "compact"}, Content: []Block{{Type: "text", Text: "summary"}}},
		},
		Side: []Turn{{Match: &Match{Model: "haiku", Tools: &no, LastUserText: "topic"}, Content: []Block{{Type: "text", Text: "a topic"}}}},
	}
	f := New(s, nil)
	srv := httptest.NewServer(f)
	defer srv.Close()
	steps := []struct {
		name, body, answer, text string
	}{
		{"a side request doesn't take a turn", `{"model":"claude-haiku","messages":[{"role":"user","content":"title this"}]}`, "canned", "Fake title"},
		{"a side turn", `{"model":"claude-haiku","messages":[{"role":"user","content":"a topic?"}]}`, "side 0", "a topic"},
		{"a turn that doesn't match is a miss", `{"model":"m","tools":[{"name":"Bash"}],"messages":[{"role":"user","content":"bye"}]}`, "miss", "fakeapi: no turn of the script matches this request."},
		{"the first turn", `{"model":"m","tools":[{"name":"Bash"}],"messages":[{"role":"user","content":[{"type":"text","text":"<reminder/>"},{"type":"text","text":"hello"}]}]}`, "turn 0", ""},
		{"the side turn again", `{"model":"claude-haiku","messages":[{"role":"user","content":"topic"}]}`, "side 0", "a topic"},
		{"a tool's result", `{"model":"m","tools":[{"name":"Bash"}],"messages":[{"role":"user","content":"hello"},{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{}}]},{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"ok"}]}]}`, "turn 1", "done"},
		{"a turn without tools", `{"model":"m","system":[{"type":"text","text":"compact this"}],"messages":[{"role":"user","content":"x"}]}`, "turn 2", "summary"},
		{"a forced tool gets its input's shape", `{"model":"claude-haiku","tools":[{"name":"t","input_schema":{"properties":{"title":{"type":"string"},"new":{"type":"boolean"}}}}],"tool_choice":{"type":"tool","name":"t"},"messages":[{"role":"user","content":"x"}]}`, "canned", ""},
	}
	for i, st := range steps {
		resp := post(context.Background(), t, srv.URL, "", st.body)
		var msg struct {
			StopReason string `json:"stop_reason"`
			Content    []struct {
				Type  string         `json:"type"`
				Text  string         `json:"text"`
				Input map[string]any `json:"input"`
			} `json:"content"`
		}
		if err := json.NewDecoder(resp.Body).Decode(&msg); err != nil {
			t.Fatalf("%s: %v", st.name, err)
		}
		_ = resp.Body.Close()
		if got := f.Served()[i].Answer; got != st.answer {
			t.Errorf("%s: answered by %q, want %q", st.name, got, st.answer)
		}
		if st.text != "" && (len(msg.Content) != 1 || msg.Content[0].Text != st.text) {
			t.Errorf("%s: got %+v", st.name, msg)
		}
		if st.name == "a forced tool gets its input's shape" && !reflect.DeepEqual(msg.Content[0].Input, map[string]any{"title": "Fake title", "new": false}) {
			t.Errorf("%s: got %+v", st.name, msg)
		}
	}
	if f.Left() != 0 || len(f.Misses()) != 1 {
		t.Errorf("left %d, misses %v", f.Left(), f.Misses())
	}
}

func TestOtherCalls(t *testing.T) {
	f := New(&Script{Turns: []Turn{{Error: &APIError{Status: 529, Type: "overloaded_error", Message: "Overloaded"}}}}, nil)
	srv := httptest.NewServer(f)
	defer srv.Close()
	call := func(method, path, key, body string) (int, map[string]any) {
		req, _ := http.NewRequestWithContext(context.Background(), method, srv.URL+path, strings.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+key)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close() //nolint:errcheck // a test's response
		var out map[string]any
		_ = json.NewDecoder(resp.Body).Decode(&out)
		return resp.StatusCode, out
	}
	tests := []struct {
		name, method, path, key, body string
		status                        int
		check                         func(map[string]any) bool
	}{
		{"a real-looking key is refused", "POST", "/v1/messages", "sk-ant-api03-abc", withTools, 401,
			func(m map[string]any) bool { return m["error"].(map[string]any)["type"] == "authentication_error" }},
		{"an error turn", "POST", "/v1/messages", "dummy", withTools, 529,
			func(m map[string]any) bool { return m["error"].(map[string]any)["type"] == "overloaded_error" }},
		{"count_tokens", "POST", "/v1/messages/count_tokens?beta=true", "", withTools, 200,
			func(m map[string]any) bool { return m["input_tokens"].(float64) > 0 }},
		{"models", "GET", "/v1/models?limit=100", "", "", 200,
			func(m map[string]any) bool { return len(m["data"].([]any)) == 3 }},
		{"a model", "GET", "/v1/models/claude-x", "", "", 200,
			func(m map[string]any) bool { return m["id"] == "claude-x" }},
		{"anything else", "GET", "/api/oauth/profile", "", "", 404,
			func(m map[string]any) bool { return m["type"] == "error" }},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			status, body := call(tt.method, tt.path, tt.key, tt.body)
			if status != tt.status || !tt.check(body) {
				t.Errorf("got %d %v", status, body)
			}
		})
	}
	for _, s := range f.Served() {
		if strings.Contains(s.Model+s.Path+s.Answer, "sk-ant") {
			t.Errorf("a key was kept: %+v", s)
		}
	}
}

// A hanging turn streams its blocks and stops until the client goes, as
// a reply cut short by a cancel.
func TestHang(t *testing.T) {
	f := New(&Script{Turns: []Turn{{Hang: true, Content: []Block{{Type: "text", Text: "partial"}}}}}, nil)
	url, stop, err := f.Start(context.Background(), "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer func() {
		if err := stop(); err != nil {
			t.Error(err)
		}
	}()
	ctx, cancel := context.WithCancel(context.Background())
	resp := post(ctx, t, url, "dummy", withTools)
	defer resp.Body.Close() //nolint:errcheck // a test's response
	br := bufio.NewReader(resp.Body)
	for {
		line, err := br.ReadString('\n')
		if err != nil {
			t.Fatal(err)
		}
		if strings.HasPrefix(line, "event: content_block_stop") {
			break
		}
		if strings.HasPrefix(line, "event: message_delta") {
			t.Fatal("a hanging turn ended")
		}
	}
	cancel()
	if _, err := io.ReadAll(br); err == nil {
		t.Error("the stream ended on its own")
	}
}

func TestStartOnlyOnLoopback(t *testing.T) {
	if _, _, err := New(&Script{}, nil).Start(context.Background(), "0.0.0.0:0"); err == nil {
		t.Error("listened beyond loopback")
	}
}

func TestLoad(t *testing.T) {
	dir := t.TempDir()
	write := func(name, s string) string {
		p := filepath.Join(dir, name)
		if err := os.WriteFile(p, []byte(s), 0o600); err != nil {
			t.Fatal(err)
		}
		return p
	}
	write("api.json", `{"turns":[{"content":[{"type":"text","text":"hi"}]}]}`)
	s, err := Load(dir)
	if err != nil || len(s.Turns) != 1 || s.Turns[0].Content[0].Text != "hi" {
		t.Errorf("a scenario's folder: %+v, %v", s, err)
	}
	for _, bad := range []string{`{"turns":[{"content":[{"type":"image"}]}]}`, `{"turns":[{"content":[{"type":"tool_use"}]}]}`, `{`} {
		if _, err := Load(write("bad.json", bad)); err == nil {
			t.Errorf("%s loaded", bad)
		}
	}
}

// A turn can take an id only claude knows from the conversation, a task's
// say, into its reply; it doesn't match until the id is there. A turn's
// own message id stands for a numbered one.
func TestCapture(t *testing.T) {
	stop := &Turn{
		ID:    "msg_stop",
		Match: &Match{Capture: map[string]string{"task": `with ID: (\w+)`}},
		Content: []Block{
			{Type: "text", Text: "Stopping ${task}."},
			{Type: "tool_use", Name: "TaskStop", Input: json.RawMessage(`{"task_id":"${task}"}`), Deltas: []string{`{"task_id":`, `"${task}"}`}},
		},
	}
	f := New(&Script{Turns: []Turn{*stop}}, nil)
	srv := httptest.NewServer(f)
	defer srv.Close()
	ask := func(body string) map[string]any {
		resp := post(context.Background(), t, srv.URL, "", body)
		defer resp.Body.Close() //nolint:errcheck // a test's response
		var msg map[string]any
		if err := json.NewDecoder(resp.Body).Decode(&msg); err != nil {
			t.Fatal(err)
		}
		return msg
	}
	ask(`{"model":"m","tools":[{"name":"Bash"}],"messages":[{"role":"user","content":"stop it"}]}`)
	if f.Left() != 1 {
		t.Fatal("a turn whose capture finds nothing matched")
	}
	msg := ask(`{"model":"m","tools":[{"name":"Bash"}],"messages":[{"role":"user","content":"go"},` +
		`{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{}}]},` +
		`{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":[{"type":"text","text":"Running with ID: b1."}]}]},` +
		`{"role":"user","content":[{"type":"tool_result","tool_use_id":"t2","content":"Running with ID: b2."}]}]}`)
	content, _ := msg["content"].([]any)
	if len(content) != 2 || msg["id"] != "msg_stop" || content[0].(map[string]any)["text"] != "Stopping b2." ||
		!reflect.DeepEqual(content[1].(map[string]any)["input"], map[string]any{"task_id": "b2"}) {
		t.Errorf("got %v", msg)
	}
	rep := newReply(stop, "m", 1, f.newID, map[string]string{"task": `a"b`})
	body, _ := rep.events()
	var input strings.Builder
	for _, ev := range body {
		if d, ok := ev.data.(blockDelta); ok {
			if in, ok := d.Delta.(inputDelta); ok {
				input.WriteString(in.PartialJSON)
			}
		}
	}
	if input.String() != `{"task_id":"a\"b"}` {
		t.Errorf("the input streamed as %s", input.String())
	}
	if stop.Content[0].Text != "Stopping ${task}." {
		t.Error("the script changed")
	}
	p := filepath.Join(t.TempDir(), "api.json")
	if err := os.WriteFile(p, []byte(`{"turns":[{"match":{"capture":{"x":"no group"}}}]}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := Load(p); err == nil {
		t.Error("a capture without a group loaded")
	}
}

func TestStartCancelled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, _, err := New(&Script{}, nil).Start(ctx, "127.0.0.1:0"); !errors.Is(err, context.Canceled) {
		t.Errorf("started on a cancelled context: %v", err)
	}
}

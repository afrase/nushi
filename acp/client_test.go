package acp

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"strings"
	"testing"
)

type recorder struct{ updates []SessionNotification }

func (r *recorder) SessionUpdate(n SessionNotification) { r.updates = append(r.updates, n) }

// RequestPermission picks the last option.
func (r *recorder) RequestPermission(_ context.Context, req RequestPermissionRequest) (*RequestPermissionResponse, error) {
	opt := req.Options[len(req.Options)-1].OptionID
	return &RequestPermissionResponse{Outcome: RequestPermissionOutcome{Outcome: "selected", Selected: &SelectedPermissionOutcome{OptionID: opt}}}, nil
}

// fakeAgent answers each request with reply(method, params), after sending
// the notifications it returns.
func fakeAgent(t *testing.T, reply func(method string, params json.RawMessage) (notes []string, result string)) (*Client, *recorder, func()) {
	t.Helper()
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	go func() {
		sc := bufio.NewScanner(toAgentR)
		for sc.Scan() {
			var f frame
			if err := json.Unmarshal(sc.Bytes(), &f); err != nil {
				t.Errorf("agent got bad frame: %v", err)
				return
			}
			notes, result := reply(f.Method, f.Params)
			for _, n := range notes {
				io.WriteString(fromAgentW, `{"jsonrpc":"2.0","method":"session/update","params":`+n+"}\n")
			}
			io.WriteString(fromAgentW, `{"jsonrpc":"2.0","id":`+string(f.ID)+`,"result":`+result+"}\n")
		}
	}()
	rec := &recorder{}
	return Connect(fromAgentR, toAgentW, rec), rec, func() { fromAgentW.Close() }
}

func TestPromptStreamsUpdatesBeforeTheResponse(t *testing.T) {
	big := strings.Repeat("x", 200_000) // longer than any default line buffer
	c, rec, stop := fakeAgent(t, func(method string, params json.RawMessage) ([]string, string) {
		switch method {
		case "session/new":
			return nil, `{"sessionId":"s1"}`
		case "session/prompt":
			var p PromptRequest
			if err := json.Unmarshal(params, &p); err != nil || p.Prompt[0].Text == nil || p.Prompt[0].Text.Text != "hi" {
				t.Errorf("prompt params = %s (%v)", params, err)
			}
			chunk := func(s string) string {
				return `{"sessionId":"s1","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"` + s + `"}}}`
			}
			return []string{chunk("Hello"), chunk(big)}, `{"stopReason":"end_turn"}`
		}
		return nil, `{}`
	})
	defer stop()
	ctx := context.Background()

	sess, err := c.NewSession(ctx, NewSessionRequest{Cwd: "/tmp", MCPServers: []MCPServer{}})
	if err != nil || sess.SessionID != "s1" {
		t.Fatalf("NewSession = %+v, %v", sess, err)
	}
	resp, err := c.Prompt(ctx, PromptRequest{SessionID: "s1", Prompt: []ContentBlock{{Type: "text", Text: &TextContent{Text: "hi"}}}})
	if err != nil || resp.StopReason != StopReasonEndTurn {
		t.Fatalf("Prompt = %+v, %v", resp, err)
	}
	if len(rec.updates) != 2 {
		t.Fatalf("got %d updates before the response, want 2", len(rec.updates))
	}
	u := rec.updates[1].Update
	if u.SessionUpdate != "agent_message_chunk" || u.AgentMessageChunk.Content.Text.Text != big {
		t.Errorf("second update = %+v", u)
	}
}

func TestCallFailsWhenTheAgentExits(t *testing.T) {
	c, _, stop := fakeAgent(t, func(string, json.RawMessage) ([]string, string) { return nil, `{}` })
	stop()
	<-c.Done()
	if _, err := c.Prompt(context.Background(), PromptRequest{SessionID: "s1"}); err == nil {
		t.Fatal("Prompt after the agent exited succeeded")
	}
}

func TestTaggedUnionRoundTrip(t *testing.T) {
	in := `{"type":"text","text":"hi"}`
	var b ContentBlock
	if err := json.Unmarshal([]byte(in), &b); err != nil {
		t.Fatal(err)
	}
	out, err := json.Marshal(b)
	if err != nil || string(out) != in {
		t.Errorf("round trip = %s, %v; want %s", out, err, in)
	}
	var unknown ContentBlock
	if err := json.Unmarshal([]byte(`{"type":"hologram"}`), &unknown); err != nil || unknown.Type != "hologram" {
		t.Errorf("unknown variant = %+v, %v", unknown, err)
	}
}

func TestAgentRequestIsAnswered(t *testing.T) {
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	defer fromAgentW.Close()
	Connect(fromAgentR, toAgentW, &recorder{})

	io.WriteString(fromAgentW, `{"jsonrpc":"2.0","id":"p1","method":"session/request_permission","params":{"sessionId":"s1","toolCall":{"toolCallId":"t1"},"options":[{"optionId":"allow","name":"Allow","kind":"allow_once"},{"optionId":"deny","name":"Deny","kind":"reject_once"}]}}`+"\n")
	io.WriteString(fromAgentW, `{"jsonrpc":"2.0","id":7,"method":"fs/read_text_file","params":{}}`+"\n")
	sc := bufio.NewScanner(toAgentR)
	got := map[string]string{}
	for range 2 {
		if !sc.Scan() {
			t.Fatal("no reply")
		}
		var f frame
		json.Unmarshal(sc.Bytes(), &f)
		got[string(f.ID)] = sc.Text()
	}
	if want := `{"jsonrpc":"2.0","id":"p1","result":{"outcome":{"outcome":"selected","optionId":"deny"}}}`; got[`"p1"`] != want {
		t.Errorf("permission reply = %s, want %s", got[`"p1"`], want)
	}
	if !strings.Contains(got["7"], `"code":-32601`) {
		t.Errorf("unknown method reply = %s", got["7"])
	}
}

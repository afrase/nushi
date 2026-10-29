package claudeacp

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/acp-go/steering"
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// Initialize says who the agent is and what it does: queued prompts and
// steering in _meta, as clients of claude-agent-acp read them.
func TestInitialize(t *testing.T) {
	p := start(t, nil)
	r, err := p.Initialize(context.Background(), &acp.InitializeRequest{ProtocolVersion: 1})
	if err != nil {
		t.Fatal(err)
	}
	c := r.AgentCapabilities
	if r.ProtocolVersion != 1 || r.AgentInfo.Name != "claudeacp" || !steering.Supported(r.Meta) {
		t.Errorf("%+v", r)
	}
	queueing, _ := c.Meta["claudeCode"].(map[string]any)["promptQueueing"].(bool)
	if !c.PromptCapabilities.Image || !c.PromptCapabilities.EmbeddedContext || !c.MCPCapabilities.HTTP || !c.MCPCapabilities.SSE ||
		c.SessionCapabilities.Close == nil || !queueing || !c.LoadSession || c.SessionCapabilities.Resume == nil ||
		c.SessionCapabilities.Fork == nil || c.SessionCapabilities.List == nil || c.SessionCapabilities.Delete == nil {
		t.Errorf("%+v", c)
	}
}

// session/new runs claude in the folder with the session's id, the
// user's settings, partial messages and echoes, the ACP MCP servers over
// the options' and the options Nushi sends; initialize carries what the
// command line can't.
func TestNewSession(t *testing.T) {
	f := claudetest.New(
		claudetest.Expect(`{"type":"control_request","request":{"subtype":"initialize","appendSystemPrompt":"Be brief.\n\nBe kind."}}`),
		claudetest.Send(`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`),
	)
	p := start(t, nil, f)
	dir := t.TempDir()
	r, err := p.NewSession(context.Background(), &acp.NewSessionRequest{
		Cwd: dir, AdditionalDirectories: []string{"/extra"},
		MCPServers: []acp.MCPServer{
			{Stdio: &acp.MCPServerStdio{Name: "tools", Command: "/bin/tools", Args: []string{"-x"}, Env: []acp.EnvVariable{{Name: "K", Value: "v"}}}},
			{HTTP: &acp.MCPServerHTTP{Name: "web", URL: "https://mcp.example", Headers: []acp.HTTPHeader{{Name: "H", Value: "1"}}}},
		},
		SystemPrompt: &acp.SystemPrompt{Mode: acp.SystemPromptModeAppend, Content: []acp.ContentBlock{
			{Text: &acp.TextContent{Text: "Be brief."}}, {Text: &acp.TextContent{Text: "Be kind."}}}},
		Meta: map[string]any{"claudeCode": map[string]any{"options": map[string]any{
			"perTaskStopAffordance": false, "env": map[string]any{"CLAUDE_CODE_REPORT_FINDINGS": "1"},
			"settings": map[string]any{"ultracode": true}, "model": "opus", "unknownKey": 1,
			"mcpServers": map[string]any{"tools": map[string]any{"type": "stdio", "command": "/old"}, "kept": map[string]any{"type": "sse", "url": "https://kept"}},
		}}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if r.SessionID != "id1" {
		t.Errorf("session %s", r.SessionID)
	}
	<-f.Played()
	sp := f.Spec()
	if sp.Dir != dir || sp.Path != "/claude" {
		t.Errorf("%+v", sp)
	}
	for _, want := range []string{"--session-id=id1", "--setting-sources=user,project,local", "--include-partial-messages",
		"--replay-user-messages", "--model=opus", "--add-dir=/extra", "--disallowedTools=AskUserQuestion", `{"ultracode":true}`} {
		if !slices.Contains(sp.Args, want) {
			t.Errorf("no %s in %q", want, sp.Args)
		}
	}
	i := slices.Index(sp.Args, "--mcp-config")
	var mcp struct{ MCPServers map[string]map[string]any }
	if i < 0 || json.Unmarshal([]byte(sp.Args[i+1]), &mcp) != nil {
		t.Fatalf("%q", sp.Args)
	}
	if got := mcp.MCPServers; got["tools"]["command"] != "/bin/tools" || got["web"]["type"] != "http" ||
		got["web"]["headers"].(map[string]any)["H"] != "1" || got["kept"]["url"] != "https://kept" {
		t.Errorf("%v", got)
	}
	if !slices.Contains(sp.Env, "CLAUDE_CODE_REPORT_FINDINGS=1") {
		t.Error("the options' env isn't claude's")
	}
}

// A form-taking client keeps AskUserQuestion; subagent text is forwarded
// when the client wants it.
func TestNewSessionCaps(t *testing.T) {
	f := claudetest.New(
		claudetest.Expect(`{"type":"control_request","request":{"subtype":"initialize","perTaskStopAffordance":true,"forwardSubagentText":true}}`),
		claudetest.Send(`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`),
	)
	p := start(t, &acp.ClientCapabilities{Elicitation: &acp.ElicitationCapabilities{Form: &acp.ElicitationFormCapabilities{}},
		Meta: map[string]any{"subagent-transcript": true}}, f)
	p.open(t)
	<-f.Played()
	if slices.ContainsFunc(f.Spec().Args, func(a string) bool { return strings.HasPrefix(a, "--disallowedTools") }) {
		t.Errorf("%q", f.Spec().Args)
	}
	if f.Err() != nil {
		t.Error(f.Err())
	}
}

// What session/new refuses, and claude failing to start.
func TestNewSessionFails(t *testing.T) {
	file := filepath.Join(t.TempDir(), "file")
	if err := os.WriteFile(file, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		name string
		req  acp.NewSessionRequest
		code acp.ErrorCode
	}{
		{"relative cwd", acp.NewSessionRequest{Cwd: "here"}, acp.ErrorCodeInvalidParams},
		{"missing cwd", acp.NewSessionRequest{Cwd: "/no/such/folder"}, acp.ErrorCodeInvalidParams},
		{"file cwd", acp.NewSessionRequest{Cwd: file}, acp.ErrorCodeInvalidParams},
		{"image system prompt", acp.NewSessionRequest{Cwd: t.TempDir(), SystemPrompt: &acp.SystemPrompt{Mode: acp.SystemPromptModeOverride,
			Content: []acp.ContentBlock{{Image: &acp.ImageContent{Data: "x", MimeType: "image/png"}}}}}, acp.ErrorCodeInvalidParams},
		{"bad settings", acp.NewSessionRequest{Cwd: t.TempDir(), Meta: map[string]any{"claudeCode": map[string]any{"options": map[string]any{"settings": 3}}}}, acp.ErrorCodeInvalidParams},
		{"claude exits", acp.NewSessionRequest{Cwd: t.TempDir()}, acp.ErrorCodeInternalError},
	} {
		t.Run(tc.name, func(t *testing.T) {
			// Only claude exiting has a claude: the others never start one.
			var fakes []*claudetest.Fake
			if tc.code == acp.ErrorCodeInternalError {
				fakes = append(fakes, claudetest.New(claudetest.Expect(initRequest), claudetest.Exit(1, "boom\n")))
			}
			p := start(t, nil, fakes...)
			tc.req.MCPServers = []acp.MCPServer{}
			_, err := p.NewSession(context.Background(), &tc.req)
			if e, ok := errors.AsType[*acp.Error](err); !ok || e.Code != tc.code {
				t.Fatalf("%v", err)
			}
			if tc.code == acp.ErrorCodeInternalError && !strings.Contains(err.Error(), "boom") {
				t.Errorf("%v", err)
			}
		})
	}
}

// Close interrupts the running turn, answers it cancelled and closes
// claude; the session is gone, and closing it again is no error.
func TestClose(t *testing.T) {
	taken := make(chan struct{})
	f := fake(user("id2"), echo("id2"), signal(taken))
	p := start(t, nil, f)
	sid := p.open(t)
	w := p.prompt(t, sid, "hi")
	wait(t, taken, "the prompt taken")
	if _, err := p.CloseSession(context.Background(), &acp.CloseSessionRequest{SessionID: sid}); err != nil {
		t.Fatal(err)
	}
	if got := stopReason(w); got != "cancelled" {
		t.Errorf("the prompt: %s", got)
	}
	<-f.Exited()
	if f.Err() != nil || len(asked(f)) != 1 || !strings.Contains(asked(f)[0], "interrupt") {
		t.Errorf("%v %q", f.Err(), asked(f))
	}
	if _, err := p.CloseSession(context.Background(), &acp.CloseSessionRequest{SessionID: sid}); err != nil {
		t.Error(err)
	}
	if got := stopReason(p.prompt(t, sid, "again")); !strings.Contains(got, "no open session") {
		t.Errorf("a prompt after close: %s", got)
	}
}

// claude dying fails the turns, and the session goes.
func TestDeath(t *testing.T) {
	first := make(chan struct{})
	f := fake(user("id2"), signal(first), echo("id2"), user("id3"), claudetest.Exit(1, "crash\n"))
	p := start(t, nil, f)
	sid := p.open(t)
	w1 := p.prompt(t, sid, "one")
	wait(t, first, "the first prompt written")
	w2 := p.prompt(t, sid, "two")
	for _, w := range []func() (*acp.PromptResponse, error){w1, w2} {
		_, err := w()
		if e, ok := errors.AsType[*acp.Error](err); !ok || e.Code != acp.ErrorCodeInternalError || string(e.Data) != `{"errorKind":"transport_lost"}` {
			t.Errorf("%v", err)
		}
	}
	if got := stopReason(p.prompt(t, sid, "again")); !strings.Contains(got, "no open session") {
		t.Errorf("a prompt after death: %s", got)
	}
}

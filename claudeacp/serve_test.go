package claudeacp

import (
	"context"
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
		c.SessionCapabilities.Close == nil || !queueing {
		t.Errorf("%+v", c)
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

// Close closes claude, and the session is gone; closing it again is no
// error.
func TestClose(t *testing.T) {
	f := fake()
	p := start(t, nil, f)
	sid := p.open(t)
	for range 2 {
		if _, err := p.CloseSession(context.Background(), &acp.CloseSessionRequest{SessionID: sid}); err != nil {
			t.Fatal(err)
		}
	}
	<-f.Exited()
	if _, err := p.agent.session(sid); err == nil || f.Err() != nil {
		t.Errorf("%v %v", err, f.Err())
	}
}

// claude dying closes its session.
func TestDeath(t *testing.T) {
	p := start(t, nil, fake(claudetest.Exit(1, "crash\n")))
	sid := p.open(t)
	eventually(t, "the session gone", func() bool { _, err := p.agent.session(sid); return err != nil })
}

// session/new runs claude in the folder with the session's id, the
// user's settings, partial messages and echoes.
func TestNewSession(t *testing.T) {
	f := fake()
	p := start(t, nil, f)
	dir := t.TempDir()
	r, err := p.NewSession(context.Background(), &acp.NewSessionRequest{Cwd: dir, AdditionalDirectories: []string{"/extra"}, MCPServers: []acp.MCPServer{}})
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
		"--replay-user-messages", "--add-dir=/extra", "--disallowedTools=AskUserQuestion"} {
		if !slices.Contains(sp.Args, want) {
			t.Errorf("no %s in %q", want, sp.Args)
		}
	}
}

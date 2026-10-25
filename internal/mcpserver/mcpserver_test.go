package mcpserver

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/model"
)

type fakeTools struct{}

func (fakeTools) List(context.Context) (json.RawMessage, error) {
	return json.RawMessage(`[{"name":"echo","description":"","inputSchema":{"type":"object"}}]`), nil
}

func (fakeTools) Call(_ context.Context, name string, args json.RawMessage) (string, bool, error) {
	if name == "broken" {
		return "", false, errors.New("can't reach Nushi")
	}
	return "said " + string(args), name == "fails", nil
}

// session runs Serve on pipes and returns a function that sends a line
// and reads the answer (none for a notification).
func session(t *testing.T, tl Tools) func(line string, answer bool) map[string]any {
	t.Helper()
	inR, inW := io.Pipe()
	outR, outW := io.Pipe()
	go func() {
		_ = Serve(t.Context(), inR, outW, tl)
		_ = outW.Close()
	}()
	t.Cleanup(func() { _ = inW.Close() })
	lines := bufio.NewScanner(outR)
	return func(line string, answer bool) map[string]any {
		if _, err := io.WriteString(inW, line+"\n"); err != nil {
			t.Fatal(err)
		}
		if !answer {
			return nil
		}
		if !lines.Scan() {
			t.Fatal("no answer")
		}
		var m map[string]any
		if err := json.Unmarshal(lines.Bytes(), &m); err != nil {
			t.Fatal(err)
		}
		return m
	}
}

func TestProtocol(t *testing.T) {
	send := session(t, fakeTools{})
	init := send(`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"claude-code"}}}`, true)
	res, _ := init["result"].(map[string]any)
	if res["protocolVersion"] != "2025-06-18" || res["capabilities"] == nil {
		t.Errorf("initialize: %v", init)
	}
	send(`{"jsonrpc":"2.0","method":"notifications/initialized"}`, false)
	if r := send(`{"jsonrpc":"2.0","id":"a","method":"initialize","params":{"protocolVersion":"1999-01-01"}}`, true); r["result"].(map[string]any)["protocolVersion"] != "2025-11-25" {
		t.Errorf("an unknown version: %v", r)
	}
	list := send(`{"jsonrpc":"2.0","id":2,"method":"tools/list"}`, true)
	if !strings.Contains(asJSON(list), `"name":"echo"`) {
		t.Errorf("tools/list: %v", list)
	}
	for _, c := range []struct{ line, want string }{
		{`{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"echo","arguments":{"a":1}}}`, `"content":[{"text":"said {\"a\":1}","type":"text"}],"isError":false`},
		{`{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"fails"}}`, `"isError":true`},
		{`{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"broken"}}`, `"text":"can't reach Nushi"`},
		{`{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{}}`, `"code":-32602`},
		{`{"jsonrpc":"2.0","id":7,"method":"resources/list"}`, `"code":-32601`},
		{`{"jsonrpc":"2.0","id":8,"method":"ping"}`, `"result":{}`},
		{`not json`, `"code":-32700`},
	} {
		if got := asJSON(send(c.line, true)); !strings.Contains(got, c.want) {
			t.Errorf("%s:\n got %s\nwant %s", c.line, got, c.want)
		}
	}
}

func asJSON(m map[string]any) string {
	b, _ := json.Marshal(m)
	return string(b)
}

// The daemon's side: its tools endpoint on a Unix socket, over HTTP/2
// without TLS as the daemon serves it; a chat's key reaches that chat's
// tools only.
func TestDaemon(t *testing.T) {
	sock := filepath.Join(t.TempDir(), "s.sock")
	ln, err := new(net.ListenConfig).Listen(t.Context(), "unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	svc := tools.New(issueSet{})
	srv := &http.Server{Handler: api.Tools(svc), Protocols: new(http.Protocols)} //nolint:gosec // a test's server
	srv.Protocols.SetUnencryptedHTTP2(true)
	go func() { _ = srv.Serve(ln) }()
	t.Cleanup(func() { _ = srv.Close() })

	key := svc.Key(tools.Grant{Chat: "c1", Agent: "claude", Issue: &model.ChatIssue{Key: "ACME-12"}})
	d := Daemon{Socket: sock, Key: key}
	list, err := d.List(t.Context())
	if err != nil || !strings.Contains(string(list), `"name":"which"`) {
		t.Fatalf("list %s, %v", list, err)
	}
	text, failed, err := d.Call(t.Context(), "which", nil)
	if err != nil || failed || text != "c1 ACME-12" {
		t.Errorf("call %q %v %v", text, failed, err)
	}
	if _, failed, err := d.Call(t.Context(), "nope", nil); err != nil || !failed {
		t.Errorf("a tool it doesn't have: %v %v", failed, err)
	}
	for _, bad := range []string{"", "not-a-key"} {
		if _, err := (Daemon{Socket: sock, Key: bad}).List(t.Context()); err == nil {
			t.Errorf("key %q listed", bad)
		}
	}
}

type issueSet struct{}

func (issueSet) Tools(tools.Grant) []tools.Tool {
	return []tools.Tool{{Name: "which", InputSchema: json.RawMessage(`{"type":"object"}`)}}
}

func (issueSet) Call(_ context.Context, g tools.Grant, _ string, _ json.RawMessage) (string, error) {
	return g.Chat + " " + g.Issue.Key, nil
}

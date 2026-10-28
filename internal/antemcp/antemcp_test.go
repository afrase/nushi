package antemcp

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/filelock"
	"github.com/afrase/nushi/internal/model"
)

// A settings file as Ante writes it, other keys around mcp_servers.
const settings = `{
  "model": "kimi-k3",
  "permissions": {"allow": ["Bash(ls *)"]},
  "exclude_skills": ["x"],
  "mcp_servers": {
    "web": {"url": "https://example.com/mcp", "args": [], "env": {}, "enabled_tools": []},
    "fs": {"command": "fs-mcp", "args": ["--root", "/"], "env": {"TOKEN": "s3cret"}, "enabled_tools": ["read"]}
  },
  "theme": "dark"
}
`

// home is a temp ANTE_HOME holding settings (none when it's empty), mode 0600.
func home(t *testing.T, settings string) string {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("ANTE_HOME", dir)
	if settings != "" {
		if err := os.WriteFile(filepath.Join(dir, "settings.json"), []byte(settings), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	return filepath.Join(dir, "settings.json")
}

func decode(t *testing.T, path string) map[string]json.RawMessage {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]json.RawMessage
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatal(err)
	}
	return m
}

func servers(t *testing.T, path string) map[string]map[string]any {
	t.Helper()
	var s map[string]map[string]any
	if err := json.Unmarshal(decode(t, path)["mcp_servers"], &s); err != nil {
		t.Fatal(err)
	}
	return s
}

func TestServers(t *testing.T) {
	path := home(t, settings)
	got, err := Ante{}.Servers("/any")
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[0].Name != "fs" || got[1].Name != "web" {
		t.Fatalf("servers = %+v, want fs then web", got)
	}
	for _, s := range got {
		if s.Scope != "user" || s.Source != path {
			t.Errorf("%s: scope %q, source %q", s.Name, s.Scope, s.Source)
		}
	}
	var fs map[string]any
	if err := json.Unmarshal([]byte(got[0].Config), &fs); err != nil || fs["command"] != "fs-mcp" || fs["env"].(map[string]any)["TOKEN"] != "s3cret" {
		t.Errorf("fs's config = %s, want it as stored", got[0].Config)
	}
	home(t, "")
	if got, err := (Ante{}).Servers("/any"); err != nil || len(got) != 0 {
		t.Errorf("without a file: %v, %v", got, err)
	}
}

// Adding stdio and HTTP servers changes mcp_servers alone: the other keys
// stay as they were, and so does the file's mode.
func TestAddAndRemove(t *testing.T) {
	path := home(t, settings)
	before := decode(t, path)
	ctx := context.Background()
	if err := (Ante{}).Add(ctx, "/f", "user", "git", `{"command":"git-mcp","args":["-v"],"env":{"K":"v"}}`); err != nil {
		t.Fatal(err)
	}
	if err := (Ante{}).Add(ctx, "/f", "user", "api", `{"type":"http","url":"https://api.example.com/mcp","headers":{"Authorization":"Bearer x"},"transport":"stdio"}`); err != nil {
		t.Fatal(err)
	}
	s := servers(t, path)
	if want := map[string]any{"command": "git-mcp", "args": []any{"-v"}, "env": map[string]any{"K": "v"}}; !reflect.DeepEqual(s["git"], want) {
		t.Errorf("git = %v, want %v", s["git"], want)
	}
	if want := map[string]any{"url": "https://api.example.com/mcp", "headers": map[string]any{"Authorization": "Bearer x"}}; !reflect.DeepEqual(s["api"], want) {
		t.Errorf("api = %v, want %v (type and transport left to Ante)", s["api"], want)
	}
	if len(s) != 4 {
		t.Errorf("servers = %v, want fs and web kept", s)
	}
	if err := (Ante{}).Remove(ctx, "/f", "user", "fs"); err != nil {
		t.Fatal(err)
	}
	if _, ok := servers(t, path)["fs"]; ok {
		t.Error("fs wasn't removed")
	}
	after := decode(t, path)
	for k, v := range before {
		if k != "mcp_servers" && !bytes.Equal(compact(t, after[k]), compact(t, v)) {
			t.Errorf("%s = %s, was %s", k, after[k], v)
		}
	}
	if len(after) != len(before) {
		t.Errorf("keys = %d, were %d", len(after), len(before))
	}
	if fi, err := os.Stat(path); err != nil || fi.Mode().Perm() != 0o600 {
		t.Errorf("mode = %v, %v; want 0600 kept", fi.Mode(), err)
	}
	for _, c := range []struct{ scope, name, config, why string }{
		{"project", "p", `{"command":"x"}`, "a project's servers"},
		{"user", "git", `{"command":"x"}`, "a name taken"},
		{"user", "sse", `{"type":"sse","url":"https://x/sse"}`, "SSE"},
		{"user", "both", `{"command":"x","url":"https://x"}`, "a command and a URL"},
		{"user", "none", `{"args":["x"]}`, "neither"},
	} {
		if err := (Ante{}).Add(ctx, "/f", c.scope, c.name, c.config); err == nil {
			t.Errorf("%s: added", c.why)
		}
	}
	if err := (Ante{}).Remove(ctx, "/f", "user", "nope"); err == nil {
		t.Error("removed a server that isn't there")
	}
}

func compact(t *testing.T, raw json.RawMessage) []byte {
	t.Helper()
	var v any
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	b, _ := json.Marshal(v)
	return b
}

// A change waits while Ante holds its lock, and is made once it lets go.
func TestWritesUnderAntesLock(t *testing.T) {
	path := home(t, settings)
	unlock, err := filelock.Lock(path+".lock", 0)
	if err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { done <- (Ante{}).Add(context.Background(), "/f", "user", "late", `{"command":"x"}`) }()
	select {
	case err := <-done:
		t.Fatalf("written while the lock was held: %v", err)
	case <-time.After(300 * time.Millisecond):
	}
	if _, ok := servers(t, path)["late"]; ok {
		t.Fatal("written while the lock was held")
	}
	unlock()
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	if _, ok := servers(t, path)["late"]; !ok {
		t.Error("not written once the lock was let go")
	}
}

// A file that isn't JSON is refused and left as it was.
func TestMalformed(t *testing.T) {
	const bad = `{"mcp_servers": {"a": {"command": "x"}},` // cut short
	path := home(t, bad)
	if _, err := (Ante{}).Servers("/f"); err == nil {
		t.Error("read a broken file")
	}
	if err := (Ante{}).Add(context.Background(), "/f", "user", "b", `{"command":"y"}`); err == nil {
		t.Error("added to a broken file")
	}
	if err := (Ante{}).Remove(context.Background(), "/f", "user", "a"); err == nil {
		t.Error("removed from a broken file")
	}
	if b, _ := os.ReadFile(path); string(b) != bad {
		t.Errorf("the file became %q", b)
	}
}

// Check reads Ante's warm-up notice, as a 0.2.14 host sends it.
func TestCheck(t *testing.T) {
	home(t, settings)
	events := []string{
		`{"event":{"SessionStart":{"session_id":"ses_1","cwd":"/tmp/x"}}}`,
		`{"event":{"ExtensionRefreshed":{"session_id":"ses_1","mcp_servers":[]}}}`,
		`{"event":{"InfoBlockStart":{"id":"mcp-warmup-ses_1","header":"Warming up 2 MCP servers"}}}`,
		`{"event":{"ExtensionRefreshed":{"session_id":"ses_1","mcp_servers":[{"name":"fs","tools":[{"name":"read"}]},{"name":"web","tools":[]}]}}}`,
		`{"event":{"InfoBlockAppend":{"id":"mcp-warmup-other","detail":"MCP server 'fs' failed: not this session"}}}`,
		`{"event":{"InfoBlockAppend":{"id":"mcp-warmup-ses_1","detail":"MCP server 'web' failed: timed out connecting to MCP server 'web' after 15s"}}}`,
		`{"event":{"InfoBlockAppend":{"id":"mcp-warmup-ses_1","detail":"MCP ready: 1/2 servers connected, 1 tools registered."}}}`,
	}
	var op string
	var spawn ante.Spawn = func(string) (io.WriteCloser, io.Reader, func(), error) {
		inR, inW := io.Pipe()
		outR, outW := io.Pipe()
		go func() {
			line, _ := bufio.NewReader(inR).ReadString('\n')
			op = line
			for _, e := range events {
				_, _ = io.WriteString(outW, e+"\n")
			}
		}()
		return inW, outR, func() { _ = outW.Close(); _ = inR.Close() }, nil
	}
	got, err := Ante{Spawn: func() (ante.Spawn, error) { return spawn, nil }}.Check(context.Background(), "/f")
	if err != nil {
		t.Fatal(err)
	}
	want := []model.MCPServer{{Name: "fs", State: "connected"}, {Name: "web", State: "failed", Detail: "timed out connecting to MCP server 'web' after 15s"}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("Check = %+v, want %+v", got, want)
	}
	var m struct {
		Op map[string]map[string]string `json:"op"`
	}
	if json.Unmarshal([]byte(op), &m) != nil || m.Op["StartSession"]["cwd"] == "" || m.Op["StartSession"]["cwd"] == "/f" {
		t.Errorf("op = %q, want StartSession in a temp folder", op)
	}
}

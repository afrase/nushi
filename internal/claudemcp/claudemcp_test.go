package claudemcp

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseList(t *testing.T) {
	out := `Checking MCP server health…

claude.ai Gmail: https://gmailmcp.googleapis.com/mcp/v1 - ✔ Connected
plugin:github:github: https://api.githubcopilot.com/mcp (HTTP) - ✔ Connected
tiny: python3 tiny.py - x - ✘ Failed to connect — ENOENT: no such file
web: http://127.0.0.1:1/mcp (HTTP) - ⏸ Pending approval (run ` + "`claude`" + ` to approve)
authy: http://127.0.0.1:2/mcp (SSE) - ! Needs authentication
odd: true - ☃ Something new
`
	got := parseList(out)
	want := []struct{ name, scope, state, detail, config string }{
		{"claude.ai Gmail", "claudeai", "connected", "", `{"type":"http","url":"https://gmailmcp.googleapis.com/mcp/v1"}`},
		{"plugin:github:github", "plugin", "connected", "", `{"type":"http","url":"https://api.githubcopilot.com/mcp"}`},
		{"tiny", "", "failed", "ENOENT: no such file", `{"command":"python3 tiny.py - x"}`},
		{"web", "", "pending", "", `{"type":"http","url":"http://127.0.0.1:1/mcp"}`},
		{"authy", "", "needs_auth", "", `{"type":"sse","url":"http://127.0.0.1:2/mcp"}`},
		{"odd", "", "unknown", "☃ Something new", `{"command":"true"}`},
	}
	if len(got) != len(want) {
		t.Fatalf("got %d servers, want %d: %+v", len(got), len(want), got)
	}
	for i, w := range want {
		g := got[i]
		if g.Name != w.name || g.Scope != w.scope || g.State != w.state || g.Detail != w.detail || g.Config != w.config {
			t.Errorf("server %d = %+v, want %+v", i, g, w)
		}
	}
}

func TestServersReadsEachScope(t *testing.T) {
	cfg, root := t.TempDir(), t.TempDir()
	root, _ = filepath.EvalSymlinks(root)
	t.Setenv("CLAUDE_CONFIG_DIR", cfg)
	folder := filepath.Join(root, "repo", "sub")
	write(t, filepath.Join(cfg, ".claude.json"), `{"mcpServers":{"u":{"command":"x","env":{"TOKEN":"secret"}}},
		"projects":{"`+folder+`":{"mcpServers":{"l":{"type":"http","url":"http://l","headers":{"Authorization":"Bearer secret"}}}}}}`)
	write(t, filepath.Join(root, "repo", "sub", ".mcp.json"), `{"mcpServers":{"p":{"command":"near"}}}`)
	write(t, filepath.Join(root, "repo", ".mcp.json"), `{"mcpServers":{"p":{"command":"far"},"q":{"command":"q"}}}`)
	got, err := Claude{}.Servers(folder)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{
		`user u {"command":"x","env":{"TOKEN":"••••"}}`,
		`local l {"headers":{"Authorization":"••••"},"type":"http","url":"http://l"}`,
		`project p {"command":"near"}`,
		`project q {"command":"q"}`,
	}
	if len(got) != len(want) {
		t.Fatalf("got %+v", got)
	}
	for i, w := range want {
		if g := got[i].Scope + " " + got[i].Name + " " + got[i].Config; g != w {
			t.Errorf("server %d = %s, want %s", i, g, w)
		}
	}
}

func write(t *testing.T, path, text string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(text), 0o600); err != nil {
		t.Fatal(err)
	}
}

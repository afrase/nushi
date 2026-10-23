package claudemcp

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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
		`user u {"command":"x","env":{"TOKEN":"secret"}}`,
		`local l {"type":"http","url":"http://l","headers":{"Authorization":"Bearer secret"}}`,
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

func TestSetOnKeepsOtherSettings(t *testing.T) {
	t.Setenv("CLAUDE_CONFIG_DIR", t.TempDir())
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	if out, err := exec.Command("git", "-C", repo, "init", "-q").CombinedOutput(); err != nil {
		t.Fatal(string(out))
	}
	write(t, filepath.Join(repo, ".mcp.json"), `{"mcpServers":{"web":{"type":"http","url":"http://x"}}}`)
	ctx := context.Background()
	if err := (Claude{}).SetOn(ctx, repo, "web", false); err != nil {
		t.Fatal(err)
	}
	servers, _ := Claude{}.Servers(repo)
	if len(servers) != 1 || !servers[0].Off || servers[0].OffBy != "" {
		t.Fatalf("after turning it off: %+v", servers)
	}
	exclude, _ := os.ReadFile(filepath.Join(repo, ".git", "info", "exclude"))
	if !strings.Contains(string(exclude), "/.claude/settings.local.json\n") {
		t.Errorf("info/exclude:\n%s", exclude)
	}
	path := filepath.Join(repo, ".claude", "settings.local.json")
	write(t, path, `{"permissions":{"allow":["Bash(ls)"]},"disabledMcpjsonServers":["web","other"]}`)
	if err := (Claude{}).SetOn(ctx, repo, "web", true); err != nil {
		t.Fatal(err)
	}
	var got map[string]any
	b, _ := os.ReadFile(path)
	_ = json.Unmarshal(b, &got)
	want := `{"disabledMcpjsonServers":["other"],"enabledMcpjsonServers":["web"],"permissions":{"allow":["Bash(ls)"]}}`
	if g, _ := json.Marshal(got); string(g) != want {
		t.Errorf("settings = %s, want %s", g, want)
	}
	write(t, filepath.Join(repo, ".claude", "settings.json"), `{"disabledMcpjsonServers":["web"]}`)
	if servers, _ := (Claude{}).Servers(repo); !servers[0].Off || servers[0].OffBy != filepath.Join(repo, ".claude", "settings.json") {
		t.Errorf("turned off by the shared settings: %+v", servers[0])
	}
}

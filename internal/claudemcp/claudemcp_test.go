package claudemcp

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
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
	testcheck.Write(t, filepath.Join(cfg, ".claude.json"), `{"mcpServers":{"u":{"command":"x","env":{"TOKEN":"secret"}}},
		"projects":{"`+folder+`":{"mcpServers":{"l":{"type":"http","url":"http://l","headers":{"Authorization":"Bearer secret"}}}}}}`)
	testcheck.Write(t, filepath.Join(root, "repo", "sub", ".mcp.json"), `{"mcpServers":{"p":{"command":"near"}}}`)
	testcheck.Write(t, filepath.Join(root, "repo", ".mcp.json"), `{"mcpServers":{"p":{"command":"far"},"q":{"command":"q"}}}`)
	testcheck.Write(t, filepath.Join(root, ".mcp.json"), `{"mcpServers":{"bad":{},}}`) // left out, as Claude does
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

func TestSetOnKeepsOtherSettings(t *testing.T) {
	t.Setenv("CLAUDE_CONFIG_DIR", t.TempDir())
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	testcheck.Git(t, repo, "init", "-q")
	testcheck.Write(t, filepath.Join(repo, ".mcp.json"), `{"mcpServers":{"web":{"type":"http","url":"http://x"}}}`)
	ctx := context.Background()
	if err := (Claude{}).SetOn(ctx, repo, "project", "web", false); err != nil {
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
	testcheck.Write(t, path, `{"permissions":{"allow":["Bash(ls)"]},"disabledMcpjsonServers":["web","other"]}`)
	if err := (Claude{}).SetOn(ctx, repo, "project", "web", true); err != nil {
		t.Fatal(err)
	}
	var got map[string]any
	b, _ := os.ReadFile(path)
	_ = json.Unmarshal(b, &got)
	want := `{"disabledMcpjsonServers":["other"],"enabledMcpjsonServers":["web"],"permissions":{"allow":["Bash(ls)"]}}`
	if g, _ := json.Marshal(got); string(g) != want {
		t.Errorf("settings = %s, want %s", g, want)
	}
	// A file of null, and one name alone (which Claude takes for a list).
	testcheck.Write(t, path, `null`)
	if err := (Claude{}).SetOn(ctx, repo, "project", "web", false); err != nil {
		t.Fatal(err)
	}
	testcheck.Write(t, path, `{"enabledMcpjsonServers":"web"}`)
	if servers, _ := (Claude{}).Servers(repo); !servers[0].Approved {
		t.Errorf("approved by one name alone: %+v", servers[0])
	}
	if err := (Claude{}).SetOn(ctx, repo, "project", "web", false); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(path); !strings.Contains(string(b), `"enabledMcpjsonServers": []`) {
		t.Errorf("settings = %s", b)
	}
	testcheck.Write(t, filepath.Join(repo, ".claude", "settings.json"), `{"disabledMcpjsonServers":"web"}`)
	if servers, _ := (Claude{}).Servers(repo); !servers[0].Off || servers[0].OffBy != filepath.Join(repo, ".claude", "settings.json") {
		t.Errorf("turned off by the shared settings: %+v", servers[0])
	}
}

func TestSetOnRefusesSymlinks(t *testing.T) {
	t.Setenv("CLAUDE_CONFIG_DIR", t.TempDir())
	ctx := context.Background()
	for _, link := range []string{".claude", ".claude/settings.local.json"} {
		repo, outside := t.TempDir(), t.TempDir()
		target := filepath.Join(outside, "victim")
		testcheck.Write(t, filepath.Join(target, "settings.local.json"), "keep")
		if link == ".claude" {
			if err := os.Symlink(target, filepath.Join(repo, ".claude")); err != nil {
				t.Fatal(err)
			}
		} else {
			if err := os.MkdirAll(filepath.Join(repo, ".claude"), 0o755); err != nil {
				t.Fatal(err)
			}
			if err := os.Symlink(filepath.Join(target, "settings.local.json"), filepath.Join(repo, link)); err != nil {
				t.Fatal(err)
			}
		}
		if err := (Claude{}).SetOn(ctx, repo, "project", "web", true); err == nil {
			t.Errorf("%s as a symlink: changed", link)
		}
		if b, _ := os.ReadFile(filepath.Join(target, "settings.local.json")); string(b) != "keep" {
			t.Errorf("%s as a symlink: the target became %q", link, b)
		}
	}
}

// In a worktree Claude reads the main checkout's local settings, then the
// worktree's own local settings and settings.json, then yours; not the
// main checkout's settings.json (docs/facts/claude.md). A real worktree.
func TestSettingsFilesInAWorktree(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", cfg)
	base, _ := filepath.EvalSymlinks(t.TempDir())
	main, wt := filepath.Join(base, "main"), filepath.Join(base, "wt")
	testcheck.Write(t, filepath.Join(main, ".mcp.json"), `{"mcpServers":{"a":{"command":"a"},"b":{"command":"b"},"c":{"command":"c"},"d":{"command":"d"}}}`)
	testcheck.Git(t, main, "init", "-q")
	testcheck.Git(t, main, "add", ".mcp.json")
	testcheck.Git(t, main, "commit", "-qm", "servers")
	testcheck.Git(t, main, "worktree", "add", "-q", wt)
	if got := Project(wt); got != main {
		t.Fatalf("a worktree's project is %s, want the main checkout %s", got, main)
	}
	want := []string{filepath.Join(main, ".claude", "settings.local.json"), filepath.Join(wt, ".claude", "settings.local.json"),
		filepath.Join(wt, ".claude", "settings.json"), filepath.Join(cfg, "settings.json")}
	if got := SettingsFiles(wt, main); strings.Join(got, "|") != strings.Join(want, "|") {
		t.Errorf("a worktree's settings files:\n%q\nwant\n%q", got, want)
	}
	if got := SettingsFiles(main, main); len(got) != 3 {
		t.Errorf("the main checkout's settings files: %q", got)
	}

	testcheck.Write(t, filepath.Join(main, ".claude", "settings.local.json"), `{"disabledMcpjsonServers":["a"]}`)
	testcheck.Write(t, filepath.Join(main, ".claude", "settings.json"), `{"disabledMcpjsonServers":["b"]}`) // not read in the worktree
	testcheck.Write(t, filepath.Join(wt, ".claude", "settings.local.json"), `{"disabledMcpjsonServers":["c"]}`)
	testcheck.Write(t, filepath.Join(wt, ".claude", "settings.json"), `{"disabledMcpjsonServers":["d"]}`)
	servers, err := Claude{}.Servers(wt)
	if err != nil {
		t.Fatal(err)
	}
	var got []string
	for _, s := range servers {
		got = append(got, s.Name+" "+map[bool]string{true: "off", false: "on"}[s.Off]+" "+s.OffBy)
	}
	want = []string{"a off ", "b on ", "c off " + filepath.Join(wt, ".claude", "settings.local.json"), "d off " + filepath.Join(wt, ".claude", "settings.json")}
	if strings.Join(got, "|") != strings.Join(want, "|") {
		t.Errorf("the worktree's servers:\n%q\nwant\n%q", got, want)
	}
}

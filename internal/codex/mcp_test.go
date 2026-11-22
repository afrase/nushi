package codex

import (
	"encoding/json"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// An MCP call, as codex-acp and the Go agent send it (docs/facts/codex.md:
// title mcp.<server>.<tool>, kind execute, input {server, tool, arguments}),
// isn't a command: its kind is "other", and stays so through the updates
// that carry the kind again without the input; it has its server and tool.
func TestMCPCallIsNoCommand(t *testing.T) {
	input := json.RawMessage(`{"server":"github","tool":"search_issues","arguments":{"query":"is:open"}}`)
	it := model.Item{Title: "mcp.github.search_issues", ToolKind: "execute"}
	if harness.ToolCall(&it, map[string]any{"is_mcp_tool_call": true}, input) {
		t.Error("an MCP call took its text")
	}
	if it.ToolKind != "other" || it.MCPServer != "github" || it.MCPTool != "search_issues" {
		t.Fatalf("kind, server, tool = %q, %q, %q", it.ToolKind, it.MCPServer, it.MCPTool)
	}
	it.ToolKind = "execute" // a later update's kind (chats' updates.go)
	harness.ToolCall(&it, map[string]any{"mcp_output_delta": map[string]any{"data": "1 issue"}}, nil)
	if it.ToolKind != "other" {
		t.Fatalf("kind after an update without input = %q, want other", it.ToolKind)
	}
}

// A command stays one, whatever its title; an MCP call's title is read
// only when no input says otherwise.
func TestMCPCall(t *testing.T) {
	for _, c := range []struct {
		title, input, server, tool string
	}{
		{"mcp.github.search_issues", `{"server":"github","tool":"search_issues","arguments":{}}`, "github", "search_issues"},
		{"mcp.nushi.show", ``, "nushi", "show"},
		{"mcp.a.b.c", `null`, "a", "b.c"},
		{"Run tests", `{"server":"github","tool":"x"}`, "github", "x"}, // the input names it
		{"mcp.a.b", `{"command":["mcp.a.b"]}`, "", ""},                 // a command's input
		{"mcp.a.b", `{"server":"a"}`, "", ""},
		{"mcp.a.b --flag", ``, "", ""},
		{"mcp.a", ``, "", ""},
		{"mcp..b", ``, "", ""},
		{"git status", ``, "", ""},
	} {
		server, tool := mcpCall(c.title, json.RawMessage(c.input))
		if server != c.server || tool != c.tool {
			t.Errorf("mcpCall(%q, %s) = %q, %q; want %q, %q", c.title, c.input, server, tool, c.server, c.tool)
		}
	}
	cmd := model.Item{Title: "mcp.a.b", ToolKind: "execute"}
	harness.ToolCall(&cmd, nil, json.RawMessage(`{"command":["mcp.a.b"]}`))
	if cmd.ToolKind != "execute" {
		t.Errorf("a command's kind = %q", cmd.ToolKind)
	}
}

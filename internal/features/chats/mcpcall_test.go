package chats

import (
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// A copy saved before Nushi kept an MCP call's server and tool has the
// harness read them again from the title, for a call and for an ask, so
// an old show or dev server call is still one; other items are left as
// they were.
func TestSavedMCPCallsAreReadAgain(t *testing.T) {
	_, _, c := newChat(t, `{"sessionId":"s1"}`, &memModes{})
	items := []model.Item{
		{ID: "s", Kind: model.ToolCall, Title: "mcp__nushi__show", ToolKind: "other", Input: `{"path":"a.html"}`},
		{ID: "p", Kind: model.Permission, Title: "mcp__nushi__preview_start"},
		{ID: "g", Kind: model.ToolCall, Title: "mcp__github__search_issues", Tool: "mcp__github__search_issues"},
		{ID: "b", Kind: model.ToolCall, Title: "mcp__nushi__show", Tool: "Bash", ToolKind: "execute"},
		{ID: "m", Kind: model.AgentMessage, Title: "mcp__nushi__show"},
		{ID: "k", Kind: model.ToolCall, Title: "x", MCPServer: "kept", MCPTool: "as is"},
	}
	c.mu.Lock()
	c.savedLocked(items)
	c.mu.Unlock()
	if !isShow(items[0]) || !isPreviewStart(items[1]) {
		t.Errorf("Nushi's calls: %+v, %+v", items[0], items[1])
	}
	if items[2].MCPServer != "github" || items[2].MCPTool != "search_issues" {
		t.Errorf("an MCP call: %q, %q", items[2].MCPServer, items[2].MCPTool)
	}
	if items[3].MCPServer != "" || items[4].MCPServer != "" {
		t.Errorf("a command named so, or a message: %+v, %+v", items[3], items[4])
	}
	if items[5].MCPServer != "kept" || items[5].MCPTool != "as is" {
		t.Errorf("a call read before: %+v", items[5])
	}
}

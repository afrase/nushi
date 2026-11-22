package chats

import (
	"encoding/json"

	"github.com/afrase/nushi/internal/model"
)

// ToolsServer is the name of the MCP server of Nushi's own tools a chat's
// sessions get (Tools; cmd/nushid names it so).
const ToolsServer = "nushi"

// isShow says a call is Nushi's show tool (ADR 0068), or the ask to make
// one, by the server and tool its harness read (ToolReader).
func isShow(it model.Item) bool { return it.MCPServer == ToolsServer && it.MCPTool == "show" }

// isPreviewStart says a call is Nushi's preview_start tool (ADR 0100), the
// same way.
func isPreviewStart(it model.Item) bool {
	return it.MCPServer == ToolsServer && it.MCPTool == "preview_start"
}

// mcpLocked has the harness read the MCP server and tool of an item that
// didn't pass through its ToolReader as a call: an ask for a call not
// seen, from the request's meta and input, or a call or an ask from a copy
// saved before Nushi kept them (API 140), from its title and tool alone.
// Only those, and a call's kind with them, are taken: the rest of what the
// reader does belongs to a call's updates, not to this.
func (c *chat) mcpLocked(it *model.Item, meta map[string]any, input json.RawMessage) {
	if c.kind.toolReader == nil || it.MCPServer != "" {
		return
	}
	read := model.Item{Kind: model.ToolCall, Title: it.Title, Tool: it.Tool, ToolKind: it.ToolKind}
	c.kind.toolReader.ToolCall(&read, meta, input)
	if read.MCPServer == "" {
		return
	}
	it.MCPServer, it.MCPTool = read.MCPServer, read.MCPTool
	if it.Kind == model.ToolCall {
		it.ToolKind = read.ToolKind
	}
}

// savedLocked reads the MCP calls and asks of items read back from the
// chat's copy that it saved without their server and tool (mcpLocked), so
// an old show or dev server call keeps its card's Preview or Open.
func (c *chat) savedLocked(items []model.Item) {
	for i := range items {
		if it := &items[i]; it.Kind == model.ToolCall || it.Kind == model.Permission {
			c.mcpLocked(it, nil, nil)
		}
	}
}

package codex

import (
	"encoding/json"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// mcpCall reads the MCP server and tool a call is for: those its input
// names (`{server, tool, arguments}`), else, for an update that carries no
// input, those its title `mcp.<server>.<tool>` names; "" for any other
// call. codex-acp and the Go agent send an MCP call so, with ACP kind
// `execute` (docs/facts/codex.md). A command's input has neither key.
func mcpCall(title string, input json.RawMessage) (server, tool string) {
	var in struct {
		Server *string `json:"server"`
		Tool   *string `json:"tool"`
	}
	if json.Unmarshal(input, &in) == nil {
		if in.Server != nil || in.Tool != nil {
			if in.Server == nil || in.Tool == nil || *in.Server == "" || *in.Tool == "" {
				return "", ""
			}
			return *in.Server, *in.Tool
		}
		if len(input) > 0 && string(input) != "null" && string(input) != "{}" {
			return "", "" // an input of another shape: a command's
		}
	}
	rest, ok := strings.CutPrefix(title, "mcp.")
	if !ok || strings.ContainsAny(rest, " \t\n") {
		return "", ""
	}
	server, tool, ok = strings.Cut(rest, ".")
	if !ok || server == "" || tool == "" {
		return "", ""
	}
	return server, tool
}

// readMCP fills in an MCP call's server and tool (mcpCall), kept once
// read, and makes its kind what ACP gives a tool it has no kind for,
// "other": Codex's `execute` would make it a shell command to Nushi, its
// title shown as the command and its input as one (keepRaw, the related
// worktrees' reading of a subagent's command, the app's row). Every
// update's kind replaces the call's, so that is set again each time.
func readMCP(it *model.Item, input json.RawMessage) {
	if server, tool := mcpCall(it.Title, input); server != "" {
		it.MCPServer, it.MCPTool = server, tool
	}
	if it.MCPServer != "" && it.ToolKind == "execute" {
		it.ToolKind = "other"
	}
}

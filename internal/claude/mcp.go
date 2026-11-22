package claude

import "strings"

// mcpName reads the MCP server and tool from a tool's name as Claude Code
// makes it, mcp__<server>__<tool>: the server up to the next "__", the
// tool the rest, as Claude Code itself splits it; "" for any other name
// (docs/facts/claude.md).
func mcpName(name string) (server, tool string) {
	rest, ok := strings.CutPrefix(name, "mcp__")
	if !ok {
		return "", ""
	}
	server, tool, ok = strings.Cut(rest, "__")
	if !ok || server == "" || tool == "" {
		return "", ""
	}
	return server, tool
}

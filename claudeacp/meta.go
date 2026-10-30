package claudeacp

import "encoding/json"

// _meta: what the agent reads of a client's, and the claudeCode key it
// writes on its own updates, as claude-agent-acp writes it.

// readMeta is what a client's _meta says, as T's fields read it. _meta
// is any JSON a client sent, so a key of a shape other than T's reads as
// absent rather than failing the request.
func readMeta[T any](meta map[string]any) T {
	var v T
	if b, err := json.Marshal(meta); err == nil {
		_ = json.Unmarshal(b, &v) // a field of the wrong type is skipped, the rest read
	}
	return v
}

// claudeCodeMeta is _meta.claudeCode on what the agent sends, which a
// client that knows claude reads beside ACP's fields.
type claudeCodeMeta struct {
	ToolName        string          `json:"toolName,omitempty"`
	ParentToolUseID string          `json:"parentToolUseId,omitempty"` // the subagent's Agent call, for its work
	MCPServer       *serverName     `json:"mcpServer,omitempty"`       // the server whose tool asks
	ToolResponse    json.RawMessage `json:"toolResponse,omitempty"`    // the tool's whole response
	Kind            string          `json:"kind,omitempty"`            // "informational", for claude's notices
	Level           *string         `json:"level,omitempty"`           // a notice's level, said even when ""
	PromptQueueing  bool            `json:"promptQueueing,omitempty"`  // in initialize's answer
}

// serverName names an MCP server in _meta.
type serverName struct {
	Name string `json:"name"`
}

// meta is c as a whole _meta.
func (c claudeCodeMeta) meta() map[string]any { return map[string]any{"claudeCode": c} }

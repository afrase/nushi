package acp

import "context"

// session/fork is unstable in ACP v1, so it isn't in the pinned schema;
// these types are written by hand, with only the fields Nushi uses.

// ForkSessionRequest asks the agent for a new session that starts with a
// copy of another one's conversation.
type ForkSessionRequest struct {
	SessionID  SessionID   `json:"sessionId"`
	Cwd        string      `json:"cwd"`
	MCPServers []MCPServer `json:"mcpServers"`
}

type ForkSessionResponse struct {
	SessionID     SessionID             `json:"sessionId"`
	ConfigOptions []SessionConfigOption `json:"configOptions,omitempty"`
	Modes         *SessionModeState     `json:"modes,omitempty"`
}

// CanFork reports whether the agent advertised session/fork when it was
// initialized (agentCapabilities.sessionCapabilities.fork).
func (c *Client) CanFork() bool { return c.canFork }

// ForkSession copies a session into a new one (session/fork).
func (c *Client) ForkSession(ctx context.Context, req ForkSessionRequest) (*ForkSessionResponse, error) {
	var resp ForkSessionResponse
	return &resp, c.conn.call(ctx, "session/fork", req, &resp)
}

package acp

import "context"

// Steering is an extension of claude-agent-acp (and the ACP steering
// proposal), not part of ACP v1: `_session/steering` hands a message to the
// session's running turn, which takes it in at once, rather than as a
// prompt of its own after the turn. The agent advertises it in the
// initialize response's `_meta.steering.supported`.

// CanSteer reports whether the agent advertised steering when it was
// initialized.
func (c *Client) CanSteer() bool { return c.canSteer }

// Steer hands prompt to the session's running turn. It returns false, and
// the agent does nothing, when no turn runs: the message then belongs in a
// session/prompt.
func (c *Client) Steer(ctx context.Context, session SessionID, prompt []ContentBlock) (bool, error) {
	var resp struct {
		Outcome string `json:"outcome"`
	}
	err := c.conn.call(ctx, "_session/steering", map[string]any{
		"sessionId": session,
		"prompt":    prompt,
		"_meta":     map[string]any{"steering": map[string]any{"idleBehavior": "promptRequired"}},
	}, &resp)
	return err == nil && resp.Outcome == "injected", err
}

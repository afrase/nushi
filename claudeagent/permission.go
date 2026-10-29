package claudeagent

import (
	"bytes"
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
)

// PermissionRequest is claude asking whether a tool may run: a can_use_tool
// request. The fields past Input are optional; Raw has the whole request.
type PermissionRequest struct {
	ToolName  string
	Input     json.RawMessage
	ToolUseID string

	Suggestions             []json.RawMessage // permission updates claude offers for "always allow"
	BlockedPath             string
	DecisionReason          string
	AgentID                 string // the subagent asking, if one is
	Title                   string
	DisplayName             string
	Description             string
	MatchedAskRule          bool
	SuppressAlwaysAllowRule bool
	DefaultToNo             bool
	MCPServer               string
	Raw                     json.RawMessage
}

// PermissionResult is the answer to a PermissionRequest: Allow or Deny.
type PermissionResult interface{ permissionResult() }

// Allow lets the tool run.
type Allow struct {
	UpdatedInput       json.RawMessage   // nil = the input as asked
	UpdatedPermissions []json.RawMessage // e.g. the request's Suggestions, to stop asking
	Classification     string            // "user_temporary" or "user_permanent"
}

// Deny stops the tool.
type Deny struct {
	Message        string // what the model is told; never empty on the wire
	Interrupt      bool   // also stops the turn
	Classification string // "user_reject"
}

func (Allow) permissionResult() {}
func (Deny) permissionResult()  {}

// canUseTool asks CanUseTool about a can_use_tool request and returns
// the answer as claude reads it.
func (s *Session) canUseTool(ctx context.Context, raw json.RawMessage) (any, error) {
	var w struct {
		ToolName                string            `json:"tool_name"`
		Input                   json.RawMessage   `json:"input"`
		ToolUseID               string            `json:"tool_use_id"`
		Suggestions             []json.RawMessage `json:"permission_suggestions"`
		BlockedPath             string            `json:"blocked_path"`
		DecisionReason          string            `json:"decision_reason"`
		AgentID                 string            `json:"agent_id"`
		Title                   string            `json:"title"`
		DisplayName             string            `json:"display_name"`
		Description             string            `json:"description"`
		MatchedAskRule          json.RawMessage   `json:"matched_ask_rule"`
		SuppressAlwaysAllowRule json.RawMessage   `json:"suppress_always_allow_rule"`
		DefaultToNo             json.RawMessage   `json:"default_to_no"`
		MCPServer               json.RawMessage   `json:"mcp_server"`
	}
	if err := json.Unmarshal(raw, &w); err != nil {
		return nil, fmt.Errorf("claudeagent: a permission request that doesn't decode: %w", err)
	}
	r := PermissionRequest{
		ToolName: w.ToolName, Input: w.Input, ToolUseID: w.ToolUseID,
		Suggestions: w.Suggestions, BlockedPath: w.BlockedPath, DecisionReason: w.DecisionReason,
		AgentID: w.AgentID, Title: w.Title, DisplayName: w.DisplayName, Description: w.Description,
		MatchedAskRule: isSet(w.MatchedAskRule), SuppressAlwaysAllowRule: isSet(w.SuppressAlwaysAllowRule),
		DefaultToNo: isSet(w.DefaultToNo), MCPServer: serverName(w.MCPServer), Raw: raw,
	}
	result, err := s.o.CanUseTool(ctx, r)
	if err != nil {
		return nil, err
	}
	return permissionAnswer(r, result)
}

// permissionAnswer is result as claude reads it. It always names the
// tool call, an allow always carries the input (the asked one when
// unchanged) and a deny always a message: claude checks all three.
func permissionAnswer(r PermissionRequest, result PermissionResult) (map[string]any, error) {
	a := map[string]any{"toolUseID": r.ToolUseID}
	switch p := result.(type) {
	case Allow:
		a["behavior"] = "allow"
		input := p.UpdatedInput
		if input == nil {
			input = r.Input
		}
		if input == nil {
			input = json.RawMessage(`{}`)
		}
		a["updatedInput"] = input
		if p.UpdatedPermissions != nil {
			a["updatedPermissions"] = p.UpdatedPermissions
		}
		if p.Classification != "" {
			a["decisionClassification"] = p.Classification
		}
	case Deny:
		a["behavior"] = "deny"
		a["message"] = cmp.Or(p.Message, "Permission denied")
		if p.Interrupt {
			a["interrupt"] = true
		}
		if p.Classification != "" {
			a["decisionClassification"] = p.Classification
		}
	default:
		return nil, errors.New("claudeagent: CanUseTool returned no Allow or Deny")
	}
	return a, nil
}

// isSet says whether an optional flag is on: present, and not false,
// null or empty.
func isSet(v json.RawMessage) bool {
	s := string(bytes.TrimSpace(v))
	return s != "" && s != "false" && s != "null" && s != `""`
}

// serverName is the name of the MCP server a request names: an object
// with a name, or the name alone.
func serverName(v json.RawMessage) string {
	var o struct {
		Name string `json:"name"`
	}
	if json.Unmarshal(v, &o) == nil && o.Name != "" {
		return o.Name
	}
	var name string
	_ = json.Unmarshal(v, &name)
	return name
}

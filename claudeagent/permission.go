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

	Suggestions             []PermissionUpdate // what claude offers for "always allow"
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
	UpdatedInput       json.RawMessage    // nil = the input as asked
	UpdatedPermissions []PermissionUpdate // e.g. the request's Suggestions, to stop asking
	Classification     string             // UserTemporary or UserPermanent
}

// Deny stops the tool.
type Deny struct {
	Message        string // what the model is told; never empty on the wire
	Interrupt      bool   // also stops the turn
	Classification string // UserReject
}

// How the user decided, for claude's records: an Allow's or a Deny's
// Classification.
const (
	UserTemporary = "user_temporary" // allowed this once
	UserPermanent = "user_permanent" // allowed from now on
	UserReject    = "user_reject"
)

// PermissionUpdate is a change to what claude may do without asking: one
// of a request's Suggestions, or one made for an Allow. Type says which
// fields it uses:
//
//   - "addRules", "replaceRules", "removeRules": Rules and Behavior;
//   - "setMode": Mode;
//   - "addDirectories", "removeDirectories": Directories.
//
// Destination says where the change is kept: "session", "localSettings",
// "projectSettings", "userSettings" or "cliArg".
type PermissionUpdate struct {
	Type        string           `json:"type"`
	Rules       []PermissionRule `json:"rules,omitempty"`
	Behavior    string           `json:"behavior,omitempty"` // "allow", "deny" or "ask"
	Mode        PermissionMode   `json:"mode,omitempty"`
	Directories []string         `json:"directories,omitempty"`
	Destination string           `json:"destination,omitempty"`
	// Raw is the update as claude wrote it. When set it is what goes
	// back, unchanged, with any fields the package doesn't know; clear it
	// to send the fields instead.
	Raw json.RawMessage `json:"-"`
}

// PermissionRule names a tool and, optionally, which uses of it: ToolName
// "Bash" with RuleContent "npm test:*", say.
type PermissionRule struct {
	ToolName    string `json:"toolName"`
	RuleContent string `json:"ruleContent,omitempty"`
}

// UnmarshalJSON decodes u, keeping it in Raw.
func (u *PermissionUpdate) UnmarshalJSON(data []byte) error {
	type plain PermissionUpdate
	if err := json.Unmarshal(data, (*plain)(u)); err != nil {
		return err
	}
	u.Raw = bytes.Clone(data)
	return nil
}

// MarshalJSON encodes u: Raw when set, else the fields.
func (u PermissionUpdate) MarshalJSON() ([]byte, error) {
	if len(u.Raw) > 0 {
		return u.Raw, nil
	}
	type plain PermissionUpdate
	return json.Marshal(plain(u))
}

func (Allow) permissionResult() {}
func (Deny) permissionResult()  {}

// canUseTool asks CanUseTool about a can_use_tool request and returns
// the answer as claude reads it.
func (s *Session) canUseTool(ctx context.Context, raw json.RawMessage) (any, error) {
	var w struct {
		ToolName                string             `json:"tool_name"`
		Input                   json.RawMessage    `json:"input"`
		ToolUseID               string             `json:"tool_use_id"`
		Suggestions             []PermissionUpdate `json:"permission_suggestions"`
		BlockedPath             string             `json:"blocked_path"`
		DecisionReason          string             `json:"decision_reason"`
		AgentID                 string             `json:"agent_id"`
		Title                   string             `json:"title"`
		DisplayName             string             `json:"display_name"`
		Description             string             `json:"description"`
		MatchedAskRule          json.RawMessage    `json:"matched_ask_rule"`
		SuppressAlwaysAllowRule json.RawMessage    `json:"suppress_always_allow_rule"`
		DefaultToNo             json.RawMessage    `json:"default_to_no"`
		MCPServer               json.RawMessage    `json:"mcp_server"`
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

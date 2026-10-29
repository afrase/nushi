package claudeagent

import "encoding/json"

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

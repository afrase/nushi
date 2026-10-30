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
	Classification     Classification     // UserTemporary or UserPermanent
}

// Deny stops the tool.
type Deny struct {
	Message        string         // what the model is told; never empty on the wire
	Interrupt      bool           // also stops the turn
	Classification Classification // UserReject
}

// Classification is how the user decided, for claude's records: an
// Allow's or a Deny's.
type Classification string

// The classifications.
const (
	UserTemporary Classification = "user_temporary" // allowed this once
	UserPermanent Classification = "user_permanent" // allowed from now on
	UserReject    Classification = "user_reject"
)

// PermissionUpdate is a change to what claude may do without asking: one
// of a request's Suggestions, or one made for an Allow. Type says which
// fields it uses:
//
//   - UpdateAddRules, UpdateReplaceRules, UpdateRemoveRules: Rules and
//     Behavior;
//   - UpdateSetMode: Mode;
//   - UpdateAddDirectories, UpdateRemoveDirectories: Directories.
//
// Destination says where the change is kept.
type PermissionUpdate struct {
	Type        PermissionUpdateType  `json:"type"`
	Rules       []PermissionRule      `json:"rules,omitempty"`
	Behavior    PermissionBehavior    `json:"behavior,omitempty"`
	Mode        PermissionMode        `json:"mode,omitempty"`
	Directories []string              `json:"directories,omitempty"`
	Destination PermissionDestination `json:"destination,omitempty"`
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

// PermissionUpdateType is the change a PermissionUpdate makes.
type PermissionUpdateType string

// The permission updates claude knows; it may know more.
const (
	UpdateAddRules          PermissionUpdateType = "addRules"
	UpdateReplaceRules      PermissionUpdateType = "replaceRules"
	UpdateRemoveRules       PermissionUpdateType = "removeRules"
	UpdateSetMode           PermissionUpdateType = "setMode"
	UpdateAddDirectories    PermissionUpdateType = "addDirectories"
	UpdateRemoveDirectories PermissionUpdateType = "removeDirectories"
)

// PermissionBehavior is what a rule does with the tool uses it names.
type PermissionBehavior string

// The rules' behaviors.
const (
	BehaviorAllow PermissionBehavior = "allow"
	BehaviorDeny  PermissionBehavior = "deny"
	BehaviorAsk   PermissionBehavior = "ask"
)

// PermissionDestination is where a PermissionUpdate is kept.
type PermissionDestination string

// The destinations claude knows.
const (
	DestinationSession         PermissionDestination = "session" // this session only
	DestinationLocalSettings   PermissionDestination = "localSettings"
	DestinationProjectSettings PermissionDestination = "projectSettings"
	DestinationUserSettings    PermissionDestination = "userSettings"
	DestinationCLIArg          PermissionDestination = "cliArg"
)

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
	a, err := permissionAnswer(r, result)
	if err != nil {
		return nil, err
	}
	return a, nil
}

// permissionReply is a can_use_tool answer as claude reads it. The
// fields are in their keys' order, as claude has always been sent them.
type permissionReply struct {
	Behavior               PermissionBehavior `json:"behavior"` // allow or deny
	DecisionClassification Classification     `json:"decisionClassification,omitempty"`
	Interrupt              bool               `json:"interrupt,omitempty"`
	Message                string             `json:"message,omitempty"` // a deny's
	ToolUseID              string             `json:"toolUseID"`
	UpdatedInput           json.RawMessage    `json:"updatedInput,omitzero"` // an allow's
	UpdatedPermissions     []PermissionUpdate `json:"updatedPermissions,omitzero"`
}

// permissionAnswer is result as claude reads it. It always names the
// tool call, an allow always carries the input (the asked one when
// unchanged) and a deny always a message: claude checks all three.
func permissionAnswer(r PermissionRequest, result PermissionResult) (permissionReply, error) {
	switch p := result.(type) {
	case Allow:
		input := p.UpdatedInput
		if input == nil {
			input = r.Input
		}
		if input == nil {
			input = json.RawMessage(`{}`)
		}
		return permissionReply{
			Behavior: BehaviorAllow, ToolUseID: r.ToolUseID, UpdatedInput: input,
			UpdatedPermissions: p.UpdatedPermissions, DecisionClassification: p.Classification,
		}, nil
	case Deny:
		return permissionReply{
			Behavior: BehaviorDeny, ToolUseID: r.ToolUseID, Message: cmp.Or(p.Message, "Permission denied"),
			Interrupt: p.Interrupt, DecisionClassification: p.Classification,
		}, nil
	}
	return permissionReply{}, errors.New("claudeagent: CanUseTool returned no Allow or Deny")
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

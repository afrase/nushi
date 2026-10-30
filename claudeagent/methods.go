package claudeagent

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"uuid"
)

// UserInput is a user message for claude: Text, or Content's blocks.
type UserInput struct {
	Text    string
	Content []Block
	UUID    string // "" = a new one; claude echoes it and names it in results
	// Priority is when claude takes it during a turn; "" = claude's
	// default.
	Priority Priority
	// Origin says who wrote it; nil = a person ({"kind":"human"}), which
	// is what claude's checks for a person's say-so trust.
	Origin          *Origin
	NoQuery         bool   // adds it to the conversation without a turn
	ParentToolUseID string // the tool call it answers, if any
}

// Priority is when claude takes a user message that comes during a turn.
type Priority string

// The priorities.
const (
	PriorityNow   Priority = "now"   // at once, interrupting the turn
	PriorityNext  Priority = "next"  // at the turn's next step
	PriorityLater Priority = "later" // once the turn ends
)

// userLine is a user message as written: the SDKs' shape.
type userLine struct {
	Type            string      `json:"type"`       // "user"
	SessionID       string      `json:"session_id"` // always "": claude fills it in
	UUID            string      `json:"uuid"`
	Origin          *Origin     `json:"origin"`
	Message         userMessage `json:"message"`
	ParentToolUseID *string     `json:"parent_tool_use_id"` // null at the top
	Priority        Priority    `json:"priority,omitempty"`
	ShouldQuery     *bool       `json:"shouldQuery,omitempty"` // only ever false: NoQuery
}

// userMessage is a user line's message: its content a string or blocks.
type userMessage struct {
	Role    string `json:"role"`
	Content any    `json:"content"`
}

// Send writes a user message and returns its uuid. It doesn't wait for
// claude to take it: claude queues what comes during a turn.
func (s *Session) Send(ctx context.Context, m UserInput) (string, error) {
	var content any
	switch {
	case m.Text != "" && m.Content != nil:
		return "", errors.New("claudeagent: a user message has Text or Content, not both")
	case m.Content != nil:
		content = m.Content
	case m.Text != "":
		content = m.Text
	default:
		return "", errors.New("claudeagent: an empty user message")
	}
	id := m.UUID
	if id == "" {
		id = uuid.NewV4().String()
	}
	origin := m.Origin
	if origin == nil {
		origin = &Origin{Kind: "human"}
	}
	line := userLine{
		Type: "user", UUID: id, Origin: origin, Message: userMessage{Role: "user", Content: content},
		Priority: m.Priority,
	}
	if m.ParentToolUseID != "" {
		line.ParentToolUseID = &m.ParentToolUseID
	}
	if m.NoQuery {
		line.ShouldQuery = new(false)
	}
	if err := s.write(ctx, line); err != nil {
		return "", err
	}
	return id, nil
}

// InterruptReceipt is what an interrupt left: the user messages claude
// still has queued, and the ones it dropped. Known is false when claude
// doesn't report them (no interrupt_receipt_v1), and then the lists mean
// nothing.
type InterruptReceipt struct {
	Known       bool            `json:"-"`
	StillQueued []string        `json:"still_queued"`
	Cancelled   []string        `json:"cancelled"`
	Raw         json.RawMessage `json:"-"`
}

// Interrupt stops the turn under way.
func (s *Session) Interrupt(ctx context.Context) (InterruptReceipt, error) {
	var r InterruptReceipt
	payload, err := s.request(ctx, ask{"interrupt"}, true)
	if err != nil {
		return r, err
	}
	r.Raw = payload
	if !s.Has("interrupt_receipt_v1") {
		return r, nil
	}
	if err := decodeAnswer("interrupt", payload, &r); err != nil {
		return r, err
	}
	r.Known = true
	return r, nil
}

// SetPermissionMode switches the session's permission mode. claude
// refuses BypassPermissions unless the session started with AllowBypass
// (code "bypass_disabled").
func (s *Session) SetPermissionMode(ctx context.Context, m PermissionMode) error {
	return s.do(ctx, struct {
		ask
		Mode PermissionMode `json:"mode"`
	}{ask{"set_permission_mode"}, m}, nil)
}

// SetModel switches the session's model; "" = the default.
func (s *Session) SetModel(ctx context.Context, model string) error {
	var m *string // null: the default
	if model != "" {
		m = &model
	}
	return s.do(ctx, struct {
		ask
		Model *string `json:"model"`
	}{ask{"set_model"}, m}, nil)
}

// ApplyFlagSettings changes settings for the rest of the session, as
// --settings would have set them (effortLevel, fastMode, agent…).
func (s *Session) ApplyFlagSettings(ctx context.Context, settings map[string]any) error {
	return s.do(ctx, struct {
		ask
		Settings map[string]any `json:"settings"`
	}{ask{"apply_flag_settings"}, settings}, nil)
}

// StopTask stops a background task: a command or a subagent.
func (s *Session) StopTask(ctx context.Context, taskID string) error {
	return s.do(ctx, struct {
		ask
		TaskID string `json:"task_id"`
	}{ask{"stop_task"}, taskID}, nil)
}

// CancelAsyncMessage drops a user message claude has queued and not yet
// taken, by its uuid.
func (s *Session) CancelAsyncMessage(ctx context.Context, uuid string) error {
	return s.do(ctx, struct {
		ask
		MessageUUID string `json:"message_uuid"`
	}{ask{"cancel_async_message"}, uuid}, nil)
}

// ContextUsage is how the context window is spent.
type ContextUsage struct {
	Categories   []ContextCategory `json:"categories"`
	TotalTokens  int               `json:"totalTokens"`
	MaxTokens    int               `json:"maxTokens"`
	RawMaxTokens int               `json:"rawMaxTokens"`
	Percentage   float64           `json:"percentage"`
	Model        string            `json:"model"`
	Raw          json.RawMessage   `json:"-"`
}

// ContextCategory is one kind of what fills the context window: the
// system prompt, tools, messages, free space.
type ContextCategory struct {
	Name       string `json:"name"`
	Tokens     int    `json:"tokens"`
	IsDeferred bool   `json:"isDeferred"`
}

// ContextUsage asks how the context window is spent; detail is "summary",
// "full" or "" (claude's default).
func (s *Session) ContextUsage(ctx context.Context, detail string) (*ContextUsage, error) {
	payload, err := s.request(ctx, struct {
		ask
		Detail string `json:"detail,omitempty"`
	}{ask{"get_context_usage"}, detail}, true)
	if err != nil {
		return nil, err
	}
	u := &ContextUsage{Raw: payload}
	if err := decodeAnswer("get_context_usage", payload, u); err != nil {
		return nil, err
	}
	return u, nil
}

// MCPServerStatus is an MCP server's state, as MCPServers and SystemInit
// report it; Raw has what else claude says of it (its tools, its
// config…).
type MCPServerStatus struct {
	Name   string          `json:"name"`
	Status string          `json:"status"` // "connected", "failed", "needs-auth", "pending", "disabled"…
	Error  string          `json:"error"`
	Scope  string          `json:"scope"`
	Raw    json.RawMessage `json:"-"`
}

// UnmarshalJSON decodes m, keeping it in Raw.
func (m *MCPServerStatus) UnmarshalJSON(data []byte) error {
	type plain MCPServerStatus
	if err := json.Unmarshal(data, (*plain)(m)); err != nil {
		return err
	}
	m.Raw = bytes.Clone(data)
	return nil
}

// MCPServers asks for the state of the session's MCP servers.
func (s *Session) MCPServers(ctx context.Context) ([]MCPServerStatus, error) {
	var r struct {
		MCPServers []MCPServerStatus `json:"mcpServers"`
	}
	if err := s.do(ctx, ask{"mcp_status"}, &r); err != nil {
		return nil, err
	}
	return r.MCPServers, nil
}

// MCPToggle turns an MCP server on or off for the session.
func (s *Session) MCPToggle(ctx context.Context, name string, on bool) error {
	return s.do(ctx, struct {
		ask
		ServerName string `json:"serverName"`
		Enabled    bool   `json:"enabled"`
	}{ask{"mcp_toggle"}, name, on}, nil)
}

// MCPReconnect reconnects an MCP server.
func (s *Session) MCPReconnect(ctx context.Context, name string) error {
	return s.do(ctx, struct {
		ask
		ServerName string `json:"serverName"`
	}{ask{"mcp_reconnect"}, name}, nil)
}

// RewindResult is what rewinding files did, or with a dry run would do.
type RewindResult struct {
	CanRewind    bool            `json:"canRewind"`
	Error        string          `json:"error"`
	FilesChanged []string        `json:"filesChanged"`
	Insertions   int             `json:"insertions"`
	Deletions    int             `json:"deletions"`
	Raw          json.RawMessage `json:"-"`
}

// RewindFiles puts the files claude changed back as they were when the
// user message userMessageID was sent.
func (s *Session) RewindFiles(ctx context.Context, userMessageID string, dryRun bool) (*RewindResult, error) {
	payload, err := s.request(ctx, struct {
		ask
		UserMessageID string `json:"user_message_id"`
		DryRun        bool   `json:"dry_run"`
	}{ask{"rewind_files"}, userMessageID, dryRun}, true)
	if err != nil {
		return nil, err
	}
	r := &RewindResult{Raw: payload}
	if err := decodeAnswer("rewind_files", payload, r); err != nil {
		return nil, err
	}
	return r, nil
}

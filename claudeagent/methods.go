package claudeagent

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
)

// UserInput is a user message for claude: Text, or Content's blocks.
type UserInput struct {
	Text    string
	Content []Block
	UUID    string // "" = a new one; claude echoes it and names it in results
	// Priority is when claude takes it during a turn: "now", "next" or
	// "later"; "" = claude's default.
	Priority string
	// Origin says who wrote it; nil = a person ({"kind":"human"}), which
	// is what claude's checks for a person's say-so trust.
	Origin          *Origin
	ShouldQuery     *bool  // false = add it to the conversation without a turn
	ParentToolUseID string // the tool call it answers, if any
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
		id = newUUID()
	}
	origin := m.Origin
	if origin == nil {
		origin = &Origin{Kind: "human"}
	}
	line := map[string]any{
		"type": "user", "session_id": "", "uuid": id, "origin": origin,
		"message":            map[string]any{"role": "user", "content": content},
		"parent_tool_use_id": nil,
	}
	if m.ParentToolUseID != "" {
		line["parent_tool_use_id"] = m.ParentToolUseID
	}
	if m.Priority != "" {
		line["priority"] = m.Priority
	}
	if m.ShouldQuery != nil {
		line["shouldQuery"] = *m.ShouldQuery
	}
	if err := s.write(ctx, line); err != nil {
		return "", err
	}
	return id, nil
}

// newUUID is a random (version 4) UUID.
func newUUID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
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
	payload, err := s.request(ctx, "interrupt", nil, true)
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
	return s.Request(ctx, "set_permission_mode", map[string]any{"mode": m}, nil)
}

// SetModel switches the session's model; "" = the default.
func (s *Session) SetModel(ctx context.Context, model string) error {
	var v any
	if model != "" {
		v = model
	}
	return s.Request(ctx, "set_model", map[string]any{"model": v}, nil)
}

// ApplyFlagSettings changes settings for the rest of the session, as
// --settings would have set them (effortLevel, fastMode, agent…).
func (s *Session) ApplyFlagSettings(ctx context.Context, settings map[string]any) error {
	return s.Request(ctx, "apply_flag_settings", map[string]any{"settings": settings}, nil)
}

// StopTask stops a background task: a command or a subagent.
func (s *Session) StopTask(ctx context.Context, taskID string) error {
	return s.Request(ctx, "stop_task", map[string]any{"task_id": taskID}, nil)
}

// CancelAsyncMessage drops a user message claude has queued and not yet
// taken, by its uuid.
func (s *Session) CancelAsyncMessage(ctx context.Context, uuid string) error {
	return s.Request(ctx, "cancel_async_message", map[string]any{"message_uuid": uuid}, nil)
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
	req := map[string]any{}
	if detail != "" {
		req["detail"] = detail
	}
	payload, err := s.request(ctx, "get_context_usage", req, true)
	if err != nil {
		return nil, err
	}
	u := &ContextUsage{Raw: payload}
	if err := decodeAnswer("get_context_usage", payload, u); err != nil {
		return nil, err
	}
	return u, nil
}

// MCPServerStatus is an MCP server's state; Raw has what else claude
// says of it (its tools, its config…).
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

// MCPStatus asks for the state of the session's MCP servers.
func (s *Session) MCPStatus(ctx context.Context) ([]MCPServerStatus, error) {
	var r struct {
		MCPServers []MCPServerStatus `json:"mcpServers"`
	}
	if err := s.Request(ctx, "mcp_status", nil, &r); err != nil {
		return nil, err
	}
	return r.MCPServers, nil
}

// MCPToggle turns an MCP server on or off for the session.
func (s *Session) MCPToggle(ctx context.Context, name string, on bool) error {
	return s.Request(ctx, "mcp_toggle", map[string]any{"serverName": name, "enabled": on}, nil)
}

// MCPReconnect reconnects an MCP server.
func (s *Session) MCPReconnect(ctx context.Context, name string) error {
	return s.Request(ctx, "mcp_reconnect", map[string]any{"serverName": name}, nil)
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
	payload, err := s.request(ctx, "rewind_files", map[string]any{"user_message_id": userMessageID, "dry_run": dryRun}, true)
	if err != nil {
		return nil, err
	}
	r := &RewindResult{Raw: payload}
	if err := decodeAnswer("rewind_files", payload, r); err != nil {
		return nil, err
	}
	return r, nil
}

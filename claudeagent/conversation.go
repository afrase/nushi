package claudeagent

import "encoding/json"

// APIMessage is a Messages API message: what the model wrote.
type APIMessage struct {
	ID          string          `json:"id"`
	Role        string          `json:"role"`
	Model       string          `json:"model"`
	Content     Blocks          `json:"content"`
	StopReason  string          `json:"stop_reason"`
	StopDetails json.RawMessage `json:"stop_details,omitempty"` // a refusal's explanation, among others
	Usage       *Usage          `json:"usage,omitempty"`
}

// Assistant is the model's message. claude writes one per completed
// content block, so several share Message.ID; their StopReason and Usage
// aren't final: the Result's are.
type Assistant struct {
	Envelope
	Message         APIMessage `json:"message"`
	ParentToolUseID string     `json:"parent_tool_use_id"` // the subagent's tool call; "" at the top
	Error           string     `json:"error"`              // e.g. "authentication_failed", "rate_limit"
	AgentID         string     `json:"agent_id"`
}

// User is a user message: a tool's result, or with
// Options.ReplayUserMessages the echo of one we sent.
type User struct {
	Envelope
	Message struct {
		Role    string `json:"role"`
		Content Blocks `json:"content"`
	} `json:"message"`
	ParentToolUseID string          `json:"parent_tool_use_id"`
	ToolUseResult   json.RawMessage `json:"tool_use_result"` // the tool's structured output
	IsReplay        bool            `json:"isReplay"`
	IsSynthetic     bool            `json:"isSynthetic"`
	Origin          *Origin         `json:"origin"`
	Timestamp       string          `json:"timestamp"`
}

// Result ends a turn. Its cost and ModelUsage count the whole session so
// far; Usage counts the turn.
type Result struct {
	Envelope
	IsError           bool                  `json:"is_error"`
	Result            string                `json:"result"` // the answer's text, for a success
	Errors            []string              `json:"errors"` // for an error
	StopReason        string                `json:"stop_reason"`
	TerminalReason    string                `json:"terminal_reason"`
	DurationMS        int64                 `json:"duration_ms"`
	DurationAPIMS     int64                 `json:"duration_api_ms"`
	NumTurns          int                   `json:"num_turns"`
	TotalCostUSD      float64               `json:"total_cost_usd"`
	Usage             Usage                 `json:"usage"`
	ModelUsage        map[string]ModelUsage `json:"modelUsage"`
	PermissionDenials json.RawMessage       `json:"permission_denials"`
	Origin            *Origin               `json:"origin"` // what started the turn
	UserMessageUUID   string                `json:"user_message_uuid"`
	UserMessageUUIDs  []string              `json:"user_message_uuids"` // the user messages the turn took
	FastModeState     string                `json:"fast_mode_state"`    // "on", "off" or "cooldown"
	// FastModeDisabledReason is why fast mode is off, when claude says.
	FastModeDisabledReason string `json:"fast_mode_disabled_reason"`
}

// ModelUsage is one model's use over the session.
type ModelUsage struct {
	InputTokens              int     `json:"inputTokens"`
	OutputTokens             int     `json:"outputTokens"`
	CacheReadInputTokens     int     `json:"cacheReadInputTokens"`
	CacheCreationInputTokens int     `json:"cacheCreationInputTokens"`
	ContextWindow            int     `json:"contextWindow"`
	CostUSD                  float64 `json:"costUSD"`
}

// StreamEvent is a Messages API stream event, as the model writes, with
// Options.IncludePartialMessages.
type StreamEvent struct {
	Envelope
	Event           Event  `json:"event"`
	ParentToolUseID string `json:"parent_tool_use_id"`
}

// Event is a stream event: message_start (Message), content_block_start
// (Index, ContentBlock), content_block_delta (Index, Delta),
// content_block_stop (Index), message_delta (Delta, Usage) or
// message_stop.
type Event struct {
	Type         string      `json:"type"`
	Index        int         `json:"index"`
	Message      *APIMessage `json:"message,omitempty"`
	ContentBlock *Block      `json:"content_block,omitempty"`
	Delta        *Delta      `json:"delta,omitempty"`
	Usage        *Usage      `json:"usage,omitempty"`
}

// Delta is what a content_block_delta adds (Type text_delta: Text;
// thinking_delta: Thinking; input_json_delta: PartialJSON;
// signature_delta: Signature), or what a message_delta changes
// (StopReason, StopDetails).
type Delta struct {
	Type        string          `json:"type"`
	Text        string          `json:"text"`
	Thinking    string          `json:"thinking"`
	PartialJSON string          `json:"partial_json"`
	Signature   string          `json:"signature"`
	StopReason  string          `json:"stop_reason"`
	StopDetails json.RawMessage `json:"stop_details,omitempty"`
}

// ToolProgress says a tool is still running.
type ToolProgress struct {
	Envelope
	ToolUseID          string  `json:"tool_use_id"`
	ToolName           string  `json:"tool_name"`
	ParentToolUseID    string  `json:"parent_tool_use_id"`
	ElapsedTimeSeconds float64 `json:"elapsed_time_seconds"`
	TaskID             string  `json:"task_id"`
}

// RateLimit is the account's rate limit state; Info is claude's
// rate_limit_info as it is.
type RateLimit struct {
	Envelope
	Info json.RawMessage `json:"rate_limit_info"`
}

// ConversationReset is the conversation starting over (/clear and the
// like) as NewConversationID.
type ConversationReset struct {
	Envelope
	NewConversationID string `json:"new_conversation_id"`
	Trigger           string `json:"trigger"`
}

// AuthStatus is claude signing in.
type AuthStatus struct {
	Envelope
	IsAuthenticating bool     `json:"isAuthenticating"`
	Output           []string `json:"output"`
	Error            string   `json:"error"`
}

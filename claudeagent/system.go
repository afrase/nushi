package claudeagent

import "encoding/json"

// The system messages: type "system", each subtype its own type. Each has
// the fields a client acts on; Raw has the rest.

var systemDecoders = map[string]func() Message{
	"init":                      func() Message { return new(SystemInit) },
	"status":                    func() Message { return new(Status) },
	"compact_boundary":          func() Message { return new(CompactBoundary) },
	"session_state_changed":     func() Message { return new(SessionState) },
	"commands_changed":          func() Message { return new(CommandsChanged) },
	"task_started":              func() Message { return new(TaskStarted) },
	"task_progress":             func() Message { return new(TaskProgress) },
	"task_updated":              func() Message { return new(TaskUpdated) },
	"task_notification":         func() Message { return new(TaskNotification) },
	"background_tasks_changed":  func() Message { return new(BackgroundTasksChanged) },
	"informational":             func() Message { return new(Informational) },
	"permission_denied":         func() Message { return new(PermissionDenied) },
	"model_refusal_fallback":    func() Message { return new(ModelRefusalFallback) },
	"model_refusal_no_fallback": func() Message { return new(ModelRefusalNoFallback) },
	"local_command_output":      func() Message { return new(LocalCommandOutput) },
	"elicitation_complete":      func() Message { return new(ElicitationComplete) },
	"memory_recall":             func() Message { return new(MemoryRecall) },
	"api_retry":                 func() Message { return new(APIRetry) },
	"hook_started":              func() Message { return new(HookStarted) },
	"hook_progress":             func() Message { return new(HookProgress) },
	"hook_response":             func() Message { return new(HookResponse) },
}

// SystemInit starts each turn: the session's model, mode, tools and
// commands, and the protocol capabilities claude supports.
type SystemInit struct {
	Envelope
	ClaudeCodeVersion string         `json:"claude_code_version"`
	Cwd               string         `json:"cwd"`
	Model             string         `json:"model"`
	PermissionMode    PermissionMode `json:"permissionMode"`
	FastModeState     string         `json:"fast_mode_state"`
	Effort            string         `json:"effort"`
	APIKeySource      string         `json:"apiKeySource"`
	Tools             []string       `json:"tools"`
	SlashCommands     []string       `json:"slash_commands"`
	// TerminalSlashCommands are the commands only claude's terminal runs.
	TerminalSlashCommands []string          `json:"terminal_slash_commands"`
	MCPServers            []MCPServerStatus `json:"mcp_servers"` // their names and states
	Capabilities          []string          `json:"capabilities"`
}

// Status is a change of what claude is doing (Status "compacting",
// "requesting", or "" for nothing), or of the permission mode.
type Status struct {
	Envelope
	Status         string         `json:"status"`
	PermissionMode PermissionMode `json:"permissionMode"`
	CompactResult  string         `json:"compact_result"`
	CompactError   string         `json:"compact_error"`
}

// CompactBoundary marks where the conversation was compacted.
type CompactBoundary struct {
	Envelope
	CompactMetadata struct {
		Trigger    string `json:"trigger"` // "manual" or "auto"
		PreTokens  int    `json:"pre_tokens"`
		PostTokens int    `json:"post_tokens"`
		DurationMS int64  `json:"duration_ms"`
	} `json:"compact_metadata"`
}

// SessionState is the session going "idle", "running" or
// "requires_action". HostOnly marks the form claude sends an SDK host;
// the two carry the same news.
type SessionState struct {
	Envelope
	State    string `json:"state"`
	HostOnly bool   `json:"sdk_host_only"`
}

// Command is a slash command.
type Command struct {
	Name         string `json:"name"`
	Description  string `json:"description"`
	ArgumentHint string `json:"argumentHint"`
}

// CommandsChanged is the whole new set of slash commands.
type CommandsChanged struct {
	Envelope
	Commands []Command `json:"commands"`
}

// TaskUsage is what a task has used so far.
type TaskUsage struct {
	TotalTokens int   `json:"total_tokens"`
	ToolUses    int   `json:"tool_uses"`
	DurationMS  int64 `json:"duration_ms"`
}

// TaskStarted is a task starting: a subagent, or a background command.
// ToolUseID is the tool call that started it.
type TaskStarted struct {
	Envelope
	TaskID         string `json:"task_id"`
	RunID          string `json:"run_id"`
	ToolUseID      string `json:"tool_use_id"`
	Description    string `json:"description"`
	SubagentType   string `json:"subagent_type"`
	TaskType       string `json:"task_type"`
	IsBackgrounded bool   `json:"is_backgrounded"`
	ParentTaskID   string `json:"parent_task_id"`
	Prompt         string `json:"prompt"`
}

// TaskProgress is a running task's progress.
type TaskProgress struct {
	Envelope
	TaskID       string    `json:"task_id"`
	RunID        string    `json:"run_id"`
	ToolUseID    string    `json:"tool_use_id"`
	Description  string    `json:"description"`
	Usage        TaskUsage `json:"usage"`
	LastToolName string    `json:"last_tool_name"`
	Summary      string    `json:"summary"`
}

// TaskUpdated is a change to a task; Patch has only what changed.
type TaskUpdated struct {
	Envelope
	TaskID string `json:"task_id"`
	RunID  string `json:"run_id"`
	Patch  struct {
		Status         string `json:"status"`
		Description    string `json:"description"`
		Error          string `json:"error"`
		IsBackgrounded *bool  `json:"is_backgrounded"`
	} `json:"patch"`
}

// TaskNotification is a task's end: Status "completed", "failed" or
// "stopped".
type TaskNotification struct {
	Envelope
	TaskID     string     `json:"task_id"`
	RunID      string     `json:"run_id"`
	ToolUseID  string     `json:"tool_use_id"`
	Status     string     `json:"status"`
	Reason     string     `json:"reason"`
	OutputFile string     `json:"output_file"`
	Summary    string     `json:"summary"`
	Usage      *TaskUsage `json:"usage"`
}

// BackgroundTasksChanged is the whole new set of background tasks, to
// replace the last one.
type BackgroundTasksChanged struct {
	Envelope
	Tasks json.RawMessage `json:"tasks"`
}

// Informational is a notice for the user: Level "info", "notice",
// "suggestion" or "warning".
type Informational struct {
	Envelope
	Content             string `json:"content"`
	Level               string `json:"level"`
	ToolUseID           string `json:"tool_use_id"`
	PreventContinuation bool   `json:"prevent_continuation"`
}

// PermissionDenied is a tool call claude refused without asking.
type PermissionDenied struct {
	Envelope
	ToolName           string `json:"tool_name"`
	ToolUseID          string `json:"tool_use_id"`
	AgentID            string `json:"agent_id"`
	DecisionReasonType string `json:"decision_reason_type"`
	DecisionReason     string `json:"decision_reason"`
	Message            string `json:"message"`
}

// ModelRefusalFallback is a refusal that claude retried on another model.
type ModelRefusalFallback struct {
	Envelope
	Trigger                string `json:"trigger"`
	OriginalModel          string `json:"original_model"`
	FallbackModel          string `json:"fallback_model"`
	APIRefusalExplanation  string `json:"api_refusal_explanation"`
	RefusedUserMessageUUID string `json:"refused_user_message_uuid"`
	Content                string `json:"content"`
}

// ModelRefusalNoFallback is a refusal with no model to retry on.
type ModelRefusalNoFallback struct {
	Envelope
	OriginalModel          string `json:"original_model"`
	APIRefusalExplanation  string `json:"api_refusal_explanation"`
	RefusedUserMessageUUID string `json:"refused_user_message_uuid"`
	Content                string `json:"content"`
}

// LocalCommandOutput is what a slash command claude ran itself printed.
type LocalCommandOutput struct {
	Envelope
	Content string `json:"content"`
}

// ElicitationComplete says an MCP server's URL elicitation finished.
type ElicitationComplete struct {
	Envelope
	MCPServerName string `json:"mcp_server_name"`
	ElicitationID string `json:"elicitation_id"`
}

// MemoryRecall is memories claude recalled for the turn.
type MemoryRecall struct {
	Envelope
	Mode     string          `json:"mode"`
	Memories json.RawMessage `json:"memories"`
}

// APIRetry is claude retrying a failed API request.
type APIRetry struct {
	Envelope
	Attempt      int    `json:"attempt"`
	MaxRetries   int    `json:"max_retries"`
	RetryDelayMS int64  `json:"retry_delay_ms"`
	ErrorStatus  *int   `json:"error_status"`
	Error        string `json:"error"`
}

// Hook names a hook run: its id, name and event (PreToolUse…).
type Hook struct {
	HookID    string `json:"hook_id"`
	HookName  string `json:"hook_name"`
	HookEvent string `json:"hook_event"`
}

// HookStarted is a hook starting.
type HookStarted struct {
	Envelope
	Hook
}

// HookProgress is what a running hook has written so far.
type HookProgress struct {
	Envelope
	Hook
	Stdout string `json:"stdout"`
	Stderr string `json:"stderr"`
	Output string `json:"output"`
}

// HookResponse is a hook's end: Outcome "success", "error" or
// "cancelled".
type HookResponse struct {
	Envelope
	Hook
	Stdout   string `json:"stdout"`
	Stderr   string `json:"stderr"`
	Output   string `json:"output"`
	ExitCode *int   `json:"exit_code"`
	Outcome  string `json:"outcome"`
}

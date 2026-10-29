package claudeagent

import (
	"encoding/json"
	"testing"
)

// The lines are shaped as claude 2.1.312's schema says, as TestDecode's.
func TestDecodeSystem(t *testing.T) {
	five := 5
	checkDecode(t, []decodeCase{
		{
			`{"type":"system","subtype":"init","claude_code_version":"2.1.312","cwd":"/w","tools":["Bash"],"mcp_servers":[{"name":"t","status":"connected"}],"model":"claude-opus-5","permissionMode":"default","slash_commands":["compact"],"apiKeySource":"none","fast_mode_state":"off","effort":"high","capabilities":["interrupt_receipt_v1"],"agents":["x"],"uuid":"u15","session_id":"s1"}`,
			&SystemInit{ClaudeCodeVersion: "2.1.312", Cwd: "/w", Model: "claude-opus-5", PermissionMode: "default", FastModeState: "off", Effort: "high",
				APIKeySource: "none", Tools: []string{"Bash"}, SlashCommands: []string{"compact"}, MCPServers: []MCPStatus{{"t", "connected"}},
				Capabilities: []string{"interrupt_receipt_v1"}},
		},
		{`{"type":"system","subtype":"status","status":null,"permissionMode":"plan","uuid":"u16","session_id":"s1"}`, &Status{PermissionMode: "plan"}},
		{`{"type":"system","subtype":"status","status":"compacting","compact_result":"success","uuid":"u17","session_id":"s1"}`, &Status{Status: "compacting", CompactResult: "success"}},
		{
			`{"type":"system","subtype":"compact_boundary","compact_metadata":{"trigger":"auto","pre_tokens":100,"post_tokens":10,"duration_ms":5},"uuid":"u18","session_id":"s1"}`,
			func() Message {
				m := &CompactBoundary{}
				m.CompactMetadata.Trigger, m.CompactMetadata.PreTokens, m.CompactMetadata.PostTokens, m.CompactMetadata.DurationMS = "auto", 100, 10, 5
				return m
			}(),
		},
		{`{"type":"system","subtype":"session_state_changed","state":"idle","uuid":"u19","session_id":"s1"}`, &SessionState{State: "idle"}},
		{`{"type":"system","subtype":"session_state_changed","state":"running","sdk_host_only":true,"uuid":"u20","session_id":"s1"}`, &SessionState{State: "running", HostOnly: true}},
		{
			`{"type":"system","subtype":"commands_changed","commands":[{"name":"review","description":"Review","argumentHint":"<pr>","aliases":[]}],"uuid":"u21","session_id":"s1"}`,
			&CommandsChanged{Commands: []Command{{"review", "Review", "<pr>"}}},
		},
		{
			`{"type":"system","subtype":"task_started","task_id":"t1","run_id":"r1","tool_use_id":"tu_1","description":"Explore","subagent_type":"Explore","task_type":"local_agent","is_backgrounded":true,"parent_task_id":"t0","prompt":"Look","uuid":"u22","session_id":"s1"}`,
			&TaskStarted{TaskID: "t1", RunID: "r1", ToolUseID: "tu_1", Description: "Explore", SubagentType: "Explore", TaskType: "local_agent", IsBackgrounded: true, ParentTaskID: "t0", Prompt: "Look"},
		},
		{
			`{"type":"system","subtype":"task_progress","task_id":"t1","description":"Explore","usage":{"total_tokens":10,"tool_uses":2,"duration_ms":30},"last_tool_name":"Read","uuid":"u23","session_id":"s1"}`,
			&TaskProgress{TaskID: "t1", Description: "Explore", Usage: TaskUsage{10, 2, 30}, LastToolName: "Read"},
		},
		{
			`{"type":"system","subtype":"task_updated","task_id":"t1","patch":{"status":"killed","is_backgrounded":false},"uuid":"u24","session_id":"s1"}`,
			func() Message {
				m, no := &TaskUpdated{TaskID: "t1"}, false
				m.Patch.Status, m.Patch.IsBackgrounded = "killed", &no
				return m
			}(),
		},
		{
			`{"type":"system","subtype":"task_notification","task_id":"t1","tool_use_id":"tu_1","status":"stopped","output_file":"/o","summary":"S","usage":{"total_tokens":1,"tool_uses":0,"duration_ms":2},"uuid":"u25","session_id":"s1"}`,
			&TaskNotification{TaskID: "t1", ToolUseID: "tu_1", Status: "stopped", OutputFile: "/o", Summary: "S", Usage: &TaskUsage{1, 0, 2}},
		},
		{`{"type":"system","subtype":"background_tasks_changed","tasks":[{"id":"t1"}],"uuid":"u26","session_id":"s1"}`, &BackgroundTasksChanged{Tasks: json.RawMessage(`[{"id":"t1"}]`)}},
		{
			`{"type":"system","subtype":"informational","content":"Heads up","level":"warning","prevent_continuation":true,"uuid":"u27","session_id":"s1"}`,
			&Informational{Content: "Heads up", Level: "warning", PreventContinuation: true},
		},
		{
			`{"type":"system","subtype":"permission_denied","tool_name":"Bash","tool_use_id":"tu_1","decision_reason_type":"rule","decision_reason":"deny rule","message":"No","uuid":"u28","session_id":"s1"}`,
			&PermissionDenied{ToolName: "Bash", ToolUseID: "tu_1", DecisionReasonType: "rule", DecisionReason: "deny rule", Message: "No"},
		},
		{
			`{"type":"system","subtype":"model_refusal_fallback","trigger":"refusal","original_model":"a","fallback_model":"b","api_refusal_explanation":"E","content":"C","uuid":"u29","session_id":"s1"}`,
			&ModelRefusalFallback{Trigger: "refusal", OriginalModel: "a", FallbackModel: "b", APIRefusalExplanation: "E", Content: "C"},
		},
		{
			`{"type":"system","subtype":"model_refusal_no_fallback","original_model":"a","refused_user_message_uuid":"p1","content":"C","uuid":"u30","session_id":"s1"}`,
			&ModelRefusalNoFallback{OriginalModel: "a", RefusedUserMessageUUID: "p1", Content: "C"},
		},
		{`{"type":"system","subtype":"local_command_output","content":"Context: 10%","uuid":"u31","session_id":"s1"}`, &LocalCommandOutput{Content: "Context: 10%"}},
		{`{"type":"system","subtype":"elicitation_complete","mcp_server_name":"m","elicitation_id":"e1","uuid":"u32","session_id":"s1"}`, &ElicitationComplete{MCPServerName: "m", ElicitationID: "e1"}},
		{`{"type":"system","subtype":"memory_recall","mode":"auto","memories":[],"uuid":"u33","session_id":"s1"}`, &MemoryRecall{Mode: "auto", Memories: json.RawMessage(`[]`)}},
		{
			`{"type":"system","subtype":"api_retry","attempt":1,"max_retries":5,"retry_delay_ms":500,"error_status":529,"error":"overloaded","uuid":"u34","session_id":"s1"}`,
			func() Message {
				s := 529
				return &APIRetry{Attempt: 1, MaxRetries: 5, RetryDelayMS: 500, ErrorStatus: &s, Error: "overloaded"}
			}(),
		},
		{`{"type":"system","subtype":"hook_started","hook_id":"h1","hook_name":"PostToolUse:Bash","hook_event":"PostToolUse","uuid":"u35","session_id":"s1"}`, &HookStarted{Hook: Hook{"h1", "PostToolUse:Bash", "PostToolUse"}}},
		{`{"type":"system","subtype":"hook_progress","hook_id":"h1","hook_name":"n","hook_event":"e","stdout":"o","stderr":"","output":"o","uuid":"u36","session_id":"s1"}`, &HookProgress{Hook: Hook{"h1", "n", "e"}, Stdout: "o", Output: "o"}},
		{
			`{"type":"system","subtype":"hook_response","hook_id":"h1","hook_name":"n","hook_event":"e","output":"","stdout":"","stderr":"x","exit_code":5,"outcome":"error","uuid":"u37","session_id":"s1"}`,
			&HookResponse{Hook: Hook{"h1", "n", "e"}, Stderr: "x", ExitCode: &five, Outcome: "error"},
		},
	})
}

// A system message whose fields don't decode as modelled is Unknown.
func TestDecodeSystemMistyped(t *testing.T) {
	line := `{"type":"system","subtype":"init","tools":"Bash"}`
	m, err := Decode([]byte(line))
	if u, ok := m.(*Unknown); err != nil || !ok || u.Err == nil || u.Subtype != "init" || string(u.Raw) != line {
		t.Errorf("%+v %v", m, err)
	}
}

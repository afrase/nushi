package acptest

// Codex makes an Agent answer as codex-acp 2.2.2 does where Nushi's
// features follow it: it names itself "fake-codex" and its fork copies a
// whole session (no cut at a message); a session starts in mode "agent",
// reported both as legacy modes and as a mode option, with a model option,
// an effort option ("reasoning_effort", category thought_level) and the
// legacy models list, whose ids carry the effort as a suffix
// ("m1[medium]"); it has no /context; and the prompt "run" runs a command
// whose output comes only in _meta (terminal_output_delta, then
// terminal_exit), its content a terminal.

var codexModes = []map[string]any{{"id": "read-only", "name": "Read-only"}, {"id": "workspace-write", "name": "Workspace access"},
	{"id": "agent", "name": "Auto review"}, {"id": "agent-full-access", "name": "Full access"}}

func codexInit() map[string]any {
	return map[string]any{"protocolVersion": 1, "agentInfo": map[string]any{"name": "fake-codex", "title": "Codex"},
		"agentCapabilities": map[string]any{"loadSession": true, "promptCapabilities": map[string]any{"image": true},
			"sessionCapabilities": map[string]any{"fork": map[string]any{}, "delete": map[string]any{}, "close": map[string]any{}, "list": map[string]any{}}}}
}

func codexSession(id string) map[string]any {
	var modes []map[string]any
	for _, m := range codexModes {
		modes = append(modes, map[string]any{"value": m["id"], "name": m["name"]})
	}
	return map[string]any{"sessionId": id,
		"modes":  map[string]any{"currentModeId": "agent", "availableModes": codexModes},
		"models": map[string]any{"currentModelId": "m1[medium]", "availableModels": []map[string]any{{"modelId": "m1[low]", "name": "M1 (low)"}, {"modelId": "m1[medium]", "name": "M1 (medium)"}}},
		"configOptions": []map[string]any{
			{"id": "mode", "name": "Mode", "category": "mode", "type": "select", "currentValue": "agent", "options": modes},
			{"id": "model", "name": "Model", "category": "model", "type": "select", "currentValue": "m1", "options": []map[string]any{{"value": "m1", "name": "M1"}}},
			{"id": "reasoning_effort", "name": "Reasoning effort", "category": "thought_level", "type": "select", "currentValue": "medium",
				"options": []map[string]any{{"value": "low", "name": "Low"}, {"value": "medium", "name": "Medium"}}},
		}}
}

// run plays a command as codex-acp reports one to a client without
// terminals.
func (a *Agent) run(session string) {
	a.update(session, map[string]any{"sessionUpdate": "tool_call", "toolCallId": "c1", "kind": "execute", "title": "echo hi", "status": "in_progress",
		"content": []map[string]any{{"type": "terminal", "terminalId": "c1"}}, "rawInput": map[string]any{"command": "echo hi"}})
	a.update(session, map[string]any{"sessionUpdate": "tool_call_update", "toolCallId": "c1",
		"_meta": map[string]any{"terminal_output_delta": map[string]any{"data": "hi\n", "terminal_id": "c1"}}})
	a.update(session, map[string]any{"sessionUpdate": "tool_call_update", "toolCallId": "c1", "status": "completed",
		"_meta": map[string]any{"terminal_exit": map[string]any{"exit_code": 0, "signal": nil, "terminal_id": "c1"}}})
	a.say(session, "Ran it.")
}

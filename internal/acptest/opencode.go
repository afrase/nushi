package acptest

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"strings"
)

// Opencode makes an Agent answer as opencode 2.2.6 (`opencode acp`) does
// where Nushi's features follow it (docs/facts/opencode.md): it names
// itself "fake-opencode"; a session has no legacy modes or models but the
// config options "model", "effort" (only for a model that has levels) and
// "mode" (build or plan), kept with the session, and setting one is
// answered with them all and no update; it lists its commands once it has
// answered a session/new, load or fork; a session it doesn't have is
// invalid params (-32602), not ACP's resource not found; the prompt
// "permission" writes a file, the call pending with no input before it
// runs with it, asking with the options "once", "always" and "reject"; the
// prompt "question" asks with an "Other" field named "<id>_custom"; and a
// rejected permission or a dismissed question ends the turn "cancelled".

func opencodeInit() map[string]any {
	none := map[string]any{}
	return map[string]any{"protocolVersion": 1, "agentInfo": map[string]any{"name": "fake-opencode", "version": "2.2.6"},
		"agentCapabilities": map[string]any{"loadSession": true, "_meta": map[string]any{"opencode/child-session-updates": true},
			"mcpCapabilities": map[string]any{"http": true, "sse": false}, "promptCapabilities": map[string]any{"embeddedContext": true, "image": true},
			"sessionCapabilities": map[string]any{"additionalDirectories": none, "close": none, "delete": none, "fork": none, "list": none, "resume": none}}}
}

// opencodeCommands is what opencode sends after it has opened a session:
// its three commands and "compact", which is ACP's own.
var opencodeCommands = map[string]any{"sessionUpdate": "available_commands_update", "availableCommands": []map[string]any{
	{"name": "init", "description": "guided AGENTS.md setup"},
	{"name": "review", "description": "review changes [commit|branch|pr], defaults to uncommitted"},
	{"name": "goal", "description": "keep working until an objective is met [pause|resume|clear]"},
	{"name": "compact", "description": "Compact the session"},
}}

// opencodeAnswer answers a request with opencode's result where it isn't
// the plain agent's, which is result; opened is the session the request
// opened, if it did (session/new, load or fork).
func (a *Agent) opencodeAnswer(f frame, opened string, result any) {
	var set struct{ SessionID, ConfigID, Value string }
	_ = json.Unmarshal(f.Params, &set)
	switch f.Method {
	case "initialize":
		result = opencodeInit()
	case "session/new", "session/fork":
		result = map[string]any{"sessionId": opened, "configOptions": a.History.opencodeOptions(opened, "", "")}
	case "session/load":
		result = map[string]any{"configOptions": a.History.opencodeOptions(opened, "", "")}
	case "session/set_config_option":
		result = map[string]any{"configOptions": a.History.opencodeOptions(set.SessionID, set.ConfigID, set.Value)}
	}
	r, _ := json.Marshal(result)
	a.send(frame{ID: f.ID, Result: r})
	if opened != "" {
		a.live(opened, opencodeCommands)
	}
}

// opencodeScript plays the prompts opencode has its own script for, and
// returns the turn's stop reason, or "" for the plain agent's script.
func (a *Agent) opencodeScript(session, text string) string {
	if !a.Opencode {
		return ""
	}
	switch {
	case strings.Contains(text, "permission"):
		return a.opencodePermission(session)
	case strings.Contains(text, "question"):
		return a.opencodeQuestion(session)
	}
	return ""
}

// opencodeOptions is session's config options as opencode answers them,
// option id first set to value if one is named. They are the history's, as
// opencode keeps them with the session: a restarted agent answers the same.
// Only the first model has effort levels, and a change of model puts the
// effort back to "default".
func (h *History) opencodeOptions(session, id, value string) []map[string]any {
	h.mu.Lock()
	defer h.mu.Unlock()
	cur := h.options[session]
	if cur == nil {
		cur = map[string]string{"model": "fake/fake-model", "effort": "default", "mode": "build"}
	}
	if id != "" {
		cur[id] = value
		if id == "model" {
			cur["effort"] = "default"
		}
		if h.options == nil {
			h.options = map[string]map[string]string{}
		}
		h.options[session] = cur
	}
	option := func(id, name, category string, choices ...map[string]any) map[string]any {
		return map[string]any{"id": id, "name": name, "category": category, "type": "select", "currentValue": cur[id], "options": choices}
	}
	out := []map[string]any{option("model", "Model", "model",
		map[string]any{"value": "fake/fake-model", "name": "fake/Fake Model"}, map[string]any{"value": "opencode/big-pickle", "name": "opencode/Big Pickle"})}
	if cur["model"] == "fake/fake-model" {
		effort := option("effort", "Effort", "thought_level",
			map[string]any{"value": "low", "name": "Low"}, map[string]any{"value": "high", "name": "High"}, map[string]any{"value": "default", "name": "Default"})
		effort["description"] = "Available effort levels for this model"
		out = append(out, effort)
	}
	return append(out, option("mode", "Session Mode", "mode",
		map[string]any{"value": "build", "name": "Build", "description": "The default agent. Executes tools based on configured permissions."},
		map[string]any{"value": "plan", "name": "Plan", "description": "Read-only agent for exploring the codebase and planning work before implementation."}))
}

// opencodeTool starts a tool call as opencode does: pending under the
// tool's name with no input, then in progress with it. It returns the
// call's id, a new one each time as a model's are.
func (a *Agent) opencodeTool(session, name, kind string, input map[string]any, at []map[string]any) string {
	a.mu.Lock()
	a.calls++
	id := fmt.Sprintf("call_%d_0", a.calls)
	a.mu.Unlock()
	a.update(session, map[string]any{"sessionUpdate": "tool_call", "toolCallId": id, "name": name, "title": name, "kind": kind,
		"status": "pending", "locations": []any{}, "rawInput": map[string]any{}})
	a.update(session, map[string]any{"sessionUpdate": "tool_call_update", "toolCallId": id, "status": "in_progress", "kind": kind, "title": name,
		"locations": at, "rawInput": input})
	return id
}

// opencodeToolEnd ends a tool call with its output, or with why it failed.
func (a *Agent) opencodeToolEnd(session, id, text string, failed bool) {
	status, out := "completed", map[string]any{"metadata": map[string]any{"truncated": false}}
	if failed {
		status, out = "failed", map[string]any{"metadata": map[string]any{}, "error": text}
	}
	a.update(session, map[string]any{"sessionUpdate": "tool_call_update", "toolCallId": id, "status": status,
		"content": []map[string]any{{"type": "content", "content": map[string]any{"type": "text", "text": text}}}, "rawOutput": out})
}

// opencodePermission plays opencode's write tool asking first (nothing is
// written), then names the option picked. "reject" and a cancelled request
// both fail the call and end the turn.
func (a *Agent) opencodePermission(session string) string {
	a.mu.Lock()
	path := filepath.Join(a.cwds[session], "w.txt")
	a.mu.Unlock()
	input, at := map[string]any{"path": path, "content": "one\ntwo\n"}, []map[string]any{{"path": path}}
	id := a.opencodeTool(session, "write", "edit", input, at)
	res := a.request("session/request_permission", map[string]any{"sessionId": session,
		"toolCall": map[string]any{"toolCallId": id, "name": "write", "title": path, "kind": "edit", "status": "pending", "locations": at, "rawInput": input,
			"content": []map[string]any{{"type": "diff", "path": path, "oldText": nil, "newText": "one\ntwo\n"}}},
		"options": []map[string]any{{"optionId": "once", "kind": "allow_once", "name": "Allow once"},
			{"optionId": "always", "kind": "allow_always", "name": "Always allow"}, {"optionId": "reject", "kind": "reject_once", "name": "Reject"}}})
	var r struct {
		Outcome struct{ Outcome, OptionID string } `json:"outcome"`
	}
	_ = json.Unmarshal(res, &r)
	if r.Outcome.Outcome != "selected" || r.Outcome.OptionID == "reject" {
		a.opencodeToolEnd(session, id, "The user declined this tool call", true)
		return "cancelled"
	}
	a.opencodeToolEnd(session, id, "Created file successfully: w.txt", false)
	a.say(session, "Permission: "+r.Outcome.Outcome+" "+r.Outcome.OptionID)
	return "end_turn"
}

// opencodeQuestion asks as opencode's question tool does, and says what
// came back. A form declined or cancelled fails the call and ends the turn.
func (a *Agent) opencodeQuestion(session string) string {
	choices := []map[string]any{{"label": "Red", "description": "A warm one"}, {"label": "Blue", "description": "A cool one"}}
	id := a.opencodeTool(session, "question", "other", map[string]any{"questions": []map[string]any{
		{"question": "Which colour do you want?", "header": "Colour", "options": choices}}}, []map[string]any{})
	res := a.request("elicitation/create", map[string]any{
		"sessionId": session, "toolCallId": id, "mode": "form", "message": "Questions",
		"requestedSchema": map[string]any{"type": "object", "required": []string{}, "properties": map[string]any{
			"q0": map[string]any{"type": "string", "title": "Colour", "description": "Which colour do you want?", "oneOf": []map[string]any{
				{"const": "Red", "title": "Red", "description": "A warm one"}, {"const": "Blue", "title": "Blue", "description": "A cool one"}}},
			"q0_custom": map[string]any{"type": "string", "title": "Colour (other)", "description": "Type your own answer"},
		}},
	})
	var r struct{ Action string }
	_ = json.Unmarshal(res, &r)
	if r.Action != "accept" {
		a.opencodeToolEnd(session, id, "The user dismissed this question", true)
		return "cancelled"
	}
	a.opencodeToolEnd(session, id, "User has answered your questions.", false)
	a.say(session, "Answer: "+strings.TrimSpace(string(res)))
	return "end_turn"
}

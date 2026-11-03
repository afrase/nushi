package antetest

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Report is what the fake subagent reports: an Agent call's result's
// report.
const Report = "## Found\n\nThe handler is in a.go."

// agentCall is the fake's Agent call.
const agentCall = "call_a"

// subagent plays an Agent call as Ante 0.3.2 was seen to (docs/facts/ante.md):
// its work reaches the parent as lines on the call, which a resume doesn't
// replay, and its whole events go to a log of its own, there before the
// call's end. A subagent whose model fails ends its call Completed, the
// failure in its report; a cancelled one's result is a string that doesn't
// name it. It says how the turn goes on.
func (h *Host) subagent(turn, text string) any {
	emit := func(ev any, logged bool) { h.emit(turn, ev, logged) }
	emit(map[string]any{"ToolStart": map[string]any{"id": agentCall, "name": "Agent", "args": map[string]any{
		"description": "Find the handler", "prompt": "Find where errors are handled", "subagent_type": "general"}}}, true)
	h.store.mu.Lock()
	h.store.n++
	child := fmt.Sprintf("suba_01M5PGWXGYZDBX24FTNTWH%04d", h.store.n)
	h.store.mu.Unlock()
	lines := func(ls ...string) {
		for i, line := range ls {
			emit(map[string]any{"ToolUpdate": map[string]any{"tool_use_id": agentCall, "seq": i + 1, "message": line}}, false)
		}
	}
	save := func(events []any) {
		if !strings.Contains(text, "unsaved") {
			h.store.saveSubagent(h.id, child, turn, events)
		}
	}
	end := func(status string, result any) {
		emit(map[string]any{"ToolEnd": map[string]any{"tool_use_id": agentCall, "tool_name": "Agent", "status": status, "result_json": result}}, true)
	}
	result := func(report string, tools int) map[string]any {
		return map[string]any{"report": report, "session_id": child, "tool_use_count": tools, "total_duration_ms": 1200,
			"usage": map[string]any{"input_tokens": 5, "output_tokens": 1}}
	}
	switch {
	case strings.Contains(text, "fail"):
		save([]any{turnEnd(turn, map[string]any{"Error": map[string]any{"kind": "invalid_request", "headline": "invalid request", "details": []string{"HTTP 400 Bad Request"}}})})
		end("Completed", result("...[interrupted] (invalid request: the model refused)", 0))
	case strings.Contains(text, "wait"):
		lines(`Read(file_path="/work/a.go")`, "Looking for the handler.", `Grep(path=".", pattern="handle")`)
		save([]any{readStart, readEnd, narration, grepStart,
			map[string]any{"ToolEnd": map[string]any{"tool_use_id": "tool_2", "tool_name": "Grep", "status": "Cancelled", "result_json": "Tool call cancelled."}},
			turnEnd(turn, map[string]any{"Interrupted": map[string]any{"reason": "turn cancelled"}})})
		if h.store.Waiting != nil {
			h.store.Waiting <- text
		}
		<-h.paused
		end("Cancelled", "Tool call cancelled.")
		return map[string]any{"Interrupted": map[string]any{"reason": "turn cancelled"}}
	default:
		lines(`Read(file_path="/work/a.go")`, "Looking for the handler.", `Grep(path=".", pattern="handle")`, "## Found")
		save([]any{readStart, readEnd, narration, grepStart, grepEnd,
			map[string]any{"ToolEnd": map[string]any{"tool_use_id": "tool_3", "tool_name": "Bash", "status": "Denied",
				"result_json": "Tool call denied and not executed: it requires approval."}},
			map[string]any{"AgentMessage": Report}, turnEnd(turn, "Completed")})
		emit(map[string]any{"UsageUpdate": map[string]any{"usage": map[string]any{"input_tokens": 5, "output_tokens": 1}}}, true)
		end("Completed", result(Report, 3))
	}
	emit(map[string]any{"AgentMessage": "It is in a.go."}, true)
	return "Completed"
}

// What the fake subagent does, as its log has it.
var (
	readStart = map[string]any{"ToolStart": map[string]any{"id": "tool_1", "name": "Read", "args": map[string]any{"file_path": "/work/a.go"}}}
	readEnd   = map[string]any{"ToolEnd": map[string]any{"tool_use_id": "tool_1", "tool_name": "Read", "status": "Completed",
		"result_json": map[string]any{"file_type": map[string]any{"Text": map[string]any{"lines": []string{"package a\n"}}}}}}
	narration = map[string]any{"AgentMessage": "Looking for the handler.\nIt should be near."}
	grepStart = map[string]any{"ToolStart": map[string]any{"id": "tool_2", "name": "Grep", "args": map[string]any{"path": ".", "pattern": "handle"}}}
	grepEnd   = map[string]any{"ToolEnd": map[string]any{"tool_use_id": "tool_2", "tool_name": "Grep", "status": "Completed",
		"result_json": map[string]any{"content": "a.go:3:func handle() {}"}}}
)

func turnEnd(turn string, status any) map[string]any {
	return map[string]any{"TurnEnd": map[string]any{"turn_id": turn, "status": status, "steps": 3}}
}

// saveSubagent writes a subagent's event log, where and as Ante does: an Info
// naming the call, its input and turn, events, then SessionEnd, which alone
// has no parent.
func (st *Store) saveSubagent(parent, child, turn string, events []any) {
	if st.Home == "" {
		return
	}
	dir := filepath.Join(st.Home, "sessions", parent, "subagents", child)
	_ = os.MkdirAll(dir, 0o700)
	all := append([]any{
		map[string]any{"Info": "Subagent " + child + " launched by Agent call " + agentCall + " in session " + parent + "."},
		map[string]any{"UserInput": "Find where errors are handled"},
		map[string]any{"TurnStart": map[string]any{"turn_id": turn}},
	}, events...)
	var log []byte
	for _, ev := range all {
		b, _ := json.Marshal(map[string]any{"timestamp": time.Now().UTC(), "id": "evt_x", "event": ev, "parent": turn})
		log = append(append(log, b...), '\n')
	}
	b, _ := json.Marshal(map[string]any{"timestamp": time.Now().UTC(), "id": "evt_x", "event": map[string]any{"SessionEnd": map[string]any{
		"session_id": child, "reason": "Shutdown", "usage": map[string]any{"input_tokens": 5, "output_tokens": 1}}}})
	_ = os.WriteFile(filepath.Join(dir, "events.jsonl"), append(append(log, b...), '\n'), 0o600)
}

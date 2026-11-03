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

// subagent plays an Agent call, as docs/facts/ante.md says Ante does: the
// subagent's work reaches the parent only as lines on the call, which a
// resume doesn't replay here (the harder case: the log alone has its steps),
// and its whole events go to a log of its own. It says how the turn goes on.
func (h *Host) subagent(turn, text string) any {
	const call = "call_a"
	h.emit(turn, map[string]any{"ToolStart": map[string]any{"id": call, "name": "Agent", "args": map[string]any{
		"description": "Find the handler", "prompt": "Find where errors are handled", "subagent_type": "explore"}}}, true)
	for i, line := range []string{`Read(file_path="a.go")`, "Looking for the handler.", `Grep(path=".", pattern="handle")`} {
		h.emit(turn, map[string]any{"ToolUpdate": map[string]any{"tool_use_id": call, "seq": i, "message": line}}, false)
	}
	if strings.Contains(text, "wait") {
		if h.store.Waiting != nil {
			h.store.Waiting <- text
		}
		<-h.paused
		h.emit(turn, map[string]any{"ToolEnd": map[string]any{"tool_use_id": call, "tool_name": "Agent", "status": "Cancelled",
			"result_json": "subagent cancelled"}}, true)
		return map[string]any{"Interrupted": map[string]any{"reason": "turn cancelled"}}
	}
	h.store.mu.Lock()
	h.store.n++
	child := fmt.Sprintf("ses_01M5PGWXGYZDBX24FTNTWH%04d", h.store.n)
	h.store.mu.Unlock()
	if !strings.Contains(text, "unsaved") {
		h.store.saveSubagent(h.id, child, turn)
	}
	h.emit(turn, map[string]any{"UsageUpdate": map[string]any{"usage": map[string]any{"input_tokens": 5, "output_tokens": 1}}}, true)
	h.emit(turn, map[string]any{"ToolEnd": map[string]any{"tool_use_id": call, "tool_name": "Agent", "status": "Completed",
		"result_json": map[string]any{"report": Report, "session_id": child, "tool_use_count": 2, "total_duration_ms": 1200}}}, true)
	h.emit(turn, map[string]any{"AgentMessage": "It is in a.go."}, true)
	return "Completed"
}

// saveSubagent writes a subagent's event log, where Ante keeps it.
func (st *Store) saveSubagent(parent, child, turn string) {
	if st.Home == "" {
		return
	}
	dir := filepath.Join(st.Home, "sessions", parent, "subagents", child)
	_ = os.MkdirAll(dir, 0o700)
	var log []byte
	for _, ev := range []any{
		map[string]any{"TurnStart": map[string]any{"turn_id": turn}},
		map[string]any{"UserInput": "Find where errors are handled"},
		map[string]any{"ToolStart": map[string]any{"id": "tool_1", "name": "Read", "args": map[string]any{"file_path": "a.go"}}},
		map[string]any{"ToolEnd": map[string]any{"tool_use_id": "tool_1", "tool_name": "Read", "status": "Completed",
			"result_json": map[string]any{"file_type": map[string]any{"Text": map[string]any{"lines": []string{"package a\n"}}}}}},
		map[string]any{"AgentMessage": "Looking for the handler."},
		map[string]any{"ToolStart": map[string]any{"id": "tool_2", "name": "Grep", "args": map[string]any{"path": ".", "pattern": "handle"}}},
		map[string]any{"ToolEnd": map[string]any{"tool_use_id": "tool_2", "tool_name": "Grep", "status": "Completed",
			"result_json": map[string]any{"content": "a.go:3:func handle() {}"}}},
		map[string]any{"ToolEnd": map[string]any{"tool_use_id": "tool_3", "tool_name": "Bash", "status": "Denied",
			"result_json": "Tool call denied by policy and was not executed."}},
		map[string]any{"AgentMessage": Report},
		map[string]any{"TurnEnd": map[string]any{"turn_id": turn, "status": "Completed", "steps": 3}},
	} {
		b, _ := json.Marshal(map[string]any{"timestamp": time.Now().UTC(), "id": "evt_x", "event": ev})
		log = append(append(log, b...), '\n')
	}
	_ = os.WriteFile(filepath.Join(dir, "events.jsonl"), log, 0o600)
}

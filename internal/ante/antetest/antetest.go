// Package antetest is a fake `ante serve --stdio` for tests, speaking Ante
// 0.2.14's protocol as the real one was seen to: ops in, events out, each
// event naming the op it answers. Sessions are kept in a Store, as Ante
// keeps them in its home (each saved one also as sessions/<id>/meta.json),
// so a host started later can resume or fork them. Inputs are answered by
// script, keyed on their text:
//
//   - containing "write": a Write of x.txt that, in mode "strict", waits
//     for approval first (TurnPause before ToolStart), then a message;
//   - containing "ask": an AskUser call and its Question pause, then the
//     answer as a message;
//   - containing "wait": nothing, until Interrupt or a Steer;
//   - containing "mcp": first an ExtensionRefreshed that adds the skill
//     "late", as an MCP server coming online would;
//   - anything else: "You said: <text>", as two deltas and the whole text.
//
// A session has the skill "review" (argument hint "<path>"); SlashCommand
// runs a skill as a turn without echoing an input, its text the skill's
// instructions ("<skill>\n<name>review</name>\n\nReview <args>\n</skill>"),
// and any other name as the input "/name args". Compact compacts, its
// summary "the summary", in an info block as Ante's.
package antetest

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// Store holds the saved sessions, by id, and writes their meta.json in Home.
type Store struct {
	Home string

	mu       sync.Mutex
	sessions map[string]*saved
	n        int
}

type saved struct {
	cwd, mode string
	model     string // "" is m1
	effort    string // "" is low
	skills    []string
	log       []string // the events a resume replays, as JSON
	inputs    []string // the inputs' ids, where a fork can cut (log index after)
	cuts      []int
}

// Host is one fake host on a connection.
type Host struct {
	store *Store
	w     io.Writer
	wmu   sync.Mutex

	mu      sync.Mutex
	id      string
	s       *saved
	turn    string
	paused  chan json.RawMessage // the answer to the running turn's pause
	steered chan string
}

// Serve runs a host on r and w until r ends or Shutdown.
func (st *Store) Serve(r io.Reader, w io.Writer) {
	h := &Host{store: st, w: w}
	sc := bufio.NewScanner(r)
	sc.Buffer(nil, 1<<26)
	for sc.Scan() {
		var m struct {
			Op json.RawMessage `json:"op"`
			ID string          `json:"id"`
		}
		if json.Unmarshal(sc.Bytes(), &m) != nil || !strings.HasPrefix(m.ID, "op_") || len(m.ID) != 29 {
			h.emit("", map[string]any{"Error": "Invalid OpMsg JSON"}, false)
			continue
		}
		if h.op(m.ID, m.Op) {
			return
		}
	}
}

func variant(raw json.RawMessage) (string, json.RawMessage) {
	var name string
	if json.Unmarshal(raw, &name) == nil {
		return name, nil
	}
	var m map[string]json.RawMessage
	_ = json.Unmarshal(raw, &m)
	for k, v := range m {
		return k, v
	}
	return "", nil
}

// emit writes an event; logged ones are saved for a resume to replay.
func (h *Host) emit(parent string, ev any, logged bool) {
	b, _ := json.Marshal(map[string]any{"timestamp": time.Now().UTC(), "id": "evt_x", "event": ev, "parent": parent})
	h.wmu.Lock()
	_, _ = h.w.Write(append(b, '\n'))
	h.wmu.Unlock()
	if logged && h.s != nil {
		h.store.mu.Lock()
		h.s.log = append(h.s.log, string(b))
		h.store.mu.Unlock()
	}
}

func (h *Host) info() map[string]any {
	model, effort := h.s.model, h.s.effort
	if model == "" {
		model, effort = "m1", "low"
	}
	m := map[string]any{"id": model}
	if effort != "" {
		m["effort"] = effort
	}
	return map[string]any{"session_id": h.id, "cwd": h.s.cwd, "permission_mode": h.s.mode,
		"model": m, "provider": map[string]any{"id": "fake"}, "skills": h.skills()}
}

// skills lists the session's skills, as SessionStart and
// ExtensionRefreshed do.
func (h *Host) skills() []any {
	h.store.mu.Lock()
	defer h.store.mu.Unlock()
	out := []any{map[string]any{"name": "review", "description": "Review code", "scope": "user", "argument_hint": "<path>"}}
	for _, n := range h.s.skills {
		out = append(out, map[string]any{"name": n, "description": nil, "scope": "project", "argument_hint": nil})
	}
	return out
}

func (h *Host) refreshed(parent string) {
	h.emit(parent, map[string]any{"ExtensionRefreshed": map[string]any{"session_id": h.id, "skills": h.skills(), "subagents": []any{}}}, false)
}

// input starts a turn for op id, which runs text.
func (h *Host) input(id, text string, echo bool) {
	h.store.mu.Lock()
	h.s.inputs, h.s.cuts = append(h.s.inputs, id), append(h.s.cuts, len(h.s.log))
	h.store.mu.Unlock()
	h.mu.Lock()
	h.turn, h.paused, h.steered = id, make(chan json.RawMessage, 1), make(chan string, 1)
	h.mu.Unlock()
	if echo {
		h.emit(id, map[string]any{"UserInput": text}, true)
	}
	if strings.Contains(text, "mcp") {
		h.store.mu.Lock()
		h.s.skills = append(h.s.skills, "late")
		h.store.mu.Unlock()
		h.refreshed(id)
	}
	go h.run(id, text)
}

func (h *Host) op(id string, raw json.RawMessage) (done bool) { //nolint:gocognit // one case per op the fake takes
	name, p := variant(raw)
	switch name {
	case "StartSession":
		var req struct{ Cwd string }
		_ = json.Unmarshal(p, &req)
		h.store.mu.Lock()
		if h.store.sessions == nil {
			h.store.sessions = map[string]*saved{}
		}
		h.store.n++
		h.id = fmt.Sprintf("ses_01M5PGWXGYZDBX24FTNTWH%04d", h.store.n)
		h.s = &saved{cwd: req.Cwd, mode: "strict"}
		h.store.sessions[h.id] = h.s
		h.store.mu.Unlock()
		h.store.save(h.id, h.s)
		h.emit(id, map[string]any{"SessionStart": h.info()}, false)
		h.refreshed(id)
	case "ResumeSession":
		var req struct {
			ID string `json:"session_id"`
		}
		_ = json.Unmarshal(p, &req)
		h.store.mu.Lock()
		s := h.store.sessions[req.ID]
		log := append([]string(nil), s.logOrNil()...)
		h.store.mu.Unlock()
		if s == nil {
			h.emit(id, map[string]any{"Error": "no session " + req.ID}, false)
			return false
		}
		h.id, h.s = req.ID, s
		h.emit(id, map[string]any{"SessionStart": h.info()}, false)
		h.refreshed(id)
		h.wmu.Lock()
		for _, l := range log {
			_, _ = h.w.Write([]byte(l + "\n"))
		}
		h.wmu.Unlock()
	case "UserInput":
		var text string
		_ = json.Unmarshal(p, &text)
		h.input(id, text, true)
	case "SlashCommand":
		var req struct{ Name, Args string }
		_ = json.Unmarshal(p, &req)
		if req.Name == "review" {
			h.input(id, "<skill>\n<name>review</name>\n\nReview "+req.Args+"\n</skill>", false)
		} else {
			h.input(id, strings.TrimSpace("/"+req.Name+" "+req.Args), true)
		}
	case "Compact":
		block := "compact-" + id
		h.emit(id, map[string]any{"InfoBlockStart": map[string]any{"id": block, "header": "Compacting conversation history", "loading": true}}, true)
		h.emit(id, "CompactStart", true)
		h.emit(id, map[string]any{"CompactEnd": map[string]any{"summary": "the summary"}}, true)
		h.emit(id, map[string]any{"InfoBlockAppend": map[string]any{"id": block, "detail": "Compaction complete"}}, true)
	case "Steer":
		var text string
		_ = json.Unmarshal(p, &text)
		h.emit(id, map[string]any{"UserInput": text}, true)
		h.mu.Lock()
		if h.steered != nil {
			select {
			case h.steered <- text:
			default:
			}
		}
		h.mu.Unlock()
	case "ApprovalResponse", "QuestionResponse":
		h.mu.Lock()
		if h.paused != nil {
			h.paused <- p
		}
		h.mu.Unlock()
	case "Interrupt":
		h.mu.Lock()
		if h.paused != nil {
			select {
			case h.paused <- nil:
			default:
			}
		}
		h.mu.Unlock()
	case "UpdateSession":
		var req struct {
			Mode  string `json:"permission_mode"`
			Model *struct {
				ID     string `json:"id"`
				Effort string `json:"effort"`
			} `json:"model"`
		}
		_ = json.Unmarshal(p, &req)
		if req.Mode != "" {
			h.s.mode = req.Mode
		}
		if m := req.Model; m != nil {
			h.s.model, h.s.effort = m.ID, m.Effort
			if m.Effort == "" && m.ID == "m1" { // the catalog's
				h.s.effort = "low"
			}
		}
		h.emit(id, map[string]any{"SessionUpdated": h.info()}, false)
	case "ContextReport":
		h.emit(id, map[string]any{"ContextReport": map[string]any{"system_prompt_tokens": 100, "messages_tokens": 50,
			"used_tokens": 150, "limit_tokens": 1000, "compact_buffer_tokens": 100}}, false)
	case "ForkSession":
		var req struct{ At string }
		_ = json.Unmarshal(p, &req)
		h.store.mu.Lock()
		cut := len(h.s.log)
		for i, in := range h.s.inputs {
			if in == req.At {
				cut = h.s.cuts[i]
			}
		}
		h.store.n++
		fork := fmt.Sprintf("ses_01M5PGWXGYZDBX24FTNTWH%04d", h.store.n)
		f := &saved{cwd: h.s.cwd, mode: h.s.mode, log: append([]string(nil), h.s.log[:cut]...)}
		for i, c := range h.s.cuts {
			if c < cut {
				f.inputs, f.cuts = append(f.inputs, h.s.inputs[i]), append(f.cuts, c)
			}
		}
		h.store.sessions[fork] = f
		h.store.mu.Unlock()
		h.store.save(fork, f)
		h.emit(id, map[string]any{"SessionForked": map[string]any{"forked_from": h.id, "session_id": fork}}, false)
	case "Shutdown":
		h.emit(id, "Goodbye", false)
		return true
	default:
		h.emit(id, map[string]any{"Error": "Invalid OpMsg JSON: unknown variant `" + name + "`"}, false)
	}
	return false
}

func (s *saved) logOrNil() []string {
	if s == nil {
		return nil
	}
	return s.log
}

// run plays an input's turn.
func (h *Host) run(turn, text string) {
	h.emit(turn, map[string]any{"TurnStart": map[string]any{"turn_id": turn}}, true)
	status := any("Completed")
	switch {
	case strings.Contains(text, "write"):
		call := map[string]any{"id": "call_w", "name": "Write", "args": map[string]any{"file_path": "x.txt", "content": "hi\n"}}
		decision := "Accept"
		if h.s.mode == "strict" {
			h.emit(turn, map[string]any{"TurnPause": map[string]any{"turn_id": turn, "reason": map[string]any{
				"Approval": map[string]any{"tools": []any{call}, "message": "approve"}}}}, true)
			var a struct {
				Responses []struct{ Decision string }
			}
			_ = json.Unmarshal(<-h.paused, &a)
			decision = "Deny"
			if len(a.Responses) == 1 {
				decision = a.Responses[0].Decision
			}
			h.emit(turn, map[string]any{"TurnResume": map[string]any{"turn_id": turn}}, true)
		}
		if decision == "Deny" {
			h.emit(turn, map[string]any{"ToolEnd": map[string]any{"tool_use_id": "call_w", "tool_name": "Write", "status": "Denied",
				"result_json": "Tool call denied by user and was not executed."}}, true)
		} else {
			h.emit(turn, map[string]any{"ToolStart": call}, true)
			h.emit(turn, map[string]any{"ToolEnd": map[string]any{"tool_use_id": "call_w", "tool_name": "Write", "status": "Completed",
				"result_json": map[string]any{"lines_written": 1}}}, true)
		}
		h.emit(turn, map[string]any{"AgentMessage": "Decision: " + decision}, true)
	case strings.Contains(text, "ask"):
		qs := []any{map[string]any{"header": "Color", "question": "Which color?", "multi_select": false,
			"options": []any{map[string]any{"label": "Red", "description": "warm"}, map[string]any{"label": "Blue", "description": "cool"}}}}
		h.emit(turn, map[string]any{"ToolStart": map[string]any{"id": "call_q", "name": "AskUser", "args": map[string]any{"questions": qs}}}, true)
		h.emit(turn, map[string]any{"TurnPause": map[string]any{"turn_id": turn, "reason": map[string]any{
			"Question": map[string]any{"tool_use_id": "call_q", "questions": qs}}}}, true)
		reply := <-h.paused
		h.emit(turn, map[string]any{"ToolEnd": map[string]any{"tool_use_id": "call_q", "tool_name": "AskUser", "status": "Completed",
			"result_json": map[string]any{"message": "answered"}}}, true)
		h.emit(turn, map[string]any{"AgentMessage": "Reply: " + string(reply)}, true)
	case strings.Contains(text, "wait"):
		select {
		case <-h.paused:
			status = map[string]any{"Interrupted": map[string]any{"reason": "turn cancelled"}}
		case s := <-h.steered:
			h.emit(turn, map[string]any{"AgentMessage": "Steered: " + s}, true)
		case <-time.After(10 * time.Second):
		}
	default:
		h.emit(turn, map[string]any{"MessageDelta": "You said: "}, true)
		h.emit(turn, map[string]any{"MessageDelta": text}, true)
		h.emit(turn, map[string]any{"AgentMessage": "You said: " + text}, true)
	}
	h.emit(turn, map[string]any{"UsageUpdate": map[string]any{"usage": map[string]any{"input_tokens": 10, "output_tokens": 2},
		"context": map[string]any{"used_tokens": 12, "limit_tokens": 1000}}}, true)
	h.emit(turn, map[string]any{"TurnEnd": map[string]any{"turn_id": turn, "status": status, "steps": 1}}, true)
	h.store.save(h.id, h.s)
}

// save writes a session's meta.json, as Ante does.
func (st *Store) save(id string, s *saved) {
	if st.Home == "" {
		return
	}
	dir := filepath.Join(st.Home, "sessions", id)
	_ = os.MkdirAll(dir, 0o700)
	b, _ := json.Marshal(map[string]any{"id": id, "dir": s.cwd, "first_user_message": "hi", "last_active_time": time.Now().UTC()})
	_ = os.WriteFile(filepath.Join(dir, "meta.json"), b, 0o600)
}

// Saved says whether a session is still in the home folder.
func (st *Store) Saved(id string) bool {
	_, err := os.Stat(filepath.Join(st.Home, "sessions", id))
	return err == nil
}

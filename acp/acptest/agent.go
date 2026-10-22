// Package acptest is a fake ACP agent for tests. It answers prompts by
// script, keyed on the prompt's text:
//
//   - containing "permission": a tool call that asks permission (options
//     "allow" and "reject"), then a message naming the option picked, or
//     the turn ends "cancelled" if the prompt was cancelled;
//   - containing "question": an elicitation form with one choice field
//     ("color": red, green or blue), then a message with the answer;
//   - containing "think": its thoughts in a few chunks, then a message;
//   - containing "plan": a three-step plan, each step ticked off in turn;
//   - containing "many": 150 messages, each after a tool call, quickly;
//   - containing "pwd": "cwd: <the session's cwd>";
//   - anything else: "You said: <text>", streamed in two chunks.
//
// Pause slows the "think" and "plan" scripts down, to watch them stream.
//
// Sessions are kept in a History, which session/load replays and
// session/fork copies; agents that share a History see each other's
// sessions, as a restarted agent would. A session takes any cwd.
package acptest

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"strconv"
	"strings"
	"sync"
	"time"
)

// History holds every session's updates, for session/load.
type History struct {
	mu       sync.Mutex
	sessions map[string][]json.RawMessage
}

func (h *History) add(session string, update any) {
	b, _ := json.Marshal(update)
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.sessions == nil {
		h.sessions = map[string][]json.RawMessage{}
	}
	h.sessions[session] = append(h.sessions[session], b)
}

// fork gives session to a copy of session from's history.
func (h *History) fork(from, to string) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.sessions[to] = append(h.sessions[to], h.sessions[from]...)
}

func (h *History) get(session string) ([]json.RawMessage, bool) {
	h.mu.Lock()
	defer h.mu.Unlock()
	u, ok := h.sessions[session]
	return append([]json.RawMessage(nil), u...), ok
}

// Agent is one fake agent process.
type Agent struct {
	History *History
	Pause   time.Duration

	w       io.Writer
	writeMu sync.Mutex
	mu      sync.Mutex
	nextID  int
	pending map[string]chan json.RawMessage
	cwds    map[string]string // by session: what session/new or session/load said
}

type frame struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *struct {
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

// Serve speaks ACP on r and w until r ends.
func (a *Agent) Serve(r io.Reader, w io.Writer) {
	a.w = w
	a.pending = map[string]chan json.RawMessage{}
	a.cwds = map[string]string{}
	sc := bufio.NewScanner(r)
	sc.Buffer(nil, 1<<30)
	for sc.Scan() {
		var f frame
		if json.Unmarshal(sc.Bytes(), &f) != nil {
			continue
		}
		if f.Method == "" { // a response to one of our requests
			a.mu.Lock()
			ch := a.pending[string(f.ID)]
			a.mu.Unlock()
			if ch != nil {
				ch <- f.Result
			}
			continue
		}
		if f.ID != nil {
			go a.answer(f)
		}
	}
}

func (a *Agent) send(f frame) {
	f.JSONRPC = "2.0"
	b, _ := json.Marshal(f)
	a.writeMu.Lock()
	defer a.writeMu.Unlock()
	a.w.Write(append(b, '\n'))
}

// request calls the client and waits for its result.
func (a *Agent) request(method string, params any) json.RawMessage {
	p, _ := json.Marshal(params)
	ch := make(chan json.RawMessage, 1)
	a.mu.Lock()
	a.nextID++
	id := json.RawMessage(strconv.Itoa(a.nextID))
	a.pending[string(id)] = ch
	a.mu.Unlock()
	a.send(frame{ID: id, Method: method, Params: p})
	return <-ch
}

// update sends a session/update and records it in the history.
func (a *Agent) update(session string, update map[string]any) {
	a.History.add(session, update)
	p, _ := json.Marshal(map[string]any{"sessionId": session, "update": update})
	a.send(frame{Method: "session/update", Params: p})
}

func (a *Agent) answer(f frame) {
	var p struct {
		SessionID string `json:"sessionId"`
		Cwd       string `json:"cwd"`
		Prompt    []struct {
			Text string `json:"text"`
		} `json:"prompt"`
	}
	json.Unmarshal(f.Params, &p)
	var result any
	switch f.Method {
	case "initialize":
		result = map[string]any{"protocolVersion": 1, "agentCapabilities": map[string]any{"loadSession": true,
			"sessionCapabilities": map[string]any{"fork": map[string]any{}}}}
	case "session/new", "session/fork":
		a.mu.Lock()
		a.nextID++
		id := fmt.Sprintf("fake-%d-%p", a.nextID, a)
		a.cwds[id] = p.Cwd
		a.mu.Unlock()
		a.History.add(id, nil)
		if f.Method == "session/fork" {
			a.History.fork(p.SessionID, id)
		}
		result = map[string]any{"sessionId": id}
	case "session/load":
		updates, ok := a.History.get(p.SessionID)
		if !ok {
			a.send(frame{ID: f.ID, Error: &struct {
				Message string `json:"message"`
			}{"no such session"}})
			return
		}
		a.mu.Lock()
		a.cwds[p.SessionID] = p.Cwd
		a.mu.Unlock()
		for _, u := range updates {
			if string(u) != "null" {
				a.send(frame{Method: "session/update", Params: json.RawMessage(`{"sessionId":"` + p.SessionID + `","update":` + string(u) + `}`)})
			}
		}
		result = map[string]any{}
	case "session/prompt":
		var text string
		for _, b := range p.Prompt {
			text += b.Text
		}
		result = map[string]any{"stopReason": a.prompt(p.SessionID, text)}
	default:
		result = map[string]any{}
	}
	r, _ := json.Marshal(result)
	a.send(frame{ID: f.ID, Result: r})
}

func (a *Agent) say(session, text string) {
	a.update(session, map[string]any{"sessionUpdate": "agent_message_chunk", "content": map[string]any{"type": "text", "text": text}})
}

// prompt runs the script for text and returns the turn's stop reason.
func (a *Agent) prompt(session, text string) string {
	a.History.add(session, map[string]any{"sessionUpdate": "user_message_chunk", "content": map[string]any{"type": "text", "text": text}})
	switch {
	case strings.Contains(text, "permission"):
		a.update(session, map[string]any{"sessionUpdate": "tool_call", "toolCallId": "t1", "title": "touch x", "kind": "execute", "status": "pending"})
		res := a.request("session/request_permission", map[string]any{
			"sessionId": session, "toolCall": map[string]any{"toolCallId": "t1"},
			"options": []map[string]any{{"optionId": "allow", "name": "Allow", "kind": "allow_once"}, {"optionId": "reject", "name": "Reject", "kind": "reject_once"}},
		})
		var r struct {
			Outcome struct{ Outcome, OptionID string } `json:"outcome"`
		}
		json.Unmarshal(res, &r)
		if r.Outcome.Outcome == "cancelled" { // the client stopped the turn
			return "cancelled"
		}
		a.update(session, map[string]any{"sessionUpdate": "tool_call_update", "toolCallId": "t1", "status": "completed"})
		a.say(session, "Permission: "+r.Outcome.Outcome+" "+r.Outcome.OptionID)
	case strings.Contains(text, "question"):
		res := a.request("elicitation/create", map[string]any{
			"sessionId": session, "mode": "form", "message": "Pick one",
			"requestedSchema": map[string]any{"type": "object", "properties": map[string]any{
				"color": map[string]any{"type": "string", "title": "Color", "enum": []string{"red", "green", "blue"}},
			}},
		})
		a.say(session, "Answer: "+string(res))
	case strings.Contains(text, "think"):
		for _, t := range []string{"The user wants me to think. ", "Let me look at the files first, ", "then decide what to change."} {
			time.Sleep(a.Pause)
			a.update(session, map[string]any{"sessionUpdate": "agent_thought_chunk", "content": map[string]any{"type": "text", "text": t}})
		}
		a.say(session, "Done thinking.")
	case strings.Contains(text, "pwd"):
		a.mu.Lock()
		cwd := a.cwds[session]
		a.mu.Unlock()
		a.say(session, "cwd: "+cwd)
	case strings.Contains(text, "many"):
		for i := range 150 {
			id := "many-" + strconv.Itoa(i)
			a.update(session, map[string]any{"sessionUpdate": "tool_call", "toolCallId": id, "title": "Read file" + strconv.Itoa(i) + ".go", "kind": "read", "status": "completed"})
			a.update(session, map[string]any{"sessionUpdate": "agent_message_chunk", "messageId": "m" + id, "content": map[string]any{"type": "text",
				"text": fmt.Sprintf("Step **%d**: read `file%d.go`.\n\n```go\nfunc f%d() int { return %d }\n```\n", i, i, i, i)}})
			time.Sleep(a.Pause / 20)
		}
	case strings.Contains(text, "plan"):
		steps := []string{"Read the code", "Make the change", "Run the tests"}
		for done := 0; done <= len(steps); done++ {
			var entries []map[string]any
			for i, s := range steps {
				status := map[bool]string{true: "completed", false: "pending"}[i < done]
				if i == done {
					status = "in_progress"
				}
				entries = append(entries, map[string]any{"content": s, "priority": "medium", "status": status})
			}
			a.update(session, map[string]any{"sessionUpdate": "plan", "entries": entries})
			time.Sleep(a.Pause)
		}
		a.say(session, "All done.")
	default:
		a.say(session, "You said: ")
		a.say(session, text)
	}
	return "end_turn"
}

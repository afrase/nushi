// Package acptest is a fake ACP agent for tests, shaped like Claude's
// agent (or like Codex's adapter, with Agent.Codex: codex.go; like omp,
// with Agent.Omp: omp.go; or like opencode, with Agent.Opencode:
// opencode.go). It answers prompts by script, keyed on the prompt's text:
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
//   - containing "wait": nothing, until the turn is cancelled (10 s at most);
//   - containing "subagent": a subagent, as claude-agent-acp showed one
//     without its own session, that runs the prompt as a command and ends;
//   - containing "screenshot": a tool call that returns an image
//     (Screenshot), then a message;
//   - containing "tool": a command run with the prompt as its input and
//     output;
//   - containing "garbage": a line that isn't JSON-RPC and an update that
//     isn't one, then a message;
//   - containing "safeguards": as Claude Code 2.1.312 when its safeguards
//     stop a response (docs/facts/claude.md): a message's start, then its
//     notice, then the reply it goes on with; its history keeps only the
//     reply;
//   - containing "stderr" (with any of the others): a line with a key in
//     it on Stderr;
//   - anything else: "You said: <text>", streamed in two chunks.
//
// A line "title: <title>" in any prompt first names the session, as
// Claude does (session_info_update); "late title: <title>" names it 100 ms
// after the turn has ended, as Claude may after a short first turn.
//
// Pause slows the "think" and "plan" scripts down, to watch them stream.
//
// Cancelling a turn (session/cancel) ends "think", "plan" and "many"
// between their steps, with stop reason "cancelled".
//
// Sessions are kept in a History, by folder as Claude keeps them:
// session/load finds a session only in the history of the request's cwd,
// session/fork in any folder's, writing the fork into the cwd's (as
// Claude's Go agent does, ADR 0014). Agents that share a History
// see each other's sessions, as a restarted agent would. Like Claude's
// agent, an agent takes prompts and config changes only for sessions it
// opened (session/new, load or fork), and session/delete deletes a session
// in whichever folder has it. session/list lists the History's sessions,
// titled with their first prompt.
package acptest

import (
	"bufio"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Agent is one fake agent process.
type Agent struct {
	History  *History
	Pause    time.Duration
	Codex    bool // answers as codex-acp does (codex.go)
	Omp      bool // answers as omp does (omp.go)
	Opencode bool // answers as opencode does (opencode.go)
	Images   bool // says it takes images in prompts (as plain agents don't)
	// For the log: what it writes to its stderr, how long session/load
	// takes, and whether it reopens a session it doesn't know (as if
	// another process had kept it), replaying nothing.
	Stderr    io.Writer
	LoadDelay time.Duration
	LoadAny   bool

	w       io.Writer
	writeMu sync.Mutex
	mu      sync.Mutex
	nextID  int
	pending map[string]chan json.RawMessage
	cwds    map[string]string // the sessions open here, by id: their cwd
	turns   map[string]*turn  // the running turn's, by session
	calls   int               // opencode's tool calls so far, for their ids
}

// turn is a running prompt's: cancelled once session/cancel came for it.
type turn struct{ cancelled bool }

type frame struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

// rpcError is a request's error: the plain agent's is only a message.
type rpcError struct {
	Code    int    `json:"code,omitempty"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

// Serve speaks ACP on r and w until r ends.
func (a *Agent) Serve(r io.Reader, w io.Writer) {
	a.w = w
	a.pending = map[string]chan json.RawMessage{}
	a.cwds = map[string]string{}
	a.turns = map[string]*turn{}
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
		var p struct {
			SessionID string `json:"sessionId"`
		}
		_ = json.Unmarshal(f.Params, &p)
		a.mu.Lock()
		switch f.Method {
		case "session/prompt": // in the order the frames come, before any cancel for it
			a.turns[p.SessionID] = &turn{}
		case "session/cancel":
			if t := a.turns[p.SessionID]; t != nil {
				t.cancelled = true
			}
		}
		a.mu.Unlock()
		if f.ID != nil {
			go a.answer(f)
		}
	}
}

// cancelled reports whether the session's running turn was cancelled.
func (a *Agent) cancelled(session string) bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	t := a.turns[session]
	return t != nil && t.cancelled
}

func (a *Agent) fail(f frame, msg string) {
	a.send(frame{ID: f.ID, Error: &rpcError{Message: msg}})
}

// noSession is the error for a session/load of a session the history
// doesn't have: opencode's is invalid params with the id, not ACP's
// resource not found (docs/facts/opencode.md).
func (a *Agent) noSession(id string) *rpcError {
	if a.Opencode {
		return &rpcError{Code: -32602, Message: "Invalid params: session not found: " + id, Data: map[string]any{"sessionId": id}}
	}
	return &rpcError{Message: "no such session"}
}

func (a *Agent) send(f frame) {
	f.JSONRPC = "2.0"
	b, _ := json.Marshal(f)
	a.writeMu.Lock()
	defer a.writeMu.Unlock()
	_, _ = a.w.Write(append(b, '\n'))
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

// update sends a session/update and records it in the session's history.
func (a *Agent) update(session string, update map[string]any) {
	a.mu.Lock()
	cwd := a.cwds[session]
	a.mu.Unlock()
	a.History.add(cwd, session, update)
	p, _ := json.Marshal(map[string]any{"sessionId": session, "update": update})
	a.send(frame{Method: "session/update", Params: p})
}

// live sends an update that the session's history doesn't keep.
func (a *Agent) live(session string, update map[string]any) {
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
	_ = json.Unmarshal(f.Params, &p)
	a.mu.Lock()
	_, open := a.cwds[p.SessionID]
	a.mu.Unlock()
	switch f.Method {
	case "session/prompt", "session/set_config_option", "session/set_mode", "_session/steering":
		if !open {
			a.fail(f, "Session not found")
			return
		}
	}
	var result any
	opened := "" // the session this request opened
	switch f.Method {
	case "initialize":
		caps := map[string]any{"fork": map[string]any{}, "delete": map[string]any{}, "close": map[string]any{}, "list": map[string]any{}}
		agentCaps := map[string]any{"loadSession": true, "sessionCapabilities": caps}
		if a.Images {
			agentCaps["promptCapabilities"] = map[string]any{"image": true}
		}
		result = map[string]any{"protocolVersion": 1, "agentCapabilities": agentCaps}
		if a.Codex {
			result = codexInit()
		}
		if a.Omp {
			result = ompInit()
		}
	case "session/list":
		var req struct{ Cwd, Cursor string }
		_ = json.Unmarshal(f.Params, &req)
		result = a.list(req.Cwd, req.Cursor)
	case "session/new", "session/fork":
		a.mu.Lock()
		a.nextID++
		id := fmt.Sprintf("fake-%d-%p", a.nextID, a)
		a.mu.Unlock()
		// Like Claude, a new session is only kept once it has a message.
		if f.Method == "session/fork" {
			if err := a.History.fork(p.Cwd, p.SessionID, id); err != nil {
				a.fail(f, err.Error())
				return
			}
		}
		a.mu.Lock()
		a.cwds[id] = p.Cwd
		a.mu.Unlock()
		opened, result = id, map[string]any{"sessionId": id}
		if a.Codex {
			result = codexSession(id)
		}
	case "session/load":
		time.Sleep(a.LoadDelay)
		updates, ok := a.History.get(p.Cwd, p.SessionID)
		if !ok && !a.LoadAny {
			a.send(frame{ID: f.ID, Error: a.noSession(p.SessionID)})
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
		opened, result = p.SessionID, map[string]any{}
	case "session/close", "session/delete":
		a.mu.Lock()
		delete(a.cwds, p.SessionID)
		a.mu.Unlock()
		if f.Method == "session/delete" {
			a.History.delete(p.SessionID)
		}
		result = map[string]any{}
	case "session/prompt":
		var blocks []string
		for _, b := range p.Prompt {
			blocks = append(blocks, b.Text)
		}
		result = map[string]any{"stopReason": a.prompt(p.SessionID, blocks)}
	default:
		result = map[string]any{}
	}
	if a.Opencode {
		a.opencodeAnswer(f, opened, result)
		return
	}
	r, _ := json.Marshal(result)
	a.send(frame{ID: f.ID, Result: r})
}

// list answers session/list a page at a time (the cursor is the next
// one's index): all at once, or, like codex-acp, two at a time from every
// folder's sessions, the other folders' then left out.
func (a *Agent) list(cwd, cursor string) map[string]any {
	all, size := a.History.list(cwd), 0
	if a.Codex {
		all, size = a.History.list(""), 2
	}
	from, _ := strconv.Atoi(cursor)
	to := len(all)
	if size > 0 {
		to = min(to, from+size)
	}
	page := []map[string]any{}
	for _, s := range all[min(from, to):to] {
		if cwd == "" || s["cwd"] == keyOf(cwd, "").cwd {
			page = append(page, s)
		}
	}
	out := map[string]any{"sessions": page}
	if to < len(all) {
		out["nextCursor"] = strconv.Itoa(to)
	}
	return out
}

func (a *Agent) say(session, text string) {
	a.update(session, map[string]any{"sessionUpdate": "agent_message_chunk", "content": map[string]any{"type": "text", "text": text}})
}

// prompt runs the script for text and returns the turn's stop reason.
func (a *Agent) prompt(session string, blocks []string) string { //nolint:gocognit,gocyclo // one case per script word
	a.mu.Lock()
	cwd := a.cwds[session]
	a.mu.Unlock()
	a.History.prompted(session, blocks)
	for _, b := range blocks { // a chunk per block, as Claude replays them
		a.History.add(cwd, session, map[string]any{"sessionUpdate": "user_message_chunk", "content": map[string]any{"type": "text", "text": b}})
	}
	text := strings.Join(blocks, "\n")
	if strings.Contains(text, "stderr") && a.Stderr != nil {
		_, _ = fmt.Fprintln(a.Stderr, "auth: using the key sk-ant-api03-Zr8fakeFAKEfake0123456789 from the environment")
	}
	for line := range strings.Lines(text) {
		if title, ok := strings.CutPrefix(strings.TrimSpace(line), "title: "); ok {
			a.update(session, map[string]any{"sessionUpdate": "session_info_update", "title": title})
		}
		if title, ok := strings.CutPrefix(strings.TrimSpace(line), "late title: "); ok {
			time.AfterFunc(100*time.Millisecond, func() {
				a.update(session, map[string]any{"sessionUpdate": "session_info_update", "title": title})
			})
		}
	}
	if stop := a.opencodeScript(session, text); stop != "" {
		return stop
	}
	switch {
	case a.Codex && strings.Contains(text, "run"):
		a.run(session)
	case a.Omp && strings.Contains(text, "question"):
		a.ompQuestion(session)
	case strings.Contains(text, "permission"):
		a.update(session, map[string]any{"sessionUpdate": "tool_call", "toolCallId": "t1", "title": "touch x", "kind": "execute", "status": "pending"})
		res := a.request("session/request_permission", map[string]any{
			"sessionId": session, "toolCall": map[string]any{"toolCallId": "t1"},
			"options": []map[string]any{{"optionId": "allow", "name": "Allow", "kind": "allow_once"}, {"optionId": "reject", "name": "Reject", "kind": "reject_once"}},
		})
		var r struct {
			Outcome struct{ Outcome, OptionID string } `json:"outcome"`
		}
		_ = json.Unmarshal(res, &r)
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
			if a.cancelled(session) {
				return "cancelled"
			}
			a.update(session, map[string]any{"sessionUpdate": "agent_thought_chunk", "content": map[string]any{"type": "text", "text": t}})
		}
		a.say(session, "Done thinking.")
	case strings.Contains(text, "wait"):
		for range 1000 {
			if a.cancelled(session) {
				return "cancelled"
			}
			time.Sleep(10 * time.Millisecond)
		}
	case strings.Contains(text, "subagent"):
		claudeCode := func(fields map[string]any) map[string]any { return map[string]any{"claudeCode": fields} }
		a.update(session, map[string]any{"sessionUpdate": "tool_call", "toolCallId": "a1", "title": "Agent", "kind": "think", "status": "in_progress",
			"rawInput": map[string]any{"subagent_type": "general-purpose", "prompt": text}, "_meta": claudeCode(map[string]any{"toolName": "Agent"})})
		a.update(session, map[string]any{"sessionUpdate": "tool_call", "toolCallId": "a1-step", "title": "Run", "kind": "execute", "status": "completed",
			"rawInput": map[string]any{"command": text}, "_meta": claudeCode(map[string]any{"toolName": "Bash", "parentToolUseId": "a1"})})
		a.update(session, map[string]any{"sessionUpdate": "tool_call_update", "toolCallId": "a1", "status": "completed",
			"_meta": claudeCode(map[string]any{"toolName": "Agent"})})
		a.say(session, "The subagent is done.")
	case strings.Contains(text, "screenshot"):
		a.update(session, map[string]any{"sessionUpdate": "tool_call", "toolCallId": "t3", "title": "Take a screenshot", "status": "in_progress"})
		a.update(session, map[string]any{"sessionUpdate": "tool_call_update", "toolCallId": "t3", "status": "completed",
			"content": []map[string]any{{"type": "content", "content": map[string]any{"type": "image", "mimeType": "image/png",
				"data": base64.StdEncoding.EncodeToString(Screenshot())}}}})
		a.say(session, "Took it.")
	case strings.Contains(text, "tool"):
		a.update(session, map[string]any{"sessionUpdate": "tool_call", "toolCallId": "t2", "title": "Run " + text, "kind": "execute",
			"status": "in_progress", "rawInput": map[string]any{"command": text}})
		a.update(session, map[string]any{"sessionUpdate": "tool_call_update", "toolCallId": "t2", "status": "completed",
			"content": []map[string]any{{"type": "content", "content": map[string]any{"type": "text", "text": "output of " + text}}}})
		a.say(session, "Ran it.")
	case strings.Contains(text, "safeguards"):
		for _, t := range []string{"Here is the first ", "part of an answer"} {
			a.live(session, map[string]any{"sessionUpdate": "agent_message_chunk", "messageId": "msg_stopped", "content": map[string]any{"type": "text", "text": t}})
		}
		a.live(session, map[string]any{"sessionUpdate": "agent_message_chunk", "_meta": map[string]any{"claudeCode": map[string]any{"kind": "informational", "level": "notice"}},
			"content": map[string]any{"type": "text", "text": "**Notice:** Opus 5.5's safeguards stopped the response above · continuing once with that noted"}})
		a.update(session, map[string]any{"sessionUpdate": "agent_message_chunk", "messageId": "msg_after", "content": map[string]any{"type": "text", "text": "Continued reply after the stop."}})
	case strings.Contains(text, "garbage"):
		a.writeMu.Lock()
		_, _ = io.WriteString(a.w, "this line isn't JSON-RPC\n")
		a.writeMu.Unlock()
		a.send(frame{Method: "session/update", Params: json.RawMessage(`{"sessionId":"` + session + `","update":"nonsense"}`)})
		a.say(session, "Sent garbage.")
	case strings.Contains(text, "pwd"):
		a.mu.Lock()
		cwd := a.cwds[session]
		a.mu.Unlock()
		a.say(session, "cwd: "+cwd)
	case strings.Contains(text, "many"):
		for i := range 150 {
			if a.cancelled(session) {
				return "cancelled"
			}
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
			if a.cancelled(session) {
				return "cancelled"
			}
		}
		a.say(session, "All done.")
	default:
		a.say(session, "You said: ")
		a.say(session, text)
	}
	return "end_turn"
}

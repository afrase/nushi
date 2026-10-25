// Package pigtest is a fake `pig --mode rpc` for tests, speaking PiG
// 0.5.3's RPC mode as the real one was seen to: commands in, responses
// (by id) and events out. Sessions are files in a folder, as PiG keeps
// them (a header line, then entries that make a tree), so a pig started
// later can open or fork them. Prompts are answered by script, keyed on
// their text:
//
//   - "/ask": an extension's select dialog (Red, Blue), then the choice
//     as a notification; the prompt is "handled", no run;
//   - "/hang": a command that never ends;
//   - containing "tool": a bash call (`ls`) and its output, then "Done";
//   - containing "think": a thought, then an answer, not streamed;
//   - containing "fail": a failed model call ("boom");
//   - containing "garbage": a line that isn't JSON and an event nobody
//     knows, then an answer;
//   - containing "wait": nothing, until abort (or a steer, answered);
//   - anything else: "You said: <text>", as two deltas.
package pigtest

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// Store is PiG's sessions folder.
type Store struct {
	Sessions string

	mu sync.Mutex
	n  int
}

// Pig is one fake pig on a connection.
type Pig struct {
	st  *Store
	w   io.Writer
	wmu sync.Mutex

	mu       sync.Mutex
	id, file string
	cwd      string
	parent   string
	entries  []map[string]any
	leaf     any // the last entry's id, or nil
	model    string
	level    string
	running  bool
	aborted  chan struct{}
	steered  chan string
	answers  map[string]chan map[string]any
}

// Serve runs a pig with args in cwd on r and w until r ends.
func (st *Store) Serve(r io.Reader, w io.Writer, cwd string, args []string) {
	p := &Pig{st: st, w: w, cwd: cwd, model: "m1", level: "low", answers: map[string]chan map[string]any{}, leaf: nil}
	p.id = st.newID()
	p.file = filepath.Join(st.Sessions, p.id+".jsonl")
	for i, a := range args {
		if a == "--session" && i+1 < len(args) {
			p.load(args[i+1])
		}
	}
	sc := bufio.NewScanner(r)
	sc.Buffer(nil, 1<<26)
	for sc.Scan() {
		var cmd map[string]any
		if json.Unmarshal(sc.Bytes(), &cmd) != nil {
			p.emit(map[string]any{"type": "response", "command": "parse", "success": false, "error": "Failed to parse command"})
			continue
		}
		if cmd["type"] == "extension_ui_response" {
			p.mu.Lock()
			ch := p.answers[cmd["id"].(string)]
			p.mu.Unlock()
			if ch != nil {
				ch <- cmd
			}
			continue
		}
		go p.command(cmd)
	}
}

func (st *Store) newID() string {
	st.mu.Lock()
	defer st.mu.Unlock()
	st.n++
	return fmt.Sprintf("01a171d2-0000-7000-8000-%012d", st.n)
}

// load opens a session file.
func (p *Pig) load(file string) {
	b, err := os.ReadFile(file)
	if err != nil {
		return
	}
	p.file = file
	for i, line := range strings.Split(strings.TrimSpace(string(b)), "\n") {
		var e map[string]any
		json.Unmarshal([]byte(line), &e)
		if i == 0 {
			p.id, p.cwd = e["id"].(string), e["cwd"].(string)
			continue
		}
		p.entries = append(p.entries, e)
		p.leaf = e["id"]
	}
}

func (p *Pig) emit(v any) {
	b, _ := json.Marshal(v)
	p.wmu.Lock()
	defer p.wmu.Unlock()
	p.w.Write(append(b, '\n'))
}

func (p *Pig) respond(cmd map[string]any, data any, err string) {
	r := map[string]any{"type": "response", "id": cmd["id"], "command": cmd["type"], "success": err == ""}
	if err != "" {
		r["error"] = err
	} else if data != nil {
		r["data"] = data
	}
	p.emit(r)
}

func (p *Pig) command(cmd map[string]any) {
	p.mu.Lock()
	defer p.mu.Unlock()
	switch cmd["type"] {
	case "get_state":
		p.respond(cmd, map[string]any{"sessionId": p.id, "sessionFile": p.file, "thinkingLevel": p.level,
			"model": map[string]any{"id": p.model, "provider": "fake"}, "isStreaming": p.running}, "")
	case "get_available_models":
		p.respond(cmd, map[string]any{"models": []map[string]any{{"id": "m1", "name": "Model one", "provider": "fake"},
			{"id": "m2", "name": "Model two", "provider": "fake"}}}, "")
	case "get_available_thinking_levels":
		p.respond(cmd, map[string]any{"levels": []string{"off", "low", "high"}}, "")
	case "set_model":
		p.model = cmd["modelId"].(string)
		p.respond(cmd, map[string]any{"id": p.model}, "")
	case "set_thinking_level":
		p.level = cmd["level"].(string)
		p.respond(cmd, nil, "")
	case "get_commands":
		p.respond(cmd, map[string]any{"commands": []map[string]any{{"name": "ask", "description": "Ask something", "source": "extension"}}}, "")
	case "get_session_stats":
		p.respond(cmd, map[string]any{"cost": 0.25, "contextUsage": map[string]any{"tokens": 100 * len(p.entries), "contextWindow": 1000}}, "")
	case "get_entries":
		p.respond(cmd, map[string]any{"entries": p.entries, "leafId": p.leaf}, "")
	case "prompt":
		text := cmd["message"].(string)
		if p.running {
			p.respond(cmd, nil, "Agent is already processing")
			return
		}
		if text == "/hang" { // a command that never ends
			return
		}
		if text == "/ask" {
			p.mu.Unlock()
			p.ask(cmd)
			p.mu.Lock()
			return
		}
		p.running, p.aborted, p.steered = true, make(chan struct{}), make(chan string, 4)
		p.respond(cmd, map[string]any{"disposition": "started"}, "")
		go p.run(text)
	case "steer":
		if !p.running {
			p.respond(cmd, nil, "nothing runs")
			return
		}
		p.steered <- cmd["message"].(string)
		p.respond(cmd, map[string]any{"disposition": "queued"}, "")
	case "abort":
		if p.running {
			close(p.aborted)
			p.running = false
		}
		p.respond(cmd, nil, "")
	case "fork", "clone":
		p.fork(cmd)
	default:
		p.respond(cmd, nil, fmt.Sprintf("Unknown command: %v", cmd["type"]))
	}
}

// ask asks a select dialog, then notifies the choice.
func (p *Pig) ask(cmd map[string]any) {
	ch := make(chan map[string]any, 1)
	p.mu.Lock()
	p.answers["ui1"] = ch
	p.mu.Unlock()
	p.emit(map[string]any{"type": "extension_ui_request", "id": "ui1", "method": "select", "title": "Pick a colour", "options": []string{"Red", "Blue"}})
	a := <-ch
	p.emit(map[string]any{"type": "extension_ui_request", "id": "ui2", "method": "notify", "message": fmt.Sprintf("Chose %v", a["value"])})
	p.respond(cmd, map[string]any{"disposition": "handled"}, "")
}

var clock atomic.Int64

// stamp is a message's time: milliseconds, unique.
func stamp() int64 {
	clock.CompareAndSwap(0, time.Now().UnixMilli())
	return clock.Add(1)
}

// append adds a message to the session's branch, and writes the file.
func (p *Pig) append(msg map[string]any) {
	id := fmt.Sprintf("e%d", len(p.entries)+1)
	b, _ := json.Marshal(map[string]any{"type": "message", "id": id, "parentId": p.leaf, "message": msg})
	var e map[string]any
	json.Unmarshal(b, &e) // as read from the file
	p.entries = append(p.entries, e)
	p.leaf = id
	p.save()
}

func (p *Pig) save() {
	h := map[string]any{"type": "session", "version": 3, "id": p.id, "cwd": p.cwd}
	if p.parent != "" {
		h["parentSession"] = p.parent
	}
	var b strings.Builder
	for _, v := range append([]map[string]any{h}, p.entries...) {
		line, _ := json.Marshal(v)
		b.Write(append(line, '\n'))
	}
	os.WriteFile(p.file, []byte(b.String()), 0o600)
}

func assistant(blocks ...map[string]any) map[string]any {
	return map[string]any{"role": "assistant", "content": blocks, "timestamp": stamp(), "stopReason": "stop",
		"usage": map[string]any{"input": 10, "output": 5, "totalTokens": 15}}
}

func textBlock(s string) map[string]any { return map[string]any{"type": "text", "text": s} }

// run answers a prompt, by script.
func (p *Pig) run(text string) {
	p.emit(map[string]any{"type": "agent_start"})
	user := map[string]any{"role": "user", "content": []map[string]any{textBlock(text)}, "timestamp": stamp()}
	p.emit(map[string]any{"type": "message_end", "message": user})
	p.mu.Lock()
	p.append(user)
	aborted, steered := p.aborted, p.steered
	p.mu.Unlock()
	say := func(m map[string]any) {
		p.emit(map[string]any{"type": "message_start", "message": map[string]any{"role": "assistant", "content": []any{}, "timestamp": m["timestamp"]}})
		blocks := m["content"].([]map[string]any)
		for i, b := range blocks {
			if t, ok := b["text"].(string); ok && b["type"] == "text" && blocks[0]["type"] != "thinking" {
				half := len(t) / 2
				for _, d := range []string{t[:half], t[half:]} {
					p.emit(map[string]any{"type": "message_update", "assistantMessageEvent": map[string]any{"type": "text_delta", "contentIndex": i, "delta": d}})
				}
			}
		}
		p.emit(map[string]any{"type": "message_end", "message": m})
		p.mu.Lock()
		p.append(m)
		p.mu.Unlock()
	}
	settle := func(abort bool) {
		p.mu.Lock()
		p.running = false
		p.mu.Unlock()
		p.emit(map[string]any{"type": "agent_end"})
		p.emit(map[string]any{"type": "agent_settled", "aborted": abort})
	}
	switch {
	case strings.Contains(text, "tool"):
		call := map[string]any{"type": "toolCall", "id": "call_1", "name": "bash", "arguments": map[string]any{"command": "ls"}}
		say(assistant(call))
		p.emit(map[string]any{"type": "tool_execution_start", "toolCallId": "call_1", "toolName": "bash", "args": call["arguments"]})
		out := map[string]any{"content": []map[string]any{textBlock("a.txt\n")}}
		p.emit(map[string]any{"type": "tool_execution_update", "toolCallId": "call_1", "toolName": "bash", "partialResult": out})
		p.emit(map[string]any{"type": "tool_execution_end", "toolCallId": "call_1", "toolName": "bash", "result": out, "isError": false})
		res := map[string]any{"role": "toolResult", "toolCallId": "call_1", "toolName": "bash", "content": out["content"], "isError": false, "timestamp": stamp()}
		p.emit(map[string]any{"type": "message_end", "message": res})
		p.mu.Lock()
		p.append(res)
		p.mu.Unlock()
		say(assistant(textBlock("Done")))
	case strings.Contains(text, "think"):
		m := assistant(map[string]any{"type": "thinking", "thinking": "Hmm."}, textBlock("Thought about it"))
		say(m) // it comes whole, with the message's end
	case strings.Contains(text, "fail"):
		m := assistant()
		m["stopReason"], m["errorMessage"] = "error", "boom"
		say(m)
	case strings.Contains(text, "garbage"):
		p.wmu.Lock()
		p.w.Write([]byte("not json\n"))
		p.wmu.Unlock()
		p.emit(map[string]any{"type": "mystery"})
		say(assistant(textBlock("Still here")))
	case strings.Contains(text, "wait"):
		select {
		case <-aborted:
			m := assistant()
			m["stopReason"], m["errorMessage"] = "aborted", "This operation was aborted"
			say(m)
			settle(true)
			return
		case s := <-steered:
			say(assistant(textBlock("Steered: " + s)))
		}
	default:
		say(assistant(textBlock("You said: " + text)))
	}
	settle(false)
}

// fork switches to a new session: the branch up to before the user's
// message entryId (fork), or all of it (clone).
func (p *Pig) fork(cmd map[string]any) {
	var keep []map[string]any
	text := ""
	for _, e := range p.entries {
		if e["id"] == cmd["entryId"] {
			m := e["message"].(map[string]any)
			text = m["content"].([]any)[0].(map[string]any)["text"].(string)
			break
		}
		keep = append(keep, e)
	}
	p.parent, p.entries, p.leaf = p.file, keep, nil
	if len(keep) > 0 {
		p.leaf = keep[len(keep)-1]["id"]
	}
	p.id = p.st.newID()
	p.file = filepath.Join(p.st.Sessions, p.id+".jsonl")
	p.save()
	data := map[string]any{"cancelled": false}
	if cmd["type"] == "fork" {
		data["text"] = text
	}
	p.respond(cmd, data, "")
}

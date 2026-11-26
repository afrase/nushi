// Package pitest is a fake `pig --mode rpc` for tests, speaking PiG
// 0.8.0's RPC mode (Pi 1.6.0's) as the real one was seen to
// (docs/facts/pig.md): commands in, responses (by id) and events out.
// Store.Shape PiG053 gives what 0.5.3 did differently, so the bridge's
// tests run on both. Sessions are files in a folder, as Pi keeps
// them (a header line, then entries that make a tree), so a pi started
// later can open or fork them. Prompts are answered by script, keyed on
// their text:
//
//   - "/ask": an extension's select dialog (Red, Blue), then the choice
//     as a notification; the prompt is "handled", no run;
//   - "/hang": a command that never ends;
//   - containing "tool": a bash call (`ls`) and its output, then "Done";
//     the call's model call writes 96 cached tokens, the next reads them;
//   - containing "todo": a todo tool's call with its list in its result's
//     details, then a plan-mode entry with its own list;
//   - containing "think": a thought, then an answer, not streamed;
//   - containing "fail": a failed model call ("boom");
//   - containing "garbage": a line that isn't JSON and an event nobody
//     knows, then an answer;
//   - containing "listen": nothing, until a steer, which it takes as the
//     user's, then nothing again (said on Waiting again), until abort;
//   - containing "wait": nothing, until abort (or a steer, taken as the
//     user's, then answered);
//   - containing "hold": nothing, until abort; a steer meanwhile is
//     queued, and an abort leaves it for the next run (0.8.0's), or
//     brings it in as the aborted run's user message (0.5.3's);
//   - the command steer: queued, a run going or not (0.8.0's; 0.5.3's
//     with no run wasn't seen, and is taken to be the same), with a
//     queue_update of the whole queue; a prompt's run brings what is
//     queued in after its own message; clear_queue takes back the whole
//     queue;
//   - containing "long": an answer cut at the model's limit (stopReason
//     length), then the context_edit entry PiG appends for it;
//   - containing "deaf": nothing, and pi then answers no abort, until its
//     input ends (as PiG 0.5.3 after /sprite, docs/facts/pig.md);
//   - the command compact: a compaction entry ("Summary: <instructions>"),
//     unless the session has nothing to compact; "slow" waits for abort;
//   - anything else: "You said: <text>", as two deltas.
//
// A session's first prompt brings PiG 0.8.0's system message (a message
// of role system, in the events and the session) before the user's; a
// bash call's first update has no output yet. The model's messages
// stream as 0.8.0's do (speak): message_start "pending", the updates of
// each text and tool call, message_end whole; a tool call's turn ends
// after its result's message (turn_end), and the next model call has a
// turn_start of its own. Three exchanges were compared with the real
// 0.8.0's (2026-11-26, against an OpenAI-style fake provider), each
// event's type, its fields' names, an update's kind and a message's
// role and stop reason: a session's first prompt, a bash call and its
// answer (TestAToolTurnAsPiGSentIt keeps that one), and a clone with an
// extension greeting on session_start. They differ only where the fake
// says a text as two deltas and in the values (times, ids, the usage's
// numbers, the provider's names); the usage has the real one's fields. Not compared: thoughts (they come whole here), the
// to-do list and plan-mode extensions' events, a cut answer's. With Greets, an extension
// says "Started (<reason>)" on session_start: as pi starts, and as a fork
// or clone replaces the session, once before the answer (0.8.0), or a
// second time after it (0.5.3).
//
// One that waits ("/hang", "wait", a slow compact) says so on the Store's
// Waiting once it does, so a test stops or steers it when it runs, not
// after a sleep that may lose the race. As Pi's, commands are taken in
// the order they are read, abort answers once the run settled (after its
// agent_settled), and a prompt is refused until then.
package pitest

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"
)

// Shape is which PiG the fake is.
type Shape int

const (
	PiG080 Shape = iota // as PiG 0.8.0 was seen to, the default
	PiG053              // what PiG 0.5.3 did differently
)

// Store is Pi's sessions folder.
type Store struct {
	Sessions string
	// Shape is which PiG the fake is.
	Shape Shape
	// Greets runs an extension that notifies on session_start.
	Greets bool
	// Waiting, when set, gets the text of each prompt or command that
	// waits for an abort or a steer, once it waits. The fake blocks on
	// it: the test reads each, or gives the channel room.
	Waiting chan string
	// Starts, when set, gets a channel for each prompt that starts a run,
	// before its answer and the run's agent_start, which wait until the
	// test closes it: a run pi took that the bridge hasn't heard of yet.
	Starts chan chan struct{}
	// Settles, when set, gets a channel for each run that has ended,
	// before its agent_settled goes out, which waits until the test
	// closes it: pi is idle (a steer is queued for the next prompt, an
	// abort answered) and the bridge hasn't heard, as while agent_settled
	// is on its way.
	Settles chan chan struct{}
	// PromptLag, when set, is how long a prompt takes to be taken: pi
	// handles each command as it reads it, and its prompt sets up before
	// a run starts, so an abort read right after a prompt can be handled
	// first, find no run, and leave the run to start after it.
	PromptLag time.Duration
	// Read, when set, gets each prompt's text as pi reads it, before its
	// PromptLag.
	Read chan string
	// Steered, when set, gets each steer's text once pi has queued it.
	Steered chan string

	mu sync.Mutex
	n  int
}

// Program is one fake pi on a connection.
type Program struct {
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
	settled  chan struct{} // closed once the run settled
	// queued is pi's steering queue, oldest first: a run takes from it
	// (kicked says it grew), and a prompt's run brings in what it holds
	// after the prompt's own message (what an abort or an idle steer left).
	queued   []string
	kicked   chan struct{}
	prompted bool // the system message is in
	answers  map[string]chan map[string]any

	compacting chan struct{} // closed by abort
	deaf       bool          // the run is a "deaf" one: an abort gets no answer
	gone       chan struct{} // closed once pi's input has ended
}

// Serve runs a pi with args in cwd on r and w until r ends.
func (st *Store) Serve(r io.Reader, w io.Writer, cwd string, args []string) {
	p := &Program{st: st, w: w, cwd: cwd, model: "m1", level: "low", answers: map[string]chan map[string]any{}, leaf: nil,
		kicked: make(chan struct{}, 1), gone: make(chan struct{})}
	defer close(p.gone)
	p.id = st.newID()
	p.file = filepath.Join(st.Sessions, p.id+".jsonl")
	for i, a := range args {
		if a == "--session" && i+1 < len(args) {
			p.load(args[i+1])
		}
	}
	p.greet("startup")
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
		if cmd["type"] == "prompt" && (p.st.Read != nil || p.st.PromptLag > 0) {
			go func() { // it sets up first: what pi reads next may be taken before it
				if p.st.Read != nil {
					p.st.Read <- cmd["message"].(string)
				}
				time.Sleep(p.st.PromptLag)
				p.mu.Lock()
				p.command(cmd)
			}()
			continue
		}
		p.mu.Lock() // pi takes each command in the order it reads it
		go p.command(cmd)
	}
}

// greet is the Greets extension's session_start.
func (p *Program) greet(reason string) {
	if p.st.Greets {
		p.emit(map[string]any{"type": "extension_ui_request", "id": fmt.Sprintf("greet%d", greets.Add(1)), "method": "notify", "message": "Started (" + reason + ")"})
	}
}

// waiting says a turn running text now waits.
func (st *Store) waiting(text string) {
	if st.Waiting != nil {
		st.Waiting <- text
	}
}

func (st *Store) newID() string {
	st.mu.Lock()
	defer st.mu.Unlock()
	st.n++
	return fmt.Sprintf("01a171d2-0000-7000-8000-%012d", st.n)
}

func (p *Program) emit(v any) {
	b, _ := json.Marshal(v)
	p.wmu.Lock()
	defer p.wmu.Unlock()
	_, _ = p.w.Write(append(b, '\n'))
}

func (p *Program) respond(cmd map[string]any, data any, err string) {
	r := map[string]any{"type": "response", "id": cmd["id"], "command": cmd["type"], "success": err == ""}
	if err != "" {
		r["error"] = err
	} else if data != nil {
		r["data"] = data
	}
	p.emit(r)
}

// command handles one command, with p.mu held: Serve takes it in the
// order pi reads its commands, as Pi starts each as it reads it (a
// prompt with a PromptLag sets up first). One that waits lets it go.
func (p *Program) command(cmd map[string]any) {
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
		var tokens any = 100 * len(p.entries)
		if n := len(p.entries); n > 0 && p.entries[n-1]["type"] == "compaction" {
			tokens = nil // unknown until the model answers again
		}
		p.respond(cmd, map[string]any{"cost": 0.25, "contextUsage": map[string]any{"tokens": tokens, "contextWindow": 1000},
			"userMessages": 2, "assistantMessages": 3, "toolCalls": 1, "tokens": map[string]any{"input": 1500, "output": 250, "cacheRead": 64, "cacheWrite": 0}}, "")
	case "get_entries":
		p.respond(cmd, map[string]any{"entries": p.entries, "leafId": p.leaf}, "")
	case "prompt":
		text := cmd["message"].(string)
		if p.running {
			p.respond(cmd, nil, "Agent is already processing")
			return
		}
		if text == "/hang" { // a command that never ends
			p.st.waiting(text)
			return
		}
		if text == "/ask" {
			p.mu.Unlock()
			p.ask(cmd)
			p.mu.Lock()
			return
		}
		p.running, p.aborted, p.settled = true, make(chan struct{}), make(chan struct{})
		p.deaf = strings.Contains(text, "deaf")
		if p.st.Starts != nil {
			held := make(chan struct{})
			p.mu.Unlock()
			p.st.Starts <- held
			<-held
			p.mu.Lock()
		}
		p.respond(cmd, map[string]any{"disposition": "started"}, "")
		go p.run(text)
	case "steer": // queued, a run going or not: with none, the next prompt's run brings it in
		text := cmd["message"].(string)
		p.queued = append(p.queued, text)
		p.emit(map[string]any{"type": "queue_update", "steering": slices.Clone(p.queued), "followUp": []string{}})
		p.respond(cmd, map[string]any{"disposition": "queued"}, "")
		select {
		case p.kicked <- struct{}{}:
		default:
		}
		if p.st.Steered != nil {
			p.st.Steered <- text
		}
	case "clear_queue":
		p.clearQueue(cmd)
	case "abort":
		if p.running && p.deaf { // never answered
			return
		}
		if p.compacting != nil {
			close(p.compacting)
			p.compacting = nil
		}
		if p.running {
			select {
			case <-p.aborted:
			default:
				close(p.aborted)
			}
			settled := p.settled
			p.mu.Unlock()
			<-settled
			p.mu.Lock()
		}
		p.respond(cmd, nil, "")
	case "fork", "clone":
		p.fork(cmd)
	case "compact":
		p.mu.Unlock()
		p.compact(cmd)
		p.mu.Lock()
	case "set_session_name":
		name := cmd["name"].(string)
		p.add(map[string]any{"type": "session_info", "name": name})
		p.emit(map[string]any{"type": "session_info_changed", "name": name})
		p.respond(cmd, nil, "")
	default:
		p.respond(cmd, nil, fmt.Sprintf("Unknown command: %v", cmd["type"]))
	}
}

// clearQueue takes back what is queued, which never reaches the model.
func (p *Program) clearQueue(cmd map[string]any) {
	steers := p.queued
	p.queued = nil
	p.emit(map[string]any{"type": "queue_update", "steering": []string{}, "followUp": []string{}})
	p.respond(cmd, map[string]any{"steering": append([]string{}, steers...), "followUp": []string{}}, "")
}

// ask asks a select dialog, then notifies the choice.
func (p *Program) ask(cmd map[string]any) {
	ch := make(chan map[string]any, 1)
	p.mu.Lock()
	p.answers["ui1"] = ch
	p.mu.Unlock()
	p.emit(map[string]any{"type": "extension_ui_request", "id": "ui1", "method": "select", "title": "Pick a colour", "options": []string{"Red", "Blue"}})
	a := <-ch
	p.emit(map[string]any{"type": "extension_ui_request", "id": "ui2", "method": "notify", "message": fmt.Sprintf("Chose %v", a["value"])})
	p.respond(cmd, map[string]any{"disposition": "handled"}, "")
}

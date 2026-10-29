package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"maps"
	"net/http"
	"os"
	"slices"
	"strings"
	"sync"
)

// fakeClaude is a claude small enough to read, for recording without
// the real one: it speaks claude's stream-JSON protocol on stdin and
// stdout, in claude 2.1.312's shapes, and gets each reply from the
// Messages API at $ANTHROPIC_BASE_URL, as claude does. Each tool_use is
// asked about (can_use_tool) and "run": its result is "ran <input>".
// Every control request is answered at once with success.
func fakeClaude(args []string) int {
	if slices.Contains(args, "--version") {
		fmt.Println("2.1.312 (Fake Claude)") //nolint:forbidigo // claude's own output
		return 0
	}
	if slices.Equal(args, []string{"auth", "status", "--json"}) { // the Node adapter asks
		fmt.Println(`{"loggedIn":true,"authMethod":"api_key"}`) //nolint:forbidigo // as above
		return 0
	}
	f := &fake{sid: "fake-session", waiting: map[string]chan map[string]any{}, partial: slices.Contains(args, "--include-partial-messages"),
		replay: slices.Contains(args, "--replay-user-messages")}
	for _, a := range args {
		for _, k := range []string{"--session-id=", "--resume="} {
			if v, ok := strings.CutPrefix(a, k); ok {
				f.sid = v
			}
		}
	}
	users := make(chan map[string]any, 16)
	go func() {
		defer close(users)
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(nil, 64<<20)
		for sc.Scan() {
			var m map[string]any
			if json.Unmarshal(sc.Bytes(), &m) != nil {
				continue
			}
			f.take(m, users)
		}
	}()
	for u := range users {
		if err := f.turn(u); err != nil {
			fmt.Fprintln(os.Stderr, "fake claude:", err)
			return 1
		}
	}
	return 0
}

type fake struct {
	sid             string
	partial, replay bool
	history         []any
	inited          bool

	mu      sync.Mutex
	n       int
	waiting map[string]chan map[string]any // our requests' answers
}

// take files a stdin frame: control requests are answered here, answers
// go to who waits, user messages to the turns.
func (f *fake) take(m map[string]any, users chan<- map[string]any) {
	switch m["type"] {
	case "control_request":
		req, _ := m["request"].(map[string]any)
		resp := map[string]any{}
		if req["subtype"] == "initialize" {
			resp = map[string]any{"commands": []any{}, "agents": []any{}, "models": []any{}, "account": map[string]any{}}
		}
		f.send(map[string]any{"type": "control_response", "response": map[string]any{"subtype": "success", "request_id": m["request_id"], "response": resp}})
	case "control_response":
		resp, _ := m["response"].(map[string]any)
		id, _ := resp["request_id"].(string)
		f.mu.Lock()
		ch := f.waiting[id]
		delete(f.waiting, id)
		f.mu.Unlock()
		if ch != nil {
			ch <- resp
		}
	case "user":
		users <- m
	}
}

func (f *fake) send(m map[string]any) {
	b, _ := json.Marshal(m)
	f.mu.Lock()
	defer f.mu.Unlock()
	_, _ = os.Stdout.Write(append(b, '\n'))
}

func (f *fake) uuid() string {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.n++
	return fmt.Sprintf("00000000-0000-4000-8000-%012d", f.n)
}

// turn runs the turn a user message starts, to its result.
func (f *fake) turn(u map[string]any) error {
	f.send(map[string]any{"type": "system", "subtype": "session_state_changed", "state": "running", "session_id": f.sid, "uuid": f.uuid()})
	if f.replay {
		echo := with(u, map[string]any{"session_id": f.sid, "isReplay": true})
		f.send(echo)
	}
	if !f.inited {
		f.inited = true
		cwd, _ := os.Getwd()
		f.send(map[string]any{"type": "system", "subtype": "init", "session_id": f.sid, "cwd": cwd, "model": "claude-fake", "permissionMode": "default",
			"tools": []any{"Bash"}, "mcp_servers": []any{}, "slash_commands": []any{}, "uuid": f.uuid()})
	}
	f.history = append(f.history, u["message"])
	var text strings.Builder
	var usage any
	var stop string
	for {
		blocks, s, use, err := f.ask()
		if err != nil {
			return err
		}
		stop, usage = s, use
		f.history = append(f.history, map[string]any{"role": "assistant", "content": blocks})
		var results []any
		for _, b := range blocks {
			switch b["type"] {
			case "text":
				text.WriteString(b["text"].(string))
			case "tool_use":
				results = append(results, f.use(b))
			}
		}
		if stop != "tool_use" {
			break
		}
		msg := map[string]any{"role": "user", "content": results}
		f.history = append(f.history, msg)
		f.send(map[string]any{"type": "user", "message": msg, "parent_tool_use_id": nil, "session_id": f.sid, "uuid": f.uuid()})
	}
	// The Node adapter reads modelUsage and permission_denials too.
	byModel := map[string]any{"claude-fake": map[string]any{"inputTokens": 1, "outputTokens": 1, "cacheReadInputTokens": 0,
		"cacheCreationInputTokens": 0, "costUSD": 0.01, "contextWindow": 200000}}
	f.send(map[string]any{"type": "result", "subtype": "success", "is_error": false, "num_turns": 1, "result": text.String(), "stop_reason": stop,
		"session_id": f.sid, "total_cost_usd": 0.01, "usage": usage, "modelUsage": byModel, "permission_denials": []any{},
		"origin": map[string]any{"kind": "human"}, "user_message_uuids": []any{u["uuid"]}, "uuid": f.uuid()})
	f.send(map[string]any{"type": "system", "subtype": "session_state_changed", "state": "idle", "session_id": f.sid, "uuid": f.uuid()})
	return nil
}

// use asks the client about a tool_use and returns its tool_result.
func (f *fake) use(b map[string]any) map[string]any {
	f.mu.Lock()
	f.n++
	id := fmt.Sprintf("fake_%d", f.n)
	ch := make(chan map[string]any, 1)
	f.waiting[id] = ch
	f.mu.Unlock()
	f.send(map[string]any{"type": "control_request", "request_id": id, "request": map[string]any{"subtype": "can_use_tool",
		"tool_name": b["name"], "input": b["input"], "tool_use_id": b["id"]}})
	resp := <-ch
	answer, _ := resp["response"].(map[string]any)
	in, _ := json.Marshal(b["input"])
	if answer["behavior"] != "allow" {
		return map[string]any{"type": "tool_result", "tool_use_id": b["id"], "content": "denied", "is_error": true}
	}
	return map[string]any{"type": "tool_result", "tool_use_id": b["id"], "content": "ran " + string(in)}
}

// ask gets a reply from the API, writing its stream events (when asked
// for) and an assistant message a block, as claude does.
func (f *fake) ask() (blocks []map[string]any, stop string, usage any, err error) {
	body, _ := json.Marshal(map[string]any{"model": "claude-fake", "max_tokens": 1024, "stream": true, "messages": f.history,
		"tools": []any{map[string]any{"name": "Bash", "input_schema": map[string]any{"type": "object"}}}})
	req, _ := http.NewRequestWithContext(context.Background(), http.MethodPost, os.Getenv("ANTHROPIC_BASE_URL")+"/v1/messages?beta=true", bytes.NewReader(body))
	req.Header.Set("X-Api-Key", os.Getenv("ANTHROPIC_API_KEY"))
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, "", nil, err
	}
	defer resp.Body.Close() //nolint:errcheck // read to its end
	var id string
	var started any // message_start's usage, which each assistant message carries
	var cur map[string]any
	var input strings.Builder
	sc := bufio.NewScanner(resp.Body)
	for sc.Scan() {
		data, ok := strings.CutPrefix(sc.Text(), "data: ")
		if !ok {
			continue
		}
		var ev map[string]any
		if err := json.Unmarshal([]byte(data), &ev); err != nil {
			return nil, "", nil, err
		}
		if f.partial && ev["type"] != "ping" {
			f.send(map[string]any{"type": "stream_event", "event": ev, "session_id": f.sid, "parent_tool_use_id": nil, "uuid": f.uuid()})
		}
		switch ev["type"] {
		case "message_start":
			start := ev["message"].(map[string]any)
			id, _ = start["id"].(string)
			started = start["usage"]
		case "content_block_start":
			cur = ev["content_block"].(map[string]any)
			input.Reset()
		case "content_block_delta":
			d := ev["delta"].(map[string]any)
			switch d["type"] {
			case "text_delta":
				cur["text"] = cur["text"].(string) + d["text"].(string)
			case "thinking_delta":
				cur["thinking"] = cur["thinking"].(string) + d["thinking"].(string)
			case "signature_delta":
				cur["signature"] = d["signature"]
			case "input_json_delta":
				input.WriteString(d["partial_json"].(string))
			}
		case "content_block_stop":
			if cur["type"] == "tool_use" {
				cur["input"] = json.RawMessage(input.String())
			}
			blocks = append(blocks, cur)
			f.send(map[string]any{"type": "assistant", "message": map[string]any{"id": id, "type": "message", "role": "assistant", "model": "claude-fake",
				"content": []any{cur}, "stop_reason": nil, "usage": started}, "parent_tool_use_id": nil, "session_id": f.sid, "uuid": f.uuid()})
		case "message_delta":
			stop, _ = ev["delta"].(map[string]any)["stop_reason"].(string)
			usage = ev["usage"]
		}
	}
	return blocks, stop, usage, sc.Err()
}

// with is a copy of m with add's keys.
func with(m, add map[string]any) map[string]any {
	out := maps.Clone(m)
	maps.Copy(out, add)
	return out
}

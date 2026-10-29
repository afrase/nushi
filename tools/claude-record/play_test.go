package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"io"
	"strings"
	"testing"
	"time"
)

// fakeAgent answers the client on r and w as a script's agent would:
// prompts ask a permission first, and say a chunk once it is answered.
// It returns the messages it got, once r ends.
func fakeAgent(r io.Reader, w io.Writer) <-chan []map[string]any {
	done := make(chan []map[string]any, 1)
	go func() {
		var got []map[string]any
		send := func(m string) { _, _ = io.WriteString(w, m+"\n") }
		var prompt json.RawMessage // the prompt waiting for its permission
		sc := bufio.NewScanner(r)
		for sc.Scan() {
			var m map[string]any
			_ = json.Unmarshal(sc.Bytes(), &m)
			got = append(got, m)
			id, _ := json.Marshal(m["id"])
			switch m["method"] {
			case "initialize", "_session/steering":
				send(`{"jsonrpc":"2.0","id":` + string(id) + `,"result":{}}`)
			case "session/new":
				send(`{"jsonrpc":"2.0","id":` + string(id) + `,"result":{"sessionId":"sid-1"}}`)
			case "session/fork":
				send(`{"jsonrpc":"2.0","id":` + string(id) + `,"result":{"sessionId":"sid-2"}}`)
			case "custom/fail":
				send(`{"jsonrpc":"2.0","id":` + string(id) + `,"error":{"code":-32002,"message":"gone"}}`)
			case "session/prompt":
				prompt = id
				send(`{"jsonrpc":"2.0","id":"perm","method":"session/request_permission","params":{"options":[{"optionId":"yes","kind":"allow_once"},{"optionId":"no","kind":"reject_once"}]}}`)
			case nil:
				if m["id"] == "perm" {
					send(`{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"sid-1","update":{"sessionUpdate":"agent_message_chunk"}}}`)
					send(`{"jsonrpc":"2.0","id":` + string(prompt) + `,"result":{"stopReason":"end_turn"}}`)
				}
			}
		}
		done <- got
	}()
	return done
}

func TestPlay(t *testing.T) {
	toAgentR, toAgentW := io.Pipe()
	fromAgentR, fromAgentW := io.Pipe()
	agent := fakeAgent(toAgentR, fromAgentW)
	var rec bytes.Buffer
	c := newConn(toAgentW, fromAgentR, &rec) // conn writes it a line at a time, under its lock
	steps := `[
		{"initialize": {}},
		{"new": "s1", "meta": {"claudeCode": {"options": {"model": "opus"}}}},
		{"prompt": "hi", "session": "s1", "async": "p"},
		{"waitFor": {"method": "session/request_permission"}},
		{"steer": "and this", "session": "s1"},
		{"answer": "session/request_permission", "option": "reject_once"},
		{"waitFor": {"params": {"update": {"sessionUpdate": "agent_message_chunk"}}}},
		{"cancel": "s1"},
		{"fork": "s1", "as": "f"},
		{"request": "custom/echo-ids", "params": {"a": "$s1", "b": ["$f", "$cwd", "$nobody"]}, "async": "e"},
		{"request": "custom/fail", "expectError": true},
		{"notify": "custom/note", "params": {"of": "$f"}}
	]`
	var s []step
	if err := json.Unmarshal([]byte(steps), &s); err != nil {
		t.Fatal(err)
	}
	p := &player{c: c, cwd: "/work", timeout: 5 * time.Second, ids: map[string]string{}, async: map[string]<-chan msg{}}
	errs := make(chan error, 1)
	go func() { errs <- p.play(t.Context(), s[:9]) }()
	if err := <-errs; err != nil {
		t.Fatal(err)
	}
	// The rest, with an echo the fake never answers: play's await of it
	// times out.
	p.timeout = 50 * time.Millisecond
	if err := p.play(t.Context(), s[9:]); err == nil || !strings.Contains(err.Error(), "e: no answer") {
		t.Errorf("play: %v", err)
	}
	_ = toAgentW.Close()
	got := <-agent
	_ = fromAgentW.Close()
	<-c.done
	byMethod := map[string]map[string]any{}
	for _, m := range got {
		if method, _ := m["method"].(string); method != "" {
			byMethod[method] = m
		} else {
			byMethod["answer "+m["id"].(string)] = m
		}
	}
	check := func(what string, ok bool) {
		t.Helper()
		if !ok {
			b, _ := json.MarshalIndent(byMethod, "", " ")
			t.Errorf("%s:\n%s", what, b)
		}
	}
	params := func(method string) map[string]any { p, _ := byMethod[method]["params"].(map[string]any); return p }
	options := func(method string) map[string]any {
		return params(method)["_meta"].(map[string]any)["claudeCode"].(map[string]any)["options"].(map[string]any)
	}
	check("new has Nushi's _meta and the step's", options("session/new")["model"] == "opus" && options("session/new")["perTaskStopAffordance"] != nil)
	check("new's cwd", params("session/new")["cwd"] == "/work")
	check("a fork has Nushi's _meta only", options("session/fork")["model"] == nil && params("session/fork")["sessionId"] == "sid-1")
	check("the steer", params("_session/steering")["sessionId"] == "sid-1" && strings.Contains(byMethodJSON(byMethod["_session/steering"]), `"idleBehavior":"promptRequired"`))
	check("the permission's answer", strings.Contains(byMethodJSON(byMethod["answer perm"]), `"optionId":"no"`))
	check("the cancel", params("session/cancel")["sessionId"] == "sid-1")
	check("names and $cwd", byMethodJSON(params("custom/echo-ids")) == `{"a":"sid-1","b":["sid-2","/work","$nobody"]}`)
	check("a notification", params("custom/note")["of"] == "sid-2")
	if lines := strings.Count(rec.String(), "\n"); lines != len(got)+8 { // and the agent's 8: 5 answers, an error, its request and an update
		t.Errorf("%d lines recorded for %d sent:\n%s", lines, len(got), rec.String())
	}
}

func byMethodJSON(v any) string {
	b, _ := json.Marshal(v)
	return string(b)
}

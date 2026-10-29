// Partly ported from the Claude Agent SDK for Python's tests (commit
// 27858cbb, tests/test_sessions.py), MIT License, Copyright (c) 2025
// Anthropic, PBC: see ../NOTICE.

package sessions

import (
	"encoding/json"
	"fmt"
	"maps"
	"strings"
	"testing"
)

type record = map[string]any

// rec is a transcript record of type typ, linked to parent ("" for none).
func rec(typ, uuid, parent string, extra ...any) record {
	r := record{"type": typ, "uuid": uuid, "parentUuid": nil, "sessionId": "s"}
	if parent != "" {
		r["parentUuid"] = parent
	}
	for i := 0; i+1 < len(extra); i += 2 {
		r[extra[i].(string)] = extra[i+1]
	}
	return r
}

// text is a record with a message of plain text.
func text(typ, uuid, parent, content string) record {
	return rec(typ, uuid, parent, "message", record{"role": typ, "content": content})
}

// parallelTurn is one response making n tool calls at once, as the CLI
// writes it: a record per call, all with the response's message id, each
// the parent of the next; and a result per call whose parent is its own
// call's record, written in resultOrder.
func parallelTurn(parent string, n int, resultOrder ...int) (calls, results []record) {
	for i := range n {
		p := parent
		if i > 0 {
			p = calls[i-1]["uuid"].(string)
		}
		calls = append(calls, rec("assistant", fmt.Sprintf("call-%d", i), p,
			"message", record{"id": "msg_parallel", "role": "assistant", "content": []any{
				record{"type": "tool_use", "id": fmt.Sprintf("toolu_%d", i), "name": "Read", "input": record{}},
			}},
			"timestamp", fmt.Sprintf("2026-01-01T00:00:01.%03dZ", i)))
	}
	for at, i := range resultOrder {
		results = append(results, rec("user", fmt.Sprintf("result-%d", i), fmt.Sprintf("call-%d", i),
			"message", record{"role": "user", "content": []any{
				record{"type": "tool_result", "tool_use_id": fmt.Sprintf("toolu_%d", i), "content": "ok"},
			}},
			"sourceToolAssistantUUID", fmt.Sprintf("call-%d", i),
			"timestamp", fmt.Sprintf("2026-01-01T00:00:02.%03dZ", at)))
	}
	return calls, results
}

// jsonl writes records as a transcript.
func jsonl(t *testing.T, records ...record) []byte {
	t.Helper()
	var b strings.Builder
	for _, r := range records {
		line, err := json.Marshal(r)
		if err != nil {
			t.Fatal(err)
		}
		b.Write(line)
		b.WriteByte('\n')
	}
	return []byte(b.String())
}

func uuids(entries []*entry) string {
	var out []string
	for _, e := range entries {
		out = append(out, e.uuid)
	}
	return strings.Join(out, " ")
}

func cat(parts ...[]record) []record {
	var out []record
	for _, p := range parts {
		out = append(out, p...)
	}
	return out
}

func TestChain(t *testing.T) {
	prompt := rec("user", "prompt", "")
	answer := func(parent string) record { return rec("assistant", "answer", parent) }
	turn := func(order ...int) ([]record, []record) { return parallelTurn("prompt", len(order), order...) }

	c1, r1 := turn(1, 2, 0)
	c2, r2 := turn(1, 0, 2)
	c3, r3 := turn(1, 2, 0)
	c4, r4 := parallelTurn("prompt", 2, 0, 1)
	old := rec("assistant", "old-call", "prompt", "message", record{"id": "msg_abandoned", "content": []any{record{"type": "tool_use", "id": "toolu_old"}}})
	oldResult := rec("user", "old-result", "old-call", "message", record{"content": []any{record{"type": "tool_result", "tool_use_id": "toolu_old"}}})
	c5, r5 := parallelTurn("prompt", 2, 0, 1)
	r5[0]["parentUuid"] = "missing"
	delete(r5[0], "sourceToolAssistantUUID")
	c6, r6 := parallelTurn("prompt", 2, 0, 1)
	dup := maps.Clone(r6[1])
	dup["uuid"], dup["parentUuid"] = "result-1-copy", "elsewhere"
	delete(dup, "sourceToolAssistantUUID")
	c7, r7 := parallelTurn("prompt", 2, 0, 1)
	r7[0]["parentUuid"], r7[0]["isSidechain"], r7[0]["agentId"] = "sidechain-call", true, "agent-1"
	delete(r7[0], "sourceToolAssistantUUID")
	c8, r8 := parallelTurn("prompt", 2, 0, 1)
	r8[0]["timestamp"] = 12345

	for _, c := range []struct {
		name    string
		records []record
		want    string
	}{
		{"empty", nil, ""},
		{"one", []record{prompt}, "prompt"},
		{"linear", []record{rec("user", "a", ""), rec("assistant", "b", "a"), rec("user", "c", "b")}, "a b c"},
		{"only progress", []record{rec("progress", "a", ""), rec("progress", "b", "a")}, ""},
		{"other types left out", []record{rec("user", "a", ""), rec("summary", "x", "a"), rec("assistant", "b", "a")}, "a b"},
		{"progress at the end walked back", []record{rec("user", "a", ""), rec("assistant", "b", "a"), rec("progress", "p", "b")}, "a b"},
		{"the main chain over a subagent's", []record{rec("user", "a", ""), rec("assistant", "b", "a"), rec("assistant", "side", "a", "isSidechain", true)}, "a b"},
		{"the leaf written last", []record{rec("user", "a", ""), rec("assistant", "b1", "a"), rec("assistant", "b2", "a")}, "a b2"},
		{"a cycle with no end", []record{rec("user", "a", "b"), rec("assistant", "b", "a")}, ""},
		{"a cycle ends", []record{rec("user", "a", "c"), rec("assistant", "b", "a"), rec("user", "c", "b"), rec("assistant", "d", "c")}, "a b c d"},
		{"no uuid", []record{rec("user", "a", ""), {"type": "assistant", "parentUuid": "a"}}, "a"},
		{"calls the walk dropped", cat([]record{prompt}, c1, r1, []record{answer("result-0")}), "prompt call-0 call-1 call-2 result-1 result-2 result-0 answer"},
		{"results in the order they finished", cat([]record{prompt}, c2, r2, []record{answer("result-2")}), "prompt call-0 call-1 call-2 result-1 result-0 result-2 answer"},
		{"calls in time order", cat([]record{prompt, c3[0], c3[2], c3[1]}, r3, []record{answer("result-0")}), "prompt call-0 call-1 call-2 result-1 result-2 result-0 answer"},
		{"an abandoned try left out", cat([]record{prompt, old, oldResult}, c4, r4), "prompt call-0 call-1 result-0 result-1"},
		{"a result found by its call", cat([]record{prompt}, c5, r5, []record{answer("result-1")}), "prompt call-0 call-1 result-0 result-1 answer"},
		{"an answered call's second result left out", cat([]record{prompt}, c6, r6, []record{dup, answer("result-1")}), "prompt call-0 call-1 result-0 result-1 answer"},
		{"another agent's result left out", cat([]record{prompt}, c7, r7, []record{answer("result-1")}), "prompt call-0 call-1 result-1 answer"},
		{"odd shapes", cat([]record{prompt}, c8, r8, []record{
			rec("assistant", "no-message", "result-1"),
			rec("assistant", "odd", "no-message", "message", record{"id": 7, "content": []any{"text", nil, record{"type": "tool_use"}}}),
			rec("user", "odd-result", "odd", "message", record{"content": []any{record{"type": "tool_result", "tool_use_id": 3}}}),
		}), "prompt call-0 call-1 result-0 result-1 no-message odd odd-result"},
	} {
		if got := uuids(chain(parseEntries(jsonl(t, c.records...)))); got != c.want {
			t.Errorf("%s: chain = %s\nwant %s", c.name, got, c.want)
		}
	}
}

func TestSequentialCallsUnchanged(t *testing.T) {
	call := func(uuid, parent, id string) record {
		return rec("assistant", uuid, parent, "message", record{"id": "msg_1", "content": []any{record{"type": "tool_use", "id": id}}})
	}
	result := func(uuid, parent, id string) record {
		return rec("user", uuid, parent, "message", record{"content": []any{record{"type": "tool_result", "tool_use_id": id}}})
	}
	records := []record{rec("user", "prompt", ""), call("call-0", "prompt", "toolu_0"), result("result-0", "call-0", "toolu_0"),
		call("call-1", "result-0", "toolu_1"), result("result-1", "call-1", "toolu_1")}
	if got := uuids(chain(parseEntries(jsonl(t, records...)))); got != "prompt call-0 result-0 call-1 result-1" {
		t.Errorf("chain = %s", got)
	}
}

func TestParseEntriesIsLenient(t *testing.T) {
	data := []byte("not json\n\n  {\"type\":\"user\",\"uuid\":\"a\",\"isMeta\":1,\"teamName\":\"\",\"agentId\":null}  \n[1]\n" +
		`{"type":"user","uuid":5}` + "\n" + `{"type":"file-history-snapshot","uuid":"f"}` + "\n" +
		`{"type":"assistant","uuid":"b","parentUuid":7,"message":"text"}`)
	got := parseEntries(data)
	if uuids(got) != "a b" {
		t.Fatalf("parseEntries kept %s", uuids(got))
	}
	if a := got[0]; !a.meta || a.team || a.agentID != "" || a.parent != "" {
		t.Errorf("a = %+v", a)
	}
	if b := got[1]; b.parent != "" || b.msgID != "" {
		t.Errorf("b = %+v", b)
	}
}

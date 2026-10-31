// Partly ported from the Claude Agent SDK for Python's tests (commit
// 27858cbb, tests/test_sessions.py), MIT License, Copyright (c) 2025
// Anthropic, PBC: see ../NOTICE.

package sessions

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// transcript writes records as session id's transcript in folder dir.
func transcript(t *testing.T, dir, id string, records ...record) {
	t.Helper()
	writeLines(t, dir, id, strings.Split(strings.TrimSuffix(string(jsonl(t, records...)), "\n"), "\n")...)
}

func messageUUIDs(ms []Message) string {
	var out []string
	for _, m := range ms {
		out = append(out, m.UUID)
	}
	return strings.Join(out, " ")
}

func TestMessages(t *testing.T) {
	config, cwd, dir := project(t)
	id := newUUID()
	c, r := parallelTurn("u2", 2, 1, 0)
	transcript(t, dir, id, cat([]record{
		text("user", "u1", "", "hello"),
		text("assistant", "a1", "u1", "hi"),
		rec("user", "meta", "a1", "isMeta", true, "message", record{"content": "caveat"}),
		rec("system", "sys", "meta", "subtype", "informational"),
		text("user", "u2", "sys", "read them"),
	}, c, r, []record{text("assistant", "a2", "result-0", "done")})...)

	got, err := Store{ConfigDir: config}.Messages(id, cwd)
	if err != nil {
		t.Fatal(err)
	}
	if want := "u1 a1 u2 call-0 call-1 result-1 result-0 a2"; messageUUIDs(got) != want {
		t.Errorf("Messages = %s\nwant %s", messageUUIDs(got), want)
	}
	first := got[0]
	var msg struct{ Content string }
	if first.Type != "user" || first.SessionID != "s" || json.Unmarshal(first.Message, &msg) != nil || msg.Content != "hello" ||
		!strings.Contains(string(first.Raw), `"uuid":"u1"`) || first.ParentToolUseID != "" {
		t.Errorf("first message = %+v", first)
	}
	if all, err := (Store{ConfigDir: config}).Messages(id, ""); err != nil || len(all) != len(got) {
		t.Errorf("Messages anywhere = %d, %v", len(all), err)
	}
}

func TestMessagesAfterCompaction(t *testing.T) {
	config, cwd, dir := project(t)
	id := newUUID()
	transcript(t, dir, id,
		text("user", "old-u", "", "before"),
		text("assistant", "old-a", "old-u", "answer"),
		rec("system", "boundary", "", "subtype", "compact_boundary", "logicalParentUuid", "old-a"),
		rec("user", "summary", "boundary", "isCompactSummary", true, "message", record{"content": "This session is being continued…"}),
		text("assistant", "kept", "summary", "kept verbatim"),
		text("user", "new-u", "kept", "after"),
	)
	got, err := Store{ConfigDir: config}.Messages(id, cwd)
	if err != nil || messageUUIDs(got) != "summary kept new-u" {
		t.Errorf("Messages = %s, %v; want the summary and what follows", messageUUIDs(got), err)
	}
}

func TestMessagesMissing(t *testing.T) {
	config, cwd, dir := project(t)
	empty := newUUID()
	writeLines(t, dir, empty)
	for _, id := range []string{newUUID(), empty} {
		if _, err := (Store{ConfigDir: config}).Messages(id, cwd); !errors.Is(err, fs.ErrNotExist) {
			t.Errorf("Messages(%s) = %v", id, err)
		}
	}
	if _, err := (Store{ConfigDir: config}).Messages("../x", cwd); err == nil || errors.Is(err, fs.ErrNotExist) {
		t.Errorf("Messages of a bad id = %v", err)
	}
	corrupt := newUUID()
	writeLines(t, dir, corrupt, "{oops", `{"type":"user","uuid":"u","message":{"content":"hi"}}`, "nope")
	if got, err := (Store{ConfigDir: config}).Messages(corrupt, cwd); err != nil || messageUUIDs(got) != "u" {
		t.Errorf("Messages past corrupt lines = %s, %v", messageUUIDs(got), err)
	}
}

func TestSubagentMessagesParallelCalls(t *testing.T) {
	config, cwd, dir := project(t)
	id := newUUID()
	transcript(t, dir, id, text("user", "u", "", "go"))
	calls, results := parallelTurn("task", 2, 0, 1)
	var records []record
	records = append(records, text("user", "task", "", "look"))
	records = append(records, calls...)
	records = append(records, results...)
	records = append(records, text("assistant", "end", "result-1", "done"))
	transcript(t, filepath.Join(dir, id, "subagents"), "agent-a1", records...)

	got, err := Store{ConfigDir: config}.SubagentMessages(id, cwd, "a1")
	if err != nil {
		t.Fatal(err)
	}
	var uuids []string
	for _, m := range got {
		uuids = append(uuids, m.UUID)
	}
	want := []string{"task", "call-0", "call-1", "result-0", "result-1", "end"}
	if !slices.Equal(uuids, want) {
		t.Errorf("messages = %v, want %v", uuids, want)
	}
}

func TestSubagents(t *testing.T) {
	config, cwd, dir := project(t)
	id, none := newUUID(), newUUID()
	transcript(t, dir, id, text("user", "u", "", "go"))
	transcript(t, dir, none, text("user", "u", "", "go"))
	agents := filepath.Join(dir, id, "subagents")
	transcript(t, agents, "agent-b2", text("user", "b-u", "", "task"), text("assistant", "b-a", "b-u", "done"))
	transcript(t, agents, "agent-a1", text("user", "a-u", "", "task"))
	transcript(t, filepath.Join(agents, "workflows", "run-1"), "agent-c3",
		text("user", "c-u", "", "nested"), text("assistant", "c-a", "c-u", "ok"),
		rec("progress", "c-p", "c-a"))
	files := map[string]string{
		"agent-b2.meta.json":                    `{"toolUseId":"toolu_b","agentType":"general-purpose"}`,
		"agent-a1.meta.json":                    `not json`,
		"workflows/run-1/agent-c3.meta.json":    `{"toolUseId":"toolu_c","parentAgentId":"b2"}`,
		"notes.txt":                             "x",
		"agent-d4.json":                         "{}",
		"workflows/run-1/agent-e5.jsonl.backup": "{}",
	}
	for name, body := range files {
		if err := os.WriteFile(filepath.Join(agents, name), []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}

	got, err := Store{ConfigDir: config}.Subagents(id, cwd)
	if err != nil {
		t.Fatal(err)
	}
	want := []Subagent{{ID: "a1"}, {ID: "b2", ParentToolUseID: "toolu_b"}, {ID: "c3", ParentToolUseID: "toolu_c", ParentAgentID: "b2"}}
	if len(got) != len(want) {
		t.Fatalf("Subagents = %+v", got)
	}
	for i := range want {
		got[i].path = ""
		if got[i] != want[i] {
			t.Errorf("Subagents[%d] = %+v, want %+v", i, got[i], want[i])
		}
	}
	if got, err := (Store{ConfigDir: config}).Subagents(none, ""); err != nil || len(got) != 0 {
		t.Errorf("Subagents of a session with none = %+v, %v", got, err)
	}
	if _, err := (Store{ConfigDir: config}).Subagents(newUUID(), cwd); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("Subagents of a missing session = %v", err)
	}

	ms, err := Store{ConfigDir: config}.SubagentMessages(id, cwd, "c3")
	if err != nil || messageUUIDs(ms) != "c-u c-a" || ms[0].ParentToolUseID != "toolu_c" || ms[1].ParentAgentID != "b2" {
		t.Errorf("SubagentMessages = %+v, %v", ms, err)
	}
	for _, agent := range []string{"zz", "", "d4"} {
		if _, err := (Store{ConfigDir: config}).SubagentMessages(id, cwd, agent); !errors.Is(err, fs.ErrNotExist) {
			t.Errorf("SubagentMessages(%q) = %v", agent, err)
		}
	}
}

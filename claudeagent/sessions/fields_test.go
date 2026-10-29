// Partly ported from the Claude Agent SDK for Python's tests (commit
// 27858cbb, tests/test_sessions.py), MIT License, Copyright (c) 2025
// Anthropic, PBC: see ../NOTICE.

package sessions

import (
	"strings"
	"testing"
)

func TestStringFields(t *testing.T) {
	for _, c := range []struct{ text, key, first, last string }{
		{`{"foo":"bar","baz":"qux"}`, "foo", "bar", "bar"},
		{`{"foo":"bar","baz":"qux"}`, "baz", "qux", "qux"},
		{`{"foo":"bar"}`, "missing", "", ""},
		{`{"foo": "bar"}`, "foo", "bar", "bar"},
		{`{"foo":"bar\"baz"}`, "foo", `bar"baz`, `bar"baz`},
		{`{"foo":"café"}`, "foo", "café", "café"},
		{"{\"summary\":\"first\"}\n{\"summary\":\"second\"}\n{\"summary\": \"third\"}", "summary", "first", "third"},
		{`{"foo":"cut off`, "foo", "", ""},
	} {
		if got := firstString(c.text, c.key); got != c.first {
			t.Errorf("firstString(%s, %s) = %q, want %q", c.text, c.key, got, c.first)
		}
		if got := lastString(c.text, c.key); got != c.last {
			t.Errorf("lastString(%s, %s) = %q, want %q", c.text, c.key, got, c.last)
		}
	}
}

func TestFirstPrompt(t *testing.T) {
	user := func(fields string) string { return `{"type":"user",` + fields + "}\n" }
	long := strings.Repeat("x", 300)
	for _, c := range []struct{ name, head, want string }{
		{"simple", user(`"message":{"content":"Hello!"}`), "Hello!"},
		{"meta skipped", user(`"isMeta":true,"message":{"content":"meta"}`) + user(`"message":{"content":"real prompt"}`), "real prompt"},
		{"tool result skipped", user(`"message":{"content":[{"type":"tool_result","content":"x"}]}`) + user(`"message":{"content":"actual prompt"}`), "actual prompt"},
		{"compaction summary skipped", user(`"isCompactSummary": true,"message":{"content":"summary"}`) + user(`"message":{"content":"next"}`), "next"},
		{"text blocks", user(`"message":{"content":[{"type":"image"},{"type":"text","text":"block prompt"}]}`), "block prompt"},
		{"one line", user(`"message":{"content":"  two\nlines  "}`), "two lines"},
		{"cut at 200", user(`"message":{"content":"` + long + `"}`), strings.Repeat("x", 200) + "…"},
		{"command fallback", user(`"message":{"content":"<command-name>/help</command-name>stuff"}`), "/help"},
		{"command, then a prompt", user(`"message":{"content":"<command-name>/help</command-name>"}`) + user(`"message":{"content":"hi"}`), "hi"},
		{"the CLI's own", user(`"message":{"content":"<local-command-stdout>x"}`) + user(`"message":{"content":"[Request interrupted by user for tool use]"}`), ""},
		{"an IDE's", user(`"message":{"content":"<ide_opened_file>a.go</ide_opened_file>"}`), ""},
		{"none", `{"type":"assistant"}` + "\n", ""},
		{"empty", "", ""},
	} {
		if got := firstPrompt(c.head); got != c.want {
			t.Errorf("%s: firstPrompt = %q, want %q", c.name, got, c.want)
		}
	}
}

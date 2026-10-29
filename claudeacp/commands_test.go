package claudeacp

import (
	"io"
	"strings"
	"testing"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// commandNames are the commands of each available_commands_update so
// far, as name(hint) lists.
func (c *client) commandNames() []string {
	var out []string
	for _, u := range c.of("available_commands_update") {
		var names []string
		for _, cmd := range u.AvailableCommandsUpdate.AvailableCommands {
			n := cmd.Name
			if cmd.Input != nil && cmd.Input.Unstructured != nil {
				n += "(" + cmd.Input.Unstructured.Hint + ")"
			}
			names = append(names, n)
		}
		out = append(out, strings.Join(names, " "))
	}
	return out
}

// A new session's commands are claude's but for the ones a client has no
// use for; they go again when claude's change, and when a turn says which
// only claude's terminal runs.
func TestCommands(t *testing.T) {
	read := make(chan struct{})
	f := started(`{"commands":[{"name":"compact","description":"Compact the conversation","argumentHint":"<instructions>"},`+
		`{"name":"login","description":"Sign in"},{"name":"review","description":"Review a change"},{"name":"mcp","description":"MCP"}]}`, `null`,
		user("id2"), echo("id2"),
		claudetest.Send(`{"type":"system","subtype":"commands_changed","commands":[{"name":"review","description":"Review"},{"name":"init","description":"Set up"}]}`),
		claudetest.Send(`{"type":"system","subtype":"init","model":"m","terminal_slash_commands":["/init"]}`),
		claudetest.Send(`{"type":"system","subtype":"init","model":"m","terminal_slash_commands":["/init"]}`),
		result(""), claudetest.Send(idle), signal(read))
	p := start(t, nil, f)
	sid := p.open(t)
	eventually(t, "the commands", func() bool { return len(p.commandNames()) == 1 })
	if got := p.commandNames()[0]; got != "compact(<instructions>) review" {
		t.Errorf("%s", got)
	}
	stopReason(p.prompt(t, sid, "go"))
	wait(t, read, "the script")
	if got := p.commandNames(); strings.Join(got, "|") != "compact(<instructions>) review|review init|review" {
		t.Errorf("%q", got)
	}
}

// What goes after a session's answer waits for the answer that opens it,
// and runs once; nothing else the agent writes sets it off.
func TestAfterAnswer(t *testing.T) {
	aa := &afterAnswer{w: io.Discard}
	ran := ""
	aa.after("s1", func() { ran += "s1" })
	aa.after("s2", func() { ran += "s2" })
	for _, tc := range []struct{ line, runs string }{
		{`{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"s1","update":{}}}`, ""},
		{`{"jsonrpc":"2.0","id":7,"method":"session/request_permission","params":{"sessionId":"s1"},"result":{"sessionId":"s1"}}`, ""},
		{`{"jsonrpc":"2.0","id":2,"result":{"stopReason":"end_turn"}}`, ""},
		{`{"jsonrpc":"2.0","id":3,"result":{"sessionId":"s2","modes":{}}}`, "s2"},
		{`{"jsonrpc":"2.0","id":"x","result":{"sessionId":"s1"}}`, "s1"},
		{`{"jsonrpc":"2.0","id":4,"result":{"sessionId":"s1"}}`, ""},
	} {
		ran = ""
		if fn := aa.answered([]byte(tc.line)); fn != nil {
			fn()
		}
		if ran != tc.runs {
			t.Errorf("%s ran %q", tc.line, ran)
		}
	}
	if _, err := aa.Write([]byte("x\n")); err != nil {
		t.Error(err)
	}
	if n := len(aa.then); n != 0 {
		t.Errorf("%d waiting", n)
	}
}

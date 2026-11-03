package ante

import (
	"context"
	"encoding/json"
	"fmt"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/ante/antetest"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// calls folds the session's tool calls as a client does, in the order they
// came: id, the call it is a step of, tool, title, status, text.
func (c *client) calls(sid acp.SessionID) []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	type call struct {
		id, parent, tool, title, status, text string
	}
	var out []*call
	find := func(id string) *call {
		i := slices.IndexFunc(out, func(c *call) bool { return c.id == id })
		if i < 0 {
			out = append(out, &call{id: id})
			return out[len(out)-1]
		}
		return out[i]
	}
	text := func(content []acp.ToolCallContent) string {
		var parts []string
		for _, b := range content {
			if b.Content != nil && b.Content.Content.Text != nil {
				parts = append(parts, b.Content.Content.Text.Text)
			}
		}
		return strings.Join(parts, " ")
	}
	for _, n := range c.updates {
		switch u := n.Update; {
		case n.SessionID != sid:
		case u.ToolCall != nil:
			it := find(string(u.ToolCall.ToolCallID))
			it.title, it.status, it.text = u.ToolCall.Title, string(u.ToolCall.Status), text(u.ToolCall.Content)
			it.parent, it.tool = Harness{}.Parent(u.ToolCall.Meta), bridgeMeta(u.ToolCall.Meta, "toolName")
		case u.ToolCallUpdate != nil:
			it := find(string(u.ToolCallUpdate.ToolCallID))
			if s := u.ToolCallUpdate.Status; s != "" {
				it.status = string(s)
			}
			if u.ToolCallUpdate.Content != nil {
				it.text = text(u.ToolCallUpdate.Content)
			}
		}
	}
	lines := make([]string, 0, len(out))
	for _, it := range out {
		lines = append(lines, strings.Join([]string{it.id, it.parent, it.tool, it.title, it.status, it.text}, "|"))
	}
	return lines
}

// A subagent is its Agent call, its report the call's text, and what it
// did the call's steps, whole from its log, with a call its policy denied;
// a resume replays the same, though Ante's parent log has none of the lines.
func TestASubagentLiveAndReplayed(t *testing.T) {
	store := &antetest.Store{Home: t.TempDir()}
	c := start(t, store)
	s, err := c.NewSession(context.Background(), &acp.NewSessionRequest{Cwd: "/work"})
	testcheck.NoErr(t, err)
	if r := prompt(t, c, s.SessionID, "ask a subagent"); r.StopReason != "end_turn" {
		t.Errorf("stop reason %q", r.StopReason)
	}
	const fence = "```"
	want := []string{
		"call_a||Agent|Find the handler|completed|" + antetest.Report,
		"call_a.step1|call_a|Read|Read a.go|completed|" + fence + "\npackage a\n" + fence,
		"call_a.step2|call_a|Grep|Grep handle|completed|a.go:3:func handle() {}",
		"call_a.tool_3|call_a|Bash|Bash|failed|Tool call denied by policy and was not executed.",
	}
	live := c.calls(s.SessionID)
	if !slices.Equal(live, want) {
		t.Errorf("live:\n%s\nwant:\n%s", strings.Join(live, "\n"), strings.Join(want, "\n"))
	}
	if got := c.texts(s.SessionID); strings.Contains(strings.Join(got, "\n"), "Looking for the handler") {
		t.Errorf("the subagent's text is in the parent's flow: %q", got)
	}

	c2 := start(t, store)
	_, err = c2.LoadSession(context.Background(), &acp.LoadSessionRequest{SessionID: s.SessionID, Cwd: "/work"})
	testcheck.NoErr(t, err)
	if got := c2.calls(s.SessionID); !slices.Equal(got, live) {
		t.Errorf("replayed:\n%s\nlive:\n%s", strings.Join(got, "\n"), strings.Join(live, "\n"))
	}
}

// A fork has the conversation but not the folder of the subagent's log:
// the log is found under the session that ran it.
func TestASubagentOfAFork(t *testing.T) {
	store := &antetest.Store{Home: t.TempDir()}
	c := start(t, store)
	s, err := c.NewSession(context.Background(), &acp.NewSessionRequest{Cwd: "/work"})
	testcheck.NoErr(t, err)
	prompt(t, c, s.SessionID, "ask a subagent")
	f, err := c.ForkSession(context.Background(), &acp.ForkSessionRequest{SessionID: s.SessionID, Cwd: "/work"})
	testcheck.NoErr(t, err)
	c2 := start(t, store)
	_, err = c2.LoadSession(context.Background(), &acp.LoadSessionRequest{SessionID: f.SessionID, Cwd: "/work"})
	testcheck.NoErr(t, err)
	if got := c2.calls(f.SessionID); len(got) != 4 {
		t.Errorf("the fork's calls: %q", got)
	}
}

// Without its log the steps are what the lines said, ended with the
// subagent, and the line that isn't a call is the call's progress only.
func TestASubagentWithoutItsLog(t *testing.T) {
	store := &antetest.Store{Home: t.TempDir()}
	c := start(t, store)
	s, err := c.NewSession(context.Background(), &acp.NewSessionRequest{Cwd: "/work"})
	testcheck.NoErr(t, err)
	prompt(t, c, s.SessionID, "ask an unsaved subagent")
	want := []string{
		"call_a||Agent|Find the handler|completed|" + antetest.Report,
		"call_a.step1|call_a|Read|Read a.go|completed|",
		"call_a.step2|call_a|Grep|Grep handle|completed|",
	}
	if got := c.calls(s.SessionID); !slices.Equal(got, want) {
		t.Errorf("calls:\n%s", strings.Join(got, "\n"))
	}
}

// While it runs its steps show one by one; a stopped turn fails the subagent
// and what it was doing, and nothing stays running.
func TestASubagentCancelled(t *testing.T) {
	store := &antetest.Store{Home: t.TempDir(), Waiting: make(chan string, 1)}
	c := start(t, store)
	s, err := c.NewSession(context.Background(), &acp.NewSessionRequest{Cwd: "/work"})
	testcheck.NoErr(t, err)
	wait := begin(t, c, store, s.SessionID, "wait for a subagent")
	if !testcheck.Eventually(func() bool { return len(c.calls(s.SessionID)) == 3 }) {
		t.Fatalf("calls: %q", c.calls(s.SessionID))
	}
	want := []string{
		"call_a||Agent|Find the handler|in_progress|Looking for the handler.",
		"call_a.step1|call_a|Read|Read a.go|completed|",
		"call_a.step2|call_a|Grep|Grep handle|in_progress|",
	}
	if got := c.calls(s.SessionID); !slices.Equal(got, want) {
		t.Errorf("running:\n%s", strings.Join(got, "\n"))
	}
	testcheck.NoErr(t, c.Cancel(context.Background(), &acp.CancelNotification{SessionID: s.SessionID}))
	if r := wait(); r.StopReason != "cancelled" {
		t.Errorf("stop reason %q", r.StopReason)
	}
	want = []string{
		"call_a||Agent|Find the handler|failed|subagent cancelled",
		"call_a.step1|call_a|Read|Read a.go|completed|",
		"call_a.step2|call_a|Grep|Grep handle|failed|",
	}
	if got := c.calls(s.SessionID); !slices.Equal(got, want) {
		t.Errorf("stopped:\n%s", strings.Join(got, "\n"))
	}
}

func TestReadStep(t *testing.T) {
	for line, want := range map[string]string{
		`Read(file_path="src/a.go")`:                 `Read {"file_path":"src/a.go"}`,
		`Grep(path=".", pattern="a, b")`:             `Grep {"path":".","pattern":"a, b"}`,
		`Read(file_path="a.go", limit=20, offset=3)`: `Read {"file_path":"a.go","limit":"20","offset":"3"}`,
		`mcp__docs__find(query="x")`:                 `mcp__docs__find {"query":"x"}`,
		"Bash(command=\"go test\n./...\")":           `Bash {"command":"go test\n./..."}`,
	} {
		t.Run(line, func(t *testing.T) {
			u, ok := readStep(line)
			if got := fmt.Sprintf("%s %s", u.Name, u.Args); !ok || got != want {
				t.Errorf("got %s (%v), want %s", got, ok, want)
			}
		})
	}
	for _, line := range []string{"Found it.", "waiting for a subagent slot", "Read", "lower(a=1)", "Done (all=3)", "Found(two) of them", "Fix(the bug)"} {
		if u, ok := readStep(line); ok {
			t.Errorf("%q read as a call: %+v", line, u)
		}
	}
}

func TestReportIsTheCallsText(t *testing.T) {
	if got := result(json.RawMessage(`{"report":"## Done","session_id":"ses_x","tool_use_count":2}`)); got != "## Done" {
		t.Errorf("result = %q", got)
	}
}

// A call of the bridge's makes the item the chats feature shows.
func TestToolCallOfASubagent(t *testing.T) {
	var it model.Item
	meta := map[string]any{"ante": map[string]any{"toolName": "Agent", "parentToolUseId": ""}}
	Harness{}.ToolCall(&it, meta, json.RawMessage(`{"description":"d","prompt":"p","subagent_type":"explore","model":"m2"}`))
	Harness{}.ToolCall(&it, nil, nil) // a later update: nothing lost
	if it.Tool != "Agent" || it.Agent != "explore" || it.Prompt != "p" || it.Model != "m2" || it.Parent != "" {
		t.Errorf("item = %+v", it)
	}
	var step model.Item
	Harness{}.ToolCall(&step, map[string]any{"ante": map[string]any{"toolName": "Read", "parentToolUseId": "call_a"}}, nil)
	if step.Parent != "call_a" || step.Tool != "Read" || step.Agent != "" {
		t.Errorf("step = %+v", step)
	}
}

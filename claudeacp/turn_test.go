package claudeacp

import (
	"errors"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/claudetest"
)

// queue is the session's unsettled prompts, by id, and the running one.
func (p *peer) queue(t *testing.T, sid acp.SessionID) (ids []string, active string) {
	t.Helper()
	s, err := p.agent.session(sid)
	if err != nil {
		t.Fatal(err)
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, x := range s.turns {
		ids = append(ids, x.id)
	}
	if s.active != nil {
		active = s.active.id
	}
	return ids, active
}

// prompts sends texts as prompts, each once the fake has read the one
// before (its script signals each on gates), so their order is known.
func (p *peer) prompts(t *testing.T, sid acp.SessionID, gates []chan struct{}, texts ...string) []func() (*acp.PromptResponse, error) {
	t.Helper()
	var ws []func() (*acp.PromptResponse, error)
	for i, text := range texts {
		ws = append(ws, p.prompt(t, sid, text))
		wait(t, gates[i], "prompt "+text+" read")
	}
	return ws
}

func gates(n int) []chan struct{} {
	g := make([]chan struct{}, n)
	for i := range g {
		g[i] = make(chan struct{})
	}
	return g
}

// Prompts queue: each is answered at its own result, after its echo, not
// at the one before's; claude's idle after a result is owed to it and
// fails no prompt.
func TestQueue(t *testing.T) {
	g := gates(3)
	f := fake(user("id2"), signal(g[0]), user("id3"), signal(g[1]),
		echo("id2"), result(names("id2")), claudetest.Until(g[2]),
		echo("id3"), claudetest.Send(idle), result(names("id3")))
	p := start(t, nil, f)
	sid := p.open(t)
	ws := p.prompts(t, sid, g, "one", "two")
	if got := stopReason(ws[0]); got != "end_turn" {
		t.Errorf("one: %s", got)
	}
	if ids, _ := p.queue(t, sid); !slices.Equal(ids, []string{"id3"}) {
		t.Errorf("queued %q", ids)
	}
	close(g[2])
	if got := stopReason(ws[1]); got != "end_turn" {
		t.Errorf("two: %s", got)
	}
}

// A result that names prompts claude folded into its turn answers them
// too; one whose origin is claude's own (a background task's end) answers
// none, unless it names one.
func TestResultLanes(t *testing.T) {
	g := gates(2)
	f := fake(user("id2"), signal(g[0]), echo("id2"), user("id3"), signal(g[1]),
		claudetest.Send(`{"type":"result","subtype":"success","origin":{"kind":"task-notification"},"usage":{"input_tokens":100}}`),
		result(names("id2", "id3")))
	p := start(t, nil, f)
	sid := p.open(t)
	ws := p.prompts(t, sid, g, "one", "two")
	r, err := ws[0]()
	if err != nil || r.StopReason != acp.StopReasonEndTurn || r.Usage.InputTokens != 3 {
		t.Errorf("one: %+v %v", r, err)
	}
	if got := stopReason(ws[1]); got != "end_turn" {
		t.Errorf("two: %s", got)
	}
	var origins []string
	for _, u := range p.of("usage_update") {
		origins = append(origins, u.UsageUpdate.Meta["_claude/origin"].(map[string]any)["kind"].(string))
	}
	if !slices.Equal(origins, []string{"task-notification", "human"}) {
		t.Errorf("%q", origins)
	}
}

// An idle while a prompt runs with no result fails it.
func TestNoResult(t *testing.T) {
	p := start(t, nil, fake(user("id2"), echo("id2"), claudetest.Send(running), claudetest.Send(idle)))
	sid := p.open(t)
	_, err := p.prompt(t, sid, "hi")()
	if e, ok := errors.AsType[*acp.Error](err); !ok || e.Code != acp.ErrorCodeInternalError || string(e.Data) != `{"errorKind":"no_result"}` {
		t.Errorf("%v", err)
	}
}

// The result's subtype and stop reason make the prompt's stop reason; a
// failed turn is an error with claude's text and the API's error kind.
func TestStopReason(t *testing.T) {
	for _, tc := range []struct {
		r    claudeagent.Result
		kind string
		want string
	}{
		{claudeagent.Result{Subtype: "success"}, "", "end_turn"},
		{claudeagent.Result{Subtype: "success", StopReason: "refusal"}, "", "refusal"},
		{claudeagent.Result{Subtype: "error_during_execution", StopReason: "max_tokens"}, "", "max_tokens"},
		{claudeagent.Result{Subtype: "error_during_execution"}, "", "end_turn"},
		{claudeagent.Result{Subtype: "error_max_turns"}, "", "max_turn_requests"},
		{claudeagent.Result{Subtype: "error_max_budget_usd"}, "", "max_turn_requests"},
		{claudeagent.Result{Subtype: "success", IsError: true, Result: "API Error: 529"}, "overloaded",
			`API Error: 529 {"errorKind":"overloaded"}`},
		{claudeagent.Result{Subtype: "error_max_turns", IsError: true, Errors: []string{"a", "b"}}, "", "a, b "},
	} {
		o := stop(&tc.r, newTurn("u"), tc.kind)
		var got string
		if e, ok := errors.AsType[*acp.Error](o.err); ok {
			got = e.Message + " " + string(e.Data)
		} else {
			got = string(o.resp.StopReason)
		}
		if got != tc.want {
			t.Errorf("%+v: %s, want %s", tc.r, got, tc.want)
		}
	}
	tu := newTurn("u")
	tu.cancelled = true
	if o := stop(&claudeagent.Result{Subtype: "success"}, tu, ""); o.resp.StopReason != acp.StopReasonCancelled {
		t.Errorf("a cancelled turn: %+v", o.resp)
	}
}

// Cancel answers the prompts claude hasn't taken at once, dropping them
// from claude's queue, and interrupts the running one, which is answered
// at its result. Until a turn starts again the stopped work's top-level
// text is dropped; a subagent's is not.
func TestCancel(t *testing.T) {
	g := gates(4)
	f := fake(user("id2"), signal(g[0]), echo("id2"), user("id3"), signal(g[1]), user("id4"), signal(g[2]),
		claudetest.Until(g[3]),
		event(`{"type":"message_start","message":{"id":"msg_1"}}`),
		delta("0", "text_delta", "text", "dropped"),
		claudetest.Send(`{"type":"stream_event","parent_tool_use_id":"toolu_1","event":{"type":"message_start","message":{"id":"msg_s"}}}`),
		claudetest.Send(`{"type":"stream_event","parent_tool_use_id":"toolu_1","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"kept"}}}`),
		result(names("id2")), claudetest.Send(idle),
		echo("id3"), result(names("id3")), // the dropped prompt's, which claude had taken
		claudetest.Send(`{"type":"system","subtype":"status","status":"requesting"}`), // work of claude's own
		event(`{"type":"message_start","message":{"id":"msg_2"}}`),
		delta("0", "text_delta", "text", "own"),
		claudetest.Send(`{"type":"result","subtype":"success","origin":{"kind":"task-notification"}}`))
	p := start(t, nil, f)
	sid := p.open(t)
	ws := p.prompts(t, sid, g, "one", "two", "three")
	eventually(t, "one running", func() bool { _, a := p.queue(t, sid); return a == "id2" })
	if err := p.Cancel(t.Context(), &acp.CancelNotification{SessionID: sid}); err != nil {
		t.Fatal(err)
	}
	for _, w := range ws[1:] {
		if got := stopReason(w); got != "cancelled" {
			t.Errorf("a queued prompt: %s", got)
		}
	}
	if ids, a := p.queue(t, sid); !slices.Equal(ids, []string{"id2"}) || a != "id2" {
		t.Errorf("queued %q, running %s", ids, a)
	}
	close(g[3])
	if got := stopReason(ws[0]); got != "cancelled" {
		t.Errorf("the running prompt: %s", got)
	}
	<-f.Played()
	eventually(t, "the last result", func() bool { return len(p.of("usage_update")) == 3 })
	if got := p.texts(); !slices.Equal(got, []string{"text:msg_s:kept", "text:msg_2:own"}) {
		t.Errorf("%q", got)
	}
	eventually(t, "drops and an interrupt", func() bool { return len(f.Responded()) == 3 })
	all := strings.Join(f.Responded(), "\n")
	for _, want := range []string{`"message_uuid":"id3"`, `"message_uuid":"id4"`, `"subtype":"interrupt"`} {
		if !strings.Contains(all, want) {
			t.Errorf("no %s in\n%s", want, all)
		}
	}
	if ids, _ := p.queue(t, sid); len(ids) != 0 {
		t.Errorf("queued %q", ids)
	}
}

// A cancelled prompt claude says no more of is answered at the idle, or
// after the backstop.
func TestCancelEnds(t *testing.T) {
	for _, tc := range []struct {
		name string
		idle bool
	}{{"idle", true}, {"backstop", false}} {
		t.Run(tc.name, func(t *testing.T) {
			taken, release := make(chan struct{}), make(chan struct{})
			steps := []claudetest.Step{user("id2"), echo("id2"), signal(taken), claudetest.Until(release)}
			if tc.idle {
				steps = append(steps, claudetest.Send(idle))
			}
			f := fake(steps...)
			p := start(t, nil, f)
			sid := p.open(t)
			w := p.prompt(t, sid, "hi")
			wait(t, taken, "the prompt taken")
			eventually(t, "the prompt running", func() bool { _, a := p.queue(t, sid); return a == "id2" })
			if err := p.Cancel(t.Context(), &acp.CancelNotification{SessionID: sid}); err != nil {
				t.Fatal(err)
			}
			s, _ := p.agent.session(sid)
			eventually(t, "the cancel taken", func() bool {
				s.mu.Lock()
				defer s.mu.Unlock()
				return s.active != nil && s.active.cancelled
			})
			close(release)
			if !tc.idle {
				p.clock.fire(t, backstop)
			}
			if got := stopReason(w); got != "cancelled" {
				t.Errorf("%s", got)
			}
		})
	}
}

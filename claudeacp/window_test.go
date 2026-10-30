package claudeacp

import (
	"fmt"
	"slices"
	"strings"
	"sync"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// windowInit is initialize's answer with a model whose names don't say
// its window and one whose do.
const windowInit = `{"models":[{"value":"default","resolvedModel":"claude-x","displayName":"Default"},` +
	`{"value":"big","resolvedModel":"claude-y","displayName":"Big","description":"Y (1M context)"}]}`

// windowAnswer has a fake answer get_context_usage with size.
func windowAnswer(f *claudetest.Fake, size string) *claudetest.Fake {
	f.Respond(`{"type":"control_request","request":{"subtype":"get_context_usage"}}`,
		`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{"rawMaxTokens":`+size+`}}}`)
	return f
}

// windowAsks counts f's asks for the context window.
func windowAsks(f *claudetest.Fake) int {
	n := 0
	for _, l := range f.Responded() {
		if strings.Contains(l, `"get_context_usage"`) {
			n++
		}
	}
	return n
}

// sessionWindow is s's window as known, and whether a result said it.
func sessionWindow(p *peer, sid acp.SessionID) (int, bool) {
	p.agent.mu.Lock()
	s := p.agent.sessions[string(sid)]
	p.agent.mu.Unlock()
	s.win.mu.Lock()
	defer s.win.mu.Unlock()
	return s.win.size, s.win.sure
}

// A session asks claude for its window as it starts, and its usage says
// the answer before the first result does; the result's window then
// counts, for the agent's next session too, which asks nothing. A model
// change asks again, unless a result has said that model's window.
func TestWindow(t *testing.T) {
	ok := `{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`
	f1 := windowAnswer(started(windowInit, `null`, user("id2"), echo("id2"),
		event(`{"type":"message_start","message":{"id":"msg_1","model":"claude-x","usage":{"input_tokens":10}}}`),
		result(names("id2")+`,"modelUsage":{"claude-x":{"contextWindow":950000}}`),
		claudetest.Send(idle)), "1000000")
	f1.Respond(`{"type":"control_request","request":{"subtype":"set_model"}}`, ok)
	f2 := windowAnswer(started(windowInit, `null`), "1000000")
	p := start(t, nil, f1, f2)
	sid := p.open(t)
	eventually(t, "the asked window", func() bool { n, _ := sessionWindow(p, sid); return n == 1_000_000 })
	if got := stopReason(p.prompt(t, sid, "hi")); got != "end_turn" {
		t.Fatal(got)
	}
	var sizes []uint64
	for _, u := range p.of("usage_update") {
		sizes = append(sizes, u.UsageUpdate.Size)
	}
	if !slices.Equal(sizes, []uint64{1_000_000, 950_000}) {
		t.Errorf("sizes %v", sizes)
	}

	sid2 := p.open(t)
	if n, sure := sessionWindow(p, sid2); n != 950_000 || !sure || windowAsks(f2) != 0 {
		t.Errorf("the next session's window %d %v, asked %d times", n, sure, windowAsks(f2))
	}

	set := func(v string) {
		t.Helper()
		if _, err := p.SetSessionConfigOption(t.Context(), &acp.SetSessionConfigOptionRequest{SessionID: sid, ConfigID: "model",
			ValueID: &acp.SetSessionConfigOptionRequestValueID{Value: acp.SessionConfigValueID(v)}}); err != nil {
			t.Fatal(err)
		}
	}
	set("big")
	eventually(t, "the second ask", func() bool { return windowAsks(f1) == 2 })
	if n, sure := sessionWindow(p, sid); n != 1_000_000 || sure {
		t.Errorf("after a change to a 1M model: %d %v, asked %d times", n, sure, windowAsks(f1))
	}
	set("default")
	if n, sure := sessionWindow(p, sid); n != 950_000 || !sure || windowAsks(f1) != 2 {
		t.Errorf("after a change back: %d %v, asked %d times", n, sure, windowAsks(f1))
	}
}

// windowScripted are the fakes whose scripts answer the ask for the
// context window, which start leaves to them.
var windowScripted sync.Map

// An answer that comes after a usage_update went with the guess sends
// it again with the answer's size.
func TestWindowLateAnswer(t *testing.T) {
	var p *peer
	updates := func(n int) claudetest.Step {
		return claudetest.Do(func() { eventually(t, "the usage updates", func() bool { return len(p.of("usage_update")) == n }) })
	}
	initOK := `{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":` + windowInit + `}}`
	f := withTitle(claudetest.New(claudetest.Expect(initRequest), claudetest.Send(initOK),
		claudetest.Expect(`{"type":"control_request","request":{"subtype":"get_context_usage","detail":"summary"}}`),
		user("id2"), echo("id2"),
		event(`{"type":"message_start","message":{"id":"msg_1","model":"claude-x","usage":{"input_tokens":10}}}`),
		updates(1),
		claudetest.Send(`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{"rawMaxTokens":1000000}}}`),
		updates(2),
		result(names("id2")+`,"modelUsage":{"claude-x":{"contextWindow":950000}}`),
		claudetest.Send(idle)), `null`)
	windowScripted.Store(f, true)
	p = start(t, nil, f)
	sid := p.open(t)
	if got := stopReason(p.prompt(t, sid, "hi")); got != "end_turn" {
		t.Fatal(got)
	}
	var got []string
	for _, u := range p.of("usage_update") {
		got = append(got, fmt.Sprintf("%d/%d", u.UsageUpdate.Used, u.UsageUpdate.Size))
	}
	if want := []string{"10/200000", "10/1000000", "10/950000"}; !slices.Equal(got, want) {
		t.Errorf("%q, want %q", got, want)
	}
}

// providerKey tells backends apart by the variables that route claude.
func TestProviderKey(t *testing.T) {
	a := providerKey([]string{"ANTHROPIC_BASE_URL=https://a", "HOME=/x"})
	b := providerKey([]string{"ANTHROPIC_BASE_URL=https://b", "HOME=/x"})
	c := providerKey([]string{"ANTHROPIC_BASE_URL=https://a", "HOME=/y"})
	if a == b || a != c {
		t.Errorf("%q %q %q", a, b, c)
	}
}

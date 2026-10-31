package claudeacp

import (
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// modelSwitch is claude's PostModelSwitch hook, as 2.1.312 calls it, and
// the answer it takes.
func modelSwitch(id, source, to string) []claudetest.Step {
	return []claudetest.Step{
		sendf(`{"type":"control_request","request_id":"` + id + `","request":{"subtype":"hook_callback","callback_id":"hook_0","input":{"hook_event_name":"PostModelSwitch",` +
			`"from_model":"claude-x","to_model":` + to + `,"requested_model":null,"source":"` + source + `"}}}`),
		claudetest.Expect(`{"type":"control_response","response":{"subtype":"success","request_id":"` + id + `"}}`),
	}
}

// claude's own switch of the model mid-turn (a refusal's fallback, to a
// model its list doesn't name) moves the option and the window at once,
// not at the next system/init or result, and the window is asked for
// after the hook's answer. A switch the client made, one a resume
// restored and an id that isn't one change nothing.
func TestModelSwitchFollowed(t *testing.T) {
	ask := `{"type":"control_request","request":{"subtype":"get_context_usage","detail":"summary"}}`
	sizeIs := func(size string) claudetest.Step {
		return claudetest.Send(`{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{"rawMaxTokens":` + size + `}}}`)
	}
	initOK := `{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":` + windowInit + `}}`
	steps := []claudetest.Step{claudetest.Expect(initRequest), claudetest.Send(initOK), claudetest.Expect(ask), sizeIs("1000000"),
		user("id2"), echo("id2"), event(`{"type":"message_start","message":{"id":"msg_1","model":"claude-x","usage":{"input_tokens":10}}}`)}
	steps = append(steps, modelSwitch("h1", "sdk", `"claude-y"`)...)
	steps = append(steps, modelSwitch("h2", "resume", `"claude-y"`)...)
	steps = append(steps, modelSwitch("h3", "auto", `"../../etc/passwd\n"`)...)
	steps = append(steps, modelSwitch("h4", "auto", `"claude-fallback"`)...)
	steps = append(steps, claudetest.Expect(ask), sizeIs("500000"),
		event(`{"type":"message_start","message":{"id":"msg_2","model":"claude-fallback","usage":{"input_tokens":20}}}`),
		result(names("id2")+`,"modelUsage":{"claude-x":{"contextWindow":1000000},"claude-fallback":{"contextWindow":400000}}`),
		claudetest.Send(idle))
	f := withTitle(claudetest.New(steps...), `null`)
	windowScripted.Store(f, true)
	p := start(t, nil, f)
	sid := p.open(t)
	if got := stopReason(p.prompt(t, sid, "hi")); got != "end_turn" {
		t.Fatal(got)
	}
	var opts []string
	for _, u := range p.of("config_option_update") {
		opts = append(opts, summary(u.ConfigOptionUpdate.ConfigOptions[1:2]))
	}
	if want := []string{"model/model=claude-fallback[default big]"}; !slices.Equal(opts, want) {
		t.Errorf("options %q, want %q", opts, want)
	}
	var sizes []uint64
	for _, u := range p.of("usage_update") {
		sizes = append(sizes, u.UsageUpdate.Size)
	}
	if !slices.Contains(sizes, 500_000) || sizes[len(sizes)-1] != 400_000 {
		t.Errorf("sizes %v: want the asked window, then the result's", sizes)
	}
}

// A switch between turns (a /model typed as a prompt) has no message of
// the new model before its result, whose modelUsage counts the session's
// old model: that isn't the new model's window.
func TestModelSwitchResultOfOldModel(t *testing.T) {
	steps := []claudetest.Step{user("id2"), echo("id2"),
		event(`{"type":"message_start","message":{"id":"msg_1","model":"claude-x","usage":{"input_tokens":10}}}`),
		result(names("id2") + `,"modelUsage":{"claude-x":{"contextWindow":1000000}}`), claudetest.Send(idle),
		user("id3"), echo("id3")}
	steps = append(steps, modelSwitch("h1", "command", `"claude-y"`)...)
	steps = append(steps, result(names("id3")+`,"modelUsage":{"claude-x":{"contextWindow":1000000}}`), claudetest.Send(idle))
	p := start(t, nil, windowAnswer(started(windowInit, `null`, steps...), "600000"))
	sid := p.open(t)
	for _, prompt := range []string{"hi", "/model big"} {
		if got := stopReason(p.prompt(t, sid, prompt)); got != "end_turn" {
			t.Fatal(got)
		}
	}
	eventually(t, "the new model's window", func() bool { n, sure := sessionWindow(p, sid); return n == 600_000 && !sure })
	var opts []string
	for _, u := range p.of("config_option_update") {
		opts = append(opts, summary(u.ConfigOptionUpdate.ConfigOptions))
	}
	if len(opts) != 1 || !strings.Contains(opts[0], "model/model=big[") {
		t.Errorf("options %q", opts)
	}
}

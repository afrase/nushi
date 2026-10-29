package claudeacp

import (
	"encoding/json"
	"slices"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

func event(e string) claudetest.Step {
	return claudetest.Send(`{"type":"stream_event","event":` + e + `}`)
}

func delta(index, kind, field, text string) claudetest.Step {
	return event(`{"type":"content_block_delta","index":` + index + `,"delta":{"type":"` + kind + `","` + field + `":"` + text + `"}}`)
}

func assistant(block string) claudetest.Step {
	return claudetest.Send(`{"type":"assistant","message":{"id":"msg_1","model":"claude-x[1m]","content":[` + block + `]}}`)
}

// Deltas stream as chunks under the API message's id; a completed block
// sends only what didn't stream, all of it when nothing did. Usage goes
// at the message's start and delta and at the result, which carries the
// cost, the origin and the model; the prompt's answer has the turn's
// tokens.
func TestStream(t *testing.T) {
	f := fake(user("id2"), echo("id2"),
		event(`{"type":"message_start","message":{"id":"msg_1","model":"claude-x[1m]","usage":{"input_tokens":10,"cache_read_input_tokens":5}}}`),
		delta("0", "thinking_delta", "thinking", "hmm"),
		assistant(`{"type":"thinking","thinking":"hmm","signature":"s"}`),
		delta("1", "text_delta", "text", "Hel"),
		delta("1", "text_delta", "text", ""),
		assistant(`{"type":"text","text":"Hello"}`),
		assistant(`{"type":"text","text":"Bye"}`),
		claudetest.Send(`{"type":"stream_event","parent_tool_use_id":"toolu_1","event":{"type":"message_start","message":{"id":"msg_s","model":"haiku"}}}`),
		claudetest.Send(`{"type":"stream_event","parent_tool_use_id":"toolu_1","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"sub"}}}`),
		event(`{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":7}}`),
		result(names("id2")+`,"origin":{"kind":"human","producer":"p"},"modelUsage":{"claude-x[1m]":{"contextWindow":900000}}`),
		claudetest.Send(idle))
	p := start(t, nil, f)
	sid := p.open(t)
	r, err := p.prompt(t, sid, "hi")()
	if err != nil {
		t.Fatal(err)
	}
	if r.StopReason != acp.StopReasonEndTurn || r.Usage.InputTokens != 3 || r.Usage.OutputTokens != 4 || r.Usage.TotalTokens != 7 {
		t.Errorf("%+v %+v", r, r.Usage)
	}
	want := []string{"thought:msg_1:hmm", "text:msg_1:Hel", "text:msg_1:lo", "text:msg_1:Bye", "text:msg_s:sub"}
	if got := p.texts(); !slices.Equal(got, want) {
		t.Errorf("texts %q", got)
	}
	for _, u := range p.of("agent_message_chunk") {
		cc, _ := u.AgentMessageChunk.Meta["claudeCode"].(map[string]any)
		if (u.AgentMessageChunk.MessageID == "msg_s") != (cc["parentToolUseId"] == "toolu_1") {
			t.Errorf("%+v", u.AgentMessageChunk)
		}
	}
	var got []string
	for _, u := range p.of("usage_update") {
		uu := u.UsageUpdate
		b, _ := json.Marshal(uu)
		got = append(got, string(b))
	}
	want = []string{
		`{"used":15,"size":1000000,"_meta":{"_claude/model":"claude-x[1m]"}}`,
		`{"used":22,"size":1000000,"_meta":{"_claude/model":"claude-x[1m]"}}`,
		`{"used":22,"size":900000,"cost":{"amount":0.5,"currency":"USD"},"_meta":{"_claude/model":"claude-x[1m]","_claude/origin":{"kind":"human","producer":"p"}}}`,
	}
	if !slices.Equal(got, want) {
		t.Errorf("usage\n%s\nwant\n%s", got, want)
	}
}

// A turn that showed no text shows its result's, as for a slash command
// claude answers itself; such a turn has no echo, and, with no model
// call, sends no usage (claude-agent-acp sends none: its counts are
// zeros).
func TestResultText(t *testing.T) {
	f := fake(user("id2"), claudetest.Send(`{"type":"result","subtype":"success","uuid":"r1","result":"Context: 5%","total_cost_usd":0}`), claudetest.Send(idle))
	p := start(t, nil, f)
	sid := p.open(t)
	if got := stopReason(p.prompt(t, sid, "/context")); got != "end_turn" {
		t.Fatal(got)
	}
	if got := p.texts(); !slices.Equal(got, []string{"text:r1:Context: 5%"}) {
		t.Errorf("%q", got)
	}
	if u := p.of("usage_update"); len(u) != 0 {
		t.Errorf("%+v", u)
	}
}

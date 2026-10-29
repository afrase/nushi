package claudeacp

import (
	"encoding/json"
	"errors"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// chunks are the message chunks so far as text|messageId|_meta.
func (c *client) chunks() []string {
	var out []string
	for _, u := range c.of("agent_message_chunk") {
		ch := u.AgentMessageChunk
		meta, _ := json.Marshal(ch.Meta)
		out = append(out, ch.Content.Text.Text+"|"+string(ch.MessageID)+"|"+string(meta))
	}
	return out
}

// Claude's notices are id-less text with their level as a label and a
// mark in _meta, or ACP notices for a client that shows them (which isn't
// told what is only information); a model fallback is labelled text.
func TestNotices(t *testing.T) {
	steps := []claudetest.Step{user("id2"), echo("id2"),
		sendf(`{"type":"system","subtype":"informational","level":"info","content":"Synced."}`),
		sendf(`{"type":"system","subtype":"informational","level":"notice","content":"Opus 5.5's safeguards stopped the response above"}`),
		sendf(`{"type":"system","subtype":"model_refusal_fallback","original_model":"a","fallback_model":"b","content":"Retrying with b."}`),
		result(names("id2")), claudetest.Send(idle)}
	p := start(t, nil, fake(steps...))
	if got := stopReason(p.prompt(t, p.open(t), "go")); got != "end_turn" {
		t.Fatal(got)
	}
	want := []string{
		`Synced.||{"claudeCode":{"kind":"informational","level":"info"}}`,
		`**Notice:** Opus 5.5's safeguards stopped the response above||{"claudeCode":{"kind":"informational","level":"notice"}}`,
		`**Model fallback:** Retrying with b.||null`,
	}
	if got := p.chunks(); !slices.Equal(got, want) {
		t.Errorf("%q", got)
	}

	p = start(t, &acp.ClientCapabilities{Session: &acp.ClientSessionCapabilities{Notices: &acp.NoticeCapabilities{}}}, fake(steps...))
	if got := stopReason(p.prompt(t, p.open(t), "go")); got != "end_turn" {
		t.Fatal(got)
	}
	var got []string
	for _, u := range p.of("notice") {
		got = append(got, string(u.Notice.Severity)+" "+u.Notice.Title)
	}
	if want := []string{"info Opus 5.5's safeguards stopped the response above", "warning Retrying with b."}; !slices.Equal(got, want) || len(p.chunks()) != 0 {
		t.Errorf("%q %q", got, p.chunks())
	}
}

// A compaction is a "compact" tool call ending with its facts, and the
// context's use after it; one that fails says why. Recalled memories are
// a finished read.
func TestCompaction(t *testing.T) {
	steps := []claudetest.Step{user("id2"),
		sendf(`{"type":"system","subtype":"status","status":"compacting","uuid":"c1"}`),
		sendf(`{"type":"system","subtype":"compact_boundary","uuid":"b1","compact_metadata":{"trigger":"manual","pre_tokens":900,"post_tokens":80,"duration_ms":1200}}`),
		sendf(`{"type":"system","subtype":"status","status":null,"compact_result":"success"}`),
		sendf(`{"type":"system","subtype":"status","status":"compacting","uuid":"c2"}`),
		sendf(`{"type":"system","subtype":"status","status":null,"compact_result":"failed","compact_error":"too short"}`),
		sendf(`{"type":"system","subtype":"memory_recall","uuid":"m1","memories":[{"path":"a"},{"path":"b"}]}`),
		result(""), claudetest.Send(idle)}
	p := start(t, nil, fake(steps...))
	if got := stopReason(p.prompt(t, p.open(t), "/compact")); got != "end_turn" {
		t.Fatal(got)
	}
	want := []string{
		`tool_call {"toolCallId":"c1","title":"Compact conversation","name":"compact","kind":"think","status":"in_progress","_meta":{"claudeCode":{"toolName":"compact"}}}`,
		`tool_call_update {"toolCallId":"c1","status":"completed","rawOutput":{"trigger":"manual","preTokens":900,"postTokens":80,"durationMs":1200},"_meta":{"claudeCode":{"toolName":"compact"}}}`,
		`tool_call {"toolCallId":"c2","title":"Compact conversation","name":"compact","kind":"think","status":"in_progress","_meta":{"claudeCode":{"toolName":"compact"}}}`,
		`tool_call_update {"toolCallId":"c2","status":"failed","content":[{"type":"content","content":{"type":"text","text":"Compaction failed: too short"}}],"rawOutput":{"error":"too short"},"_meta":{"claudeCode":{"toolName":"compact"}}}`,
		`tool_call {"toolCallId":"m1","title":"Recalled 2 memories","name":"memory_recall","kind":"read","status":"completed","rawOutput":[{"path":"a"},{"path":"b"}],"_meta":{"claudeCode":{"toolName":"memory_recall"}}}`,
	}
	if got := p.toolUpdates(); !slices.Equal(got, want) {
		t.Errorf("got\n%s\nwant\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
	if u := p.of("usage_update"); len(u) == 0 || u[0].UsageUpdate.Used != 80 {
		t.Errorf("%+v", u)
	}
}

// Claude's word that a compaction succeeded may come before its boundary,
// and twice: the boundary then adds its facts to the same call, and the
// second word is ignored.
func TestCompactionOutcomeFirst(t *testing.T) {
	success := sendf(`{"type":"system","subtype":"status","status":null,"compact_result":"success"}`)
	f := fake(user("id2"),
		sendf(`{"type":"system","subtype":"status","status":"compacting","uuid":"c1"}`),
		success,
		sendf(`{"type":"system","subtype":"compact_boundary","uuid":"b1","compact_metadata":{"trigger":"auto","pre_tokens":900,"post_tokens":80,"duration_ms":1200}}`),
		success,
		result(""), claudetest.Send(idle))
	p := start(t, nil, f)
	if got := stopReason(p.prompt(t, p.open(t), "/compact")); got != "end_turn" {
		t.Fatal(got)
	}
	want := []string{
		`tool_call {"toolCallId":"c1","title":"Compact conversation","name":"compact","kind":"think","status":"in_progress","_meta":{"claudeCode":{"toolName":"compact"}}}`,
		`tool_call_update {"toolCallId":"c1","status":"completed","_meta":{"claudeCode":{"toolName":"compact"}}}`,
		`tool_call_update {"toolCallId":"c1","rawOutput":{"trigger":"auto","preTokens":900,"postTokens":80,"durationMs":1200},"_meta":{"claudeCode":{"toolName":"compact"}}}`,
	}
	if got := p.toolUpdates(); !slices.Equal(got, want) {
		t.Errorf("got\n%s\nwant\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
}

// /context's output comes twice, as claude's printed output and as its
// result's text: clients read the last.
func TestLocalCommand(t *testing.T) {
	f := fake(user("id2"),
		sendf(`{"type":"system","subtype":"local_command_output","uuid":"o1","content":"## Context Usage"}`),
		claudetest.Send(`{"type":"result","subtype":"success","uuid":"r1","result":"## Context Usage","total_cost_usd":0}`),
		claudetest.Send(idle))
	p := start(t, nil, f)
	if got := stopReason(p.prompt(t, p.open(t), "/context")); got != "end_turn" {
		t.Fatal(got)
	}
	if got := p.texts(); !slices.Equal(got, []string{"text:o1:## Context Usage", "text:r1:## Context Usage"}) {
		t.Errorf("%q", got)
	}
}

// A refused turn says why and stops refused; one claude couldn't run
// signed out fails asking for a sign-in, without claude's stand-in text.
func TestRefusalAndSignIn(t *testing.T) {
	f := fake(user("id2"), echo("id2"),
		event(`{"type":"message_start","message":{"id":"msg_1","model":"m"}}`),
		event(`{"type":"message_delta","delta":{"stop_reason":"refusal","stop_details":{"type":"refusal","explanation":"Not that."}}}`),
		result(names("id2")+`,"stop_reason":"refusal"`), claudetest.Send(idle),
		user("id3"), echo("id3"),
		claudetest.Send(`{"type":"assistant","message":{"id":"x","model":"<synthetic>","content":[{"type":"text","text":"Not logged in · Please run /login"}]}}`),
		claudetest.Send(`{"type":"result","subtype":"success","is_error":true,"result":"Not logged in · Please run /login","user_message_uuids":["id3"]}`),
		claudetest.Send(idle))
	p := start(t, nil, f)
	sid := p.open(t)
	if got := stopReason(p.prompt(t, sid, "a")); got != "refusal" {
		t.Error(got)
	}
	_, err := p.prompt(t, sid, "b")()
	if e, ok := errors.AsType[*acp.Error](err); !ok || e.Code != acp.ErrorCodeAuthenticationRequired {
		t.Errorf("%v", err)
	}
	if got := p.texts(); !slices.Equal(got, []string{"text::Not that."}) {
		t.Errorf("%q", got)
	}
}

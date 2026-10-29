package claudeacp

import (
	"errors"
	"testing"

	"github.com/afrase/acp-go/steering"
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

func steerText(text string) []acp.ContentBlock {
	return []acp.ContentBlock{{Text: &acp.TextContent{Text: text}}}
}

// A steer joins the running turn as a message claude takes now (later
// while a permission or question is open); the turn then ends at a
// result naming it, or at the idle after its own result.
func TestSteer(t *testing.T) {
	for _, tc := range []struct {
		name     string
		asks     int
		priority string
		end      []claudetest.Step
		input    uint64 // the answer's input tokens: the results it counted
	}{
		{"named", 0, "now", []claudetest.Step{result(names("id2")), result(names("id3"))}, 6},
		{"idle", 0, "now", []claudetest.Step{result(names("id2")), claudetest.Send(idle)}, 3},
		{"later", 1, "later", []claudetest.Step{result(names("id2", "id3"))}, 3},
	} {
		t.Run(tc.name, func(t *testing.T) {
			taken := make(chan struct{})
			steps := []claudetest.Step{user("id2"), echo("id2"), signal(taken),
				claudetest.Expect(`{"type":"user","uuid":"id3","priority":"` + tc.priority + `","message":{"content":[{"type":"text","text":"also"}]}}`)}
			p := start(t, nil, fake(append(steps, tc.end...)...))
			sid := p.open(t)
			w := p.prompt(t, sid, "hi")
			wait(t, taken, "the prompt taken")
			eventually(t, "the prompt running", func() bool { _, a := p.queue(t, sid); return a == "id2" })
			s, _ := p.agent.session(sid)
			s.mu.Lock()
			s.asks = tc.asks
			s.mu.Unlock()
			outcome, err := steering.Steer(t.Context(), p.AgentConn, string(sid), steerText("also"))
			if err != nil || outcome != steering.Injected {
				t.Fatalf("%s %v", outcome, err)
			}
			r, err := w()
			if err != nil || r.StopReason != acp.StopReasonEndTurn || r.Usage.InputTokens != tc.input {
				t.Errorf("%+v %v", r, err)
			}
		})
	}
}

// With no turn, a steer asking for promptRequired does nothing; one that
// doesn't starts a turn. A steer with no prompt, or another idle
// behaviour, is refused.
func TestSteerIdle(t *testing.T) {
	f := fake(claudetest.Expect(`{"type":"user","uuid":"id2","message":{"content":[{"type":"text","text":"go"}]}}`),
		echo("id2"), result(names("id2")))
	p := start(t, nil, f)
	sid := p.open(t)
	var resp steering.Response
	if err := p.Call(t.Context(), steering.Method, steering.Request[acp.ContentBlock]{SessionID: string(sid), Prompt: steerText("wait"),
		Meta: map[string]any{"steering": map[string]any{"idleBehavior": "promptRequired"}}}, &resp); err != nil ||
		resp != (steering.Response{Outcome: steering.PromptRequired, Reason: "noRunningTurn"}) {
		t.Fatalf("%+v %v", resp, err)
	}
	if err := p.Call(t.Context(), steering.Method, steering.Request[acp.ContentBlock]{SessionID: string(sid), Prompt: steerText("go")}, &resp); err != nil ||
		resp.Outcome != steering.StartedNewTurn {
		t.Fatalf("%+v %v", resp, err)
	}
	<-f.Played()
	eventually(t, "the started turn answered", func() bool { ids, _ := p.queue(t, sid); return len(ids) == 0 })
	for _, req := range []steering.Request[acp.ContentBlock]{
		{SessionID: string(sid)},
		{SessionID: string(sid), Prompt: steerText("x"), Meta: map[string]any{"steering": map[string]any{"idleBehavior": "queue"}}},
	} {
		err := p.Call(t.Context(), steering.Method, req, &resp)
		if e, ok := errors.AsType[*acp.Error](err); !ok || e.Code != acp.ErrorCodeInvalidParams {
			t.Errorf("%+v: %v", req, err)
		}
	}
}

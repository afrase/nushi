package claudeacp

import (
	"testing"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// A slash command claude answers itself has no echo, and its result no
// origin, which is then a person's.
func TestResultText(t *testing.T) {
	f := fake(user("id2"), claudetest.Send(`{"type":"result","subtype":"success","uuid":"r1","result":"Context: 5%","total_cost_usd":0}`), claudetest.Send(idle))
	p := start(t, nil, f)
	sid := p.open(t)
	if got := stopReason(p.prompt(t, sid, "/context")); got != "end_turn" {
		t.Fatal(got)
	}
	if u := p.of("usage_update"); len(u) != 1 || u[0].UsageUpdate.Meta["_claude/origin"].(map[string]any)["kind"].(string) != "human" {
		t.Errorf("%+v", u)
	}
}

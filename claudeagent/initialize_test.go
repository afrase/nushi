package claudeagent

import (
	"encoding/json"
	"strings"
	"testing"
)

// Only what is set goes in initialize; Extra adds fields, but none Init
// names or the package sets.
func TestInitRequest(t *testing.T) {
	for _, tc := range []struct {
		name string
		init Init
		want string
	}{
		{"none", Init{}, `{}`},
		{"all", Init{
			SystemPrompt: "be brief", AppendSystemPrompt: "and kind", PerTaskStopAffordance: true, ForwardSubagentText: true, Title: "T",
			Agents: map[string]AgentDefinition{"rev": {Description: "d", Prompt: "p", Tools: []string{"Read"}}},
			Extra:  map[string]any{"workspaceTrust": true},
		}, `{"agents":{"rev":{"description":"d","prompt":"p","tools":["Read"]}},"appendSystemPrompt":"and kind","forwardSubagentText":true,"perTaskStopAffordance":true,"systemPrompt":["be brief"],"title":"T","workspaceTrust":true}`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			r, err := initRequest(tc.init)
			if err != nil {
				t.Fatal(err)
			}
			if b, _ := json.Marshal(r); string(b) != tc.want {
				t.Errorf("%s", b)
			}
		})
	}
	for _, k := range []string{"subtype", "title", "systemPrompt", "hooks"} {
		if _, err := initRequest(Init{Extra: map[string]any{k: 1}}); err == nil || !strings.Contains(err.Error(), k) {
			t.Errorf("%s: %v", k, err)
		}
	}
}

// The answer decodes what's modelled, keeps the rest in Raw, and a field
// an older claude doesn't send is zero.
func TestInitResponse(t *testing.T) {
	raw := `{"commands":[{"name":"compact","description":"Compact","argumentHint":"<how>"}],"agents":[{"name":"rev","description":"d"}],` +
		`"models":[{"value":"opus","displayName":"Opus","supportsEffort":true,"supportedEffortLevels":["low","high"],"supportsFastMode":true}],` +
		`"current_model":"opus","current_permission_mode":"default","account":{"subscriptionType":"max"},"pid":42,"capabilities":["interrupt_receipt_v1"],"unknown":1}`
	var r InitResponse
	if err := json.Unmarshal([]byte(raw), &r); err != nil {
		t.Fatal(err)
	}
	if r.Commands[0].ArgumentHint != "<how>" || r.Agents[0].Name != "rev" || !r.Models[0].SupportsFastMode || r.Models[0].SupportedEffortLevels[1] != "high" ||
		r.CurrentModel != "opus" || r.CurrentPermissionMode != "default" || r.Account.SubscriptionType != "max" || r.PID != 42 ||
		r.Capabilities[0] != "interrupt_receipt_v1" || string(r.Raw) != raw || r.FastModeState != "" {
		t.Errorf("%+v", r)
	}
}

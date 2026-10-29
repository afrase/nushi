package claudeacp

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"slices"
	"strings"
	"testing"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent/claudetest"
)

// initAnswer is claude's answer to initialize, as 2.1.312's schema shapes
// it: three models (the default has effort and fast mode), a built-in and
// a custom agent, and the session in Accept edits on the default model.
var initAnswer = oneLine(`{"models":[
	{"value":"default","displayName":"Default (recommended)","description":"Opus 5.5","resolvedModel":"claude-opus-5-5",
	 "supportsEffort":true,"supportedEffortLevels":["low","medium","high"],"supportsFastMode":true,"supportsAutoMode":true},
	{"value":"sonnet","displayName":"Sonnet 5.5","resolvedModel":"claude-sonnet-5-5","supportsEffort":true,"supportedEffortLevels":["low","high"]},
	{"value":"haiku","displayName":"Haiku 5.5"}],
	"agents":[{"name":"general-purpose"},{"name":"reviewer","description":"Reviews"}],
	"current_model":"claude-opus-5-5","current_permission_mode":"acceptEdits"}`)

// summary is options as id/category=current[values]; a boolean one as
// id/category=current.
func summary(opts []acp.SessionConfigOption) string {
	var parts []string
	for _, o := range opts {
		head := string(o.ID) + "/" + string(o.Category)
		switch {
		case o.Select != nil:
			var vs []string
			for _, v := range o.Select.Options.Ungrouped {
				vs = append(vs, string(v.Value))
			}
			parts = append(parts, fmt.Sprintf("%s=%s[%s]", head, o.Select.CurrentValue, strings.Join(vs, " ")))
		case o.Boolean != nil:
			parts = append(parts, fmt.Sprintf("%s=%t", head, o.Boolean.CurrentValue))
		}
	}
	return strings.Join(parts, " ")
}

// openWith opens a session in a temp folder with _meta.claudeCode.options.
func (p *peer) openWith(t *testing.T, options map[string]any) *acp.NewSessionResponse {
	t.Helper()
	r, err := p.NewSession(context.Background(), &acp.NewSessionRequest{Cwd: t.TempDir(), MCPServers: []acp.MCPServer{},
		Meta: map[string]any{"claudeCode": map[string]any{"options": options}}})
	if err != nil {
		t.Fatal(err)
	}
	return r
}

const allModes = "default acceptEdits plan auto bypassPermissions"

// A session offers the modes and the options claude's answer to
// initialize has: effort and fast mode only for a model that has them,
// the agent only with custom agents. What it says is current wins over
// what the session asked for, which wins over the defaults.
func TestConfigOptions(t *testing.T) {
	booleans := &acp.ClientCapabilities{Session: &acp.ClientSessionCapabilities{
		ConfigOptions: &acp.SessionConfigOptionsCapabilities{Boolean: &acp.BooleanConfigOptionCapabilities{}}}}
	for _, tc := range []struct {
		name    string
		init    string
		caps    *acp.ClientCapabilities
		options map[string]any
		mode    string
		want    string
	}{
		{"claude's answer", initAnswer, nil, nil, "acceptEdits",
			"mode/mode=acceptEdits[" + allModes + "] model/model=default[default sonnet haiku] effort/thought_level=default[default low medium high] " +
				"fast/model_config=off[on off] agent/=default[default reviewer]"},
		{"boolean options", initAnswer, booleans, nil, "acceptEdits",
			"mode/mode=acceptEdits[" + allModes + "] model/model=default[default sonnet haiku] effort/thought_level=default[default low medium high] " +
				"fast/model_config=false agent/=default[default reviewer]"},
		{"the session's settings", strings.Replace(initAnswer, `"claude-opus-5-5"`+`,"current_permission_mode"`, `"claude-sonnet-5-5","current_permission_mode"`, 1), nil,
			map[string]any{"settings": map[string]any{"effortLevel": "high", "agent": "reviewer", "fastMode": true}}, "acceptEdits",
			"mode/mode=acceptEdits[" + allModes + "] model/model=sonnet[default sonnet haiku] effort/thought_level=high[default low high] agent/=reviewer[default reviewer]"},
		{"the session's model and mode", strings.Replace(strings.Replace(initAnswer, `"current_model":"claude-opus-5-5",`, "", 1), `,"current_permission_mode":"acceptEdits"`, "", 1), nil,
			map[string]any{"model": "haiku", "permissionMode": "plan", "settings": map[string]any{"effortLevel": "medium"}}, "plan",
			"mode/mode=plan[" + allModes + "] model/model=haiku[default sonnet haiku] agent/=default[default reviewer]"},
		{"nothing said", `{}`, nil, nil, "default", "mode/mode=default[" + allModes + "]"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			p := start(t, tc.caps, started(tc.init, `null`))
			r := p.openWith(t, tc.options)
			if got := summary(r.ConfigOptions); got != tc.want {
				t.Errorf("options\n%s\nwant\n%s", got, tc.want)
			}
			var ids []string
			for _, m := range r.Modes.AvailableModes {
				ids = append(ids, string(m.ID))
			}
			if string(r.Modes.CurrentModeID) != tc.mode || strings.Join(ids, " ") != allModes {
				t.Errorf("modes %s %q", r.Modes.CurrentModeID, ids)
			}
		})
	}
}

// The client follows claude's own changes: the model, mode and fast mode
// a turn starts with, a mode change claude reports, and fast mode turned
// off, with why.
func TestConfigFollowsClaude(t *testing.T) {
	read := make(chan struct{})
	f := started(initAnswer, `null`, user("id2"), echo("id2"),
		claudetest.Send(`{"type":"system","subtype":"init","model":"claude-sonnet-5-5","permissionMode":"plan","fast_mode_state":"on"}`),
		claudetest.Send(`{"type":"system","subtype":"status","status":null,"permissionMode":"default"}`),
		result(`"fast_mode_state":"off","fast_mode_disabled_reason":"rate limited"`), claudetest.Send(idle), signal(read))
	p := start(t, nil, f)
	if got := stopReason(p.prompt(t, p.open(t), "go")); got != "end_turn" {
		t.Fatal(got)
	}
	wait(t, read, "the script")
	var modes []string
	for _, u := range p.of("current_mode_update") {
		modes = append(modes, string(u.CurrentModeUpdate.CurrentModeID))
	}
	if !slices.Equal(modes, []string{"plan", "default"}) {
		t.Errorf("modes %q", modes)
	}
	var opts []string
	for _, u := range p.of("config_option_update") {
		opts = append(opts, summary(u.ConfigOptionUpdate.ConfigOptions[1:2]))
	}
	if want := []string{"model/model=default[default sonnet haiku]", "model/model=sonnet[default sonnet haiku]", "model/model=sonnet[default sonnet haiku]", "model/model=sonnet[default sonnet haiku]"}; !slices.Equal(opts, want) {
		t.Errorf("options %q", opts)
	}
	if got := p.texts(); !slices.Equal(got, []string{"text::**Fast mode turned off:** rate limited"}) {
		t.Errorf("%q", got)
	}
}

// oneLine is JSON on one line, as claude writes it.
func oneLine(s string) string {
	var b bytes.Buffer
	if err := json.Compact(&b, []byte(s)); err != nil {
		panic(err)
	}
	return b.String()
}

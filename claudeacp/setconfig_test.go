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

// requests are the bodies of the control requests f answered of its own,
// but for asks for a title, as {subtype…} JSON with their keys sorted.
func requests(t *testing.T, f *claudetest.Fake) []string {
	t.Helper()
	var out []string
	for _, l := range asked(f) {
		var frame struct {
			Request map[string]any `json:"request"`
		}
		if err := json.Unmarshal([]byte(l), &frame); err != nil {
			t.Fatal(err)
		}
		b, _ := json.Marshal(frame.Request)
		out = append(out, string(b))
	}
	return out
}

// setter is a fake claude that takes every change of mode, model and
// settings.
func setter(init string) *claudetest.Fake {
	ok := `{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`
	f := started(init, `null`)
	f.Respond(`{"type":"control_request","request":{"subtype":"set_permission_mode"}}`, ok)
	f.Respond(`{"type":"control_request","request":{"subtype":"set_model"}}`, ok)
	f.Respond(`{"type":"control_request","request":{"subtype":"apply_flag_settings"}}`, ok)
	return f
}

// Each option is set with claude's control request for it; the answer
// is the whole set. An effort change keeps ultracode on when the
// session's settings turned it on; a model without the effort picked
// puts it back to the default. The current value asks claude nothing.
func TestSetConfigOption(t *testing.T) {
	for _, tc := range []struct {
		name     string
		settings map[string]any
		id       string
		value    any // a string, or a bool for a boolean option
		requests []string
		want     string // the options after, but for the mode's
	}{
		{"mode", nil, "mode", "plan", []string{`{"mode":"plan","subtype":"set_permission_mode"}`},
			"model/model=default[default sonnet haiku] effort/thought_level=default[default low medium high] fast/model_config=off[on off] agent/=default[default reviewer]"},
		{"model", map[string]any{"effortLevel": "medium"}, "model", "sonnet",
			[]string{`{"model":"sonnet","subtype":"set_model"}`, `{"settings":{"effortLevel":null},"subtype":"apply_flag_settings"}`},
			"model/model=sonnet[default sonnet haiku] effort/thought_level=default[default low high] agent/=default[default reviewer]"},
		{"model by its id", map[string]any{"effortLevel": "low"}, "model", "claude-sonnet-5-5", []string{`{"model":"sonnet","subtype":"set_model"}`},
			"model/model=sonnet[default sonnet haiku] effort/thought_level=low[default low high] agent/=default[default reviewer]"},
		{"effort", nil, "effort", "high", []string{`{"settings":{"effortLevel":"high"},"subtype":"apply_flag_settings"}`},
			"model/model=default[default sonnet haiku] effort/thought_level=high[default low medium high] fast/model_config=off[on off] agent/=default[default reviewer]"},
		{"effort with ultracode", map[string]any{"ultracode": true, "effortLevel": "high"}, "effort", "default",
			[]string{`{"settings":{"effortLevel":null,"ultracode":true},"subtype":"apply_flag_settings"}`},
			"model/model=default[default sonnet haiku] effort/thought_level=default[default low medium high] fast/model_config=off[on off] agent/=default[default reviewer]"},
		{"fast", nil, "fast", "on", []string{`{"settings":{"fastMode":true},"subtype":"apply_flag_settings"}`},
			"model/model=default[default sonnet haiku] effort/thought_level=default[default low medium high] fast/model_config=on[on off] agent/=default[default reviewer]"},
		{"fast as a boolean", map[string]any{"fastMode": true}, "fast", false, []string{`{"settings":{"fastMode":false},"subtype":"apply_flag_settings"}`},
			"model/model=default[default sonnet haiku] effort/thought_level=default[default low medium high] fast/model_config=off[on off] agent/=default[default reviewer]"},
		{"agent", nil, "agent", "reviewer", []string{`{"settings":{"agent":"reviewer"},"subtype":"apply_flag_settings"}`},
			"model/model=default[default sonnet haiku] effort/thought_level=default[default low medium high] fast/model_config=off[on off] agent/=reviewer[default reviewer]"},
		{"the current value", map[string]any{"agent": "reviewer"}, "agent", "reviewer", nil,
			"model/model=default[default sonnet haiku] effort/thought_level=default[default low medium high] fast/model_config=off[on off] agent/=reviewer[default reviewer]"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := setter(initAnswer)
			p := start(t, nil, f)
			sid := p.openWith(t, map[string]any{"settings": tc.settings}).SessionID
			req := &acp.SetSessionConfigOptionRequest{SessionID: sid, ConfigID: acp.SessionConfigID(tc.id)}
			switch v := tc.value.(type) {
			case bool:
				req.Boolean = &acp.SetSessionConfigOptionRequestBoolean{Value: v}
			case string:
				req.ValueID = &acp.SetSessionConfigOptionRequestValueID{Value: acp.SessionConfigValueID(v)}
			}
			r, err := p.SetSessionConfigOption(t.Context(), req)
			if err != nil {
				t.Fatal(err)
			}
			if got := requests(t, f); !slices.Equal(got, tc.requests) {
				t.Errorf("requests %q", got)
			}
			if got := summary(r.ConfigOptions[1:]); got != tc.want {
				t.Errorf("options\n%s\nwant\n%s", got, tc.want)
			}
		})
	}
}

// Options and values the session doesn't offer are refused, asking
// claude nothing.
func TestSetConfigOptionRefused(t *testing.T) {
	f := setter(strings.Replace(initAnswer, `"claude-opus-5-5","current_permission_mode"`, `"haiku","current_permission_mode"`, 1))
	p := start(t, nil, f)
	sid := p.open(t)
	for _, tc := range [][2]string{{"effort", "high"}, {"fast", "on"}, {"model", "gpt"}, {"agent", "nobody"}, {"mode", "dontAsk"}, {"colour", "red"}} {
		_, err := p.SetSessionConfigOption(t.Context(), &acp.SetSessionConfigOptionRequest{SessionID: sid, ConfigID: acp.SessionConfigID(tc[0]),
			ValueID: &acp.SetSessionConfigOptionRequestValueID{Value: acp.SessionConfigValueID(tc[1])}})
		if ae := (*acp.Error)(nil); !errors.As(err, &ae) || ae.Code != acp.ErrorCodeInvalidParams {
			t.Errorf("%s=%s: %v", tc[0], tc[1], err)
		}
	}
	if got := requests(t, f); len(got) != 0 {
		t.Errorf("requests %q", got)
	}
}

// session/set_mode switches claude's mode and tells the client of it and
// of the options. A claude that won't bypass permissions has the mode
// refused, and no longer offered.
func TestSetMode(t *testing.T) {
	refuse := `{"type":"control_response","response":{"subtype":"error","request_id":"$req","error":"bypass is off","error_code":"bypass_disabled"}}`
	ok := `{"type":"control_response","response":{"subtype":"success","request_id":"$req","response":{}}}`
	f := started(initAnswer, `null`)
	f.Respond(`{"type":"control_request","request":{"subtype":"set_permission_mode","mode":"bypassPermissions"}}`, refuse)
	f.Respond(`{"type":"control_request","request":{"subtype":"set_permission_mode"}}`, ok)
	p := start(t, nil, f)
	sid := p.open(t)
	if _, err := p.SetSessionMode(t.Context(), &acp.SetSessionModeRequest{SessionID: sid, ModeID: "plan"}); err != nil {
		t.Fatal(err)
	}
	if ms := p.of("current_mode_update"); len(ms) != 1 || ms[0].CurrentModeUpdate.CurrentModeID != "plan" {
		t.Errorf("%+v", ms)
	}
	if os := p.of("config_option_update"); len(os) != 1 || !strings.HasPrefix(summary(os[0].ConfigOptionUpdate.ConfigOptions), "mode/mode=plan[") {
		t.Errorf("%+v", os)
	}
	if _, err := p.SetSessionMode(t.Context(), &acp.SetSessionModeRequest{SessionID: sid, ModeID: "bypassPermissions"}); err == nil {
		t.Fatal("bypassed")
	}
	os := p.of("config_option_update")
	if got := summary(os[len(os)-1].ConfigOptionUpdate.ConfigOptions); !strings.HasPrefix(got, "mode/mode=plan[default acceptEdits plan auto]") {
		t.Errorf("%s", got)
	}
	if got := requests(t, f); !slices.Equal(got, []string{`{"mode":"plan","subtype":"set_permission_mode"}`, `{"mode":"bypassPermissions","subtype":"set_permission_mode"}`}) {
		t.Errorf("%q", got)
	}
}

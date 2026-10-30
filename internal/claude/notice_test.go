package claude

import (
	"testing"

	"github.com/afrase/nushi/internal/model"
)

// The adapter's informational notices, as it sends them to a client
// without ACP's notices: the label goes; anything else is the model's.
func TestNotice(t *testing.T) {
	meta := func(level string) map[string]any {
		return map[string]any{"claudeCode": map[string]any{"kind": "informational", "level": level}}
	}
	for _, c := range []struct {
		meta map[string]any
		text string
		want model.AgentNotice
		ok   bool
	}{
		{meta("notice"), "**Notice:** Opus 5.5's safeguards stopped the response above · continuing once with that noted",
			model.AgentNotice{Text: "Opus 5.5's safeguards stopped the response above · continuing once with that noted", Stopped: true}, true},
		{meta("warning"), "**Warning:** Stop hook blocked: tests fail", model.AgentNotice{Text: "Stop hook blocked: tests fail", Warning: true}, true},
		{meta("info"), "**Info:** stays as sent", model.AgentNotice{Text: "**Info:** stays as sent"}, true},
		{nil, "**Notice:** Opus 5.5's safeguards stopped the response above", model.AgentNotice{}, false},
		{map[string]any{"claudeCode": map[string]any{"parentToolUseId": "t1"}}, "text", model.AgentNotice{}, false},
	} {
		got, ok := Notice(c.meta, c.text)
		if got != c.want || ok != c.ok {
			t.Errorf("Notice(%v, %q) = %+v, %v; want %+v, %v", c.meta, c.text, got, ok, c.want, c.ok)
		}
	}
}

// Claude's marks of a stopped turn, and only those: a user who writes
// about one still wrote it.
func TestInterrupted(t *testing.T) {
	for text, want := range map[string]bool{
		"[Request interrupted by user]":                  true,
		"[Request interrupted by user for tool use]":     true,
		"Why did you say [Request interrupted by user]?": false,
		"Go on": false,
	} {
		if got := Interrupted(text); got != want {
			t.Errorf("Interrupted(%q) = %v", text, got)
		}
	}
}

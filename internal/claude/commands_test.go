package claude

import "testing"

// /plan is read as the terminal reads it: the command, then its
// description; open and share are the terminal's own words, not one.
func TestPlanIsReadAsTheTerminalReadsIt(t *testing.T) {
	for text, want := range map[string]string{
		"/plan":                  "",
		" /plan open ":           "",
		"/plan share":            "",
		"/plan open the file":    "open the file",
		"/plan\tfix it\n  today": "fix it\n  today",
	} {
		cmd, ok := Harness{}.TerminalCommand(text)
		if !ok || cmd.Prompt != want || cmd.Category != "mode" || cmd.Value != "plan" {
			t.Errorf("%q: %+v %v, want the prompt %q", text, cmd, ok, want)
		}
	}
	for _, text := range []string{"/planner", "plan", "say /plan", "/Plan", ""} {
		if _, ok := (Harness{}).TerminalCommand(text); ok {
			t.Errorf("%q read as /plan", text)
		}
	}
}

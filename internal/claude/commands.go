package claude

import (
	"strings"
	"unicode"

	"github.com/afrase/nushi/internal/model"
)

// planCommand is Claude Code's /plan as Nushi runs it: claude refuses it
// headless ("/plan isn't available in this environment."), and neither
// claude-agent-acp nor the Go agent lists it (docs/facts/claude.md, ADR 0088).
var planCommand = model.Command{Name: "plan", Description: "Switch to plan mode; with a description, start planning it", Hint: "[description]"}

// TerminalCommands are the commands of Claude's terminal that Nushi runs in
// its place: /plan.
func (Harness) TerminalCommands() []model.Command { return []model.Command{planCommand} }

// TerminalCommand reads /plan as the terminal runs it: it switches the
// mode to plan and says "Enabled plan mode"; a description after it is
// then sent as the prompt, except "open" and "share" (which open or share
// the plan in the terminal). Already in plan mode the description goes
// alone; with none it says so ("Already in plan mode."). The terminal
// drops the description there; Nushi doesn't (ADR 0088).
func (h Harness) TerminalCommand(text string) (model.OptionCommand, bool) {
	text = strings.TrimSpace(text)
	name, rest := text, ""
	if i := strings.IndexFunc(text, unicode.IsSpace); i >= 0 {
		name, rest = text[:i], strings.TrimSpace(text[i:])
	}
	if name != "/"+planCommand.Name {
		return model.OptionCommand{}, false
	}
	if rest == "open" || rest == "share" {
		rest = ""
	}
	return model.OptionCommand{Category: "mode", Value: h.ReadOnlyMode(), Prompt: rest,
		Set: "Enabled plan mode", Already: "Already in plan mode."}, true
}

package claude

import (
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// Notice reads a message chunk the adapter marks as a notice of Claude
// Code's own, not the model's words: `_meta.claudeCode.kind`
// "informational", sent as agent text to a client without ACP's notices
// (docs/facts/claude.md), its level as a bold label ("**Notice:** …",
// none for "info"). The text loses the label. Stopped says it is the
// notice that Claude's safeguards stopped the response before it and
// Claude goes on once: the stopped part, if any streamed, is the message
// just before.
func Notice(meta map[string]any, text string) (model.AgentNotice, bool) {
	if claudeCode(meta, "kind") != "informational" {
		return model.AgentNotice{}, false
	}
	level := claudeCode(meta, "level")
	if level != "" && level != "info" {
		text = strings.TrimPrefix(text, "**"+strings.ToUpper(level[:1])+level[1:]+":** ")
	}
	return model.AgentNotice{
		Text:    text,
		Warning: level == "warning",
		Stopped: strings.Contains(text, "'s safeguards stopped the response above"),
	}, true
}

package chats

import (
	"bytes"
	"encoding/json"
	"strings"
	"unicode/utf8"

	"github.com/afrase/nushi/internal/model"
)

// rawCap is how much of a tool call's raw input or output an item keeps.
const rawCap = 8 << 10

// keepRaw keeps what the agent gave of a tool call beyond its content: its
// input (rawInput) as indented JSON unless the call has diffs, and its result (rawOutput) as text or
// indented JSON, but only while the content shows nothing (no text, diff or
// image) and the call isn't a command (whose output comes in the dialect's
// _meta). An update without them leaves them as they were.
func keepRaw(it *model.Item, input, output json.RawMessage) {
	if s := inputText(input); s != "" {
		it.Input = s
	}
	if s := outputText(output); s != "" {
		it.RawOutput = s
	}
	if strings.TrimSpace(it.Text) != "" || len(it.Diffs) > 0 || len(it.Images) > 0 || it.ToolKind == "execute" {
		it.RawOutput = ""
	}
	if len(it.Diffs) > 0 { // an edit's input is the file's text again
		it.Input = ""
	}
}

// inputText is a tool call's input as indented JSON; "" when it holds
// nothing ({}, null).
func inputText(raw json.RawMessage) string {
	raw = bytes.TrimSpace(raw)
	if empty(raw) {
		return ""
	}
	var b bytes.Buffer
	if json.Indent(&b, raw, "", "  ") != nil {
		return cut(string(raw))
	}
	return cut(b.String())
}

// outputText is a tool call's raw result: a string as it is, a list of text
// blocks (Claude's tool_result content) as their text, else indented JSON.
func outputText(raw json.RawMessage) string {
	raw = bytes.TrimSpace(raw)
	if empty(raw) {
		return ""
	}
	var s string
	if json.Unmarshal(raw, &s) == nil {
		return cut(strings.TrimSpace(s))
	}
	var blocks []struct {
		Type string  `json:"type"`
		Text *string `json:"text"`
	}
	if json.Unmarshal(raw, &blocks) == nil && len(blocks) > 0 {
		texts := make([]string, 0, len(blocks))
		for _, b := range blocks {
			if b.Type != "text" || b.Text == nil {
				texts = nil
				break
			}
			texts = append(texts, *b.Text)
		}
		if texts != nil {
			return cut(strings.TrimSpace(strings.Join(texts, "\n\n")))
		}
	}
	return inputText(raw)
}

func empty(raw json.RawMessage) bool {
	switch string(raw) {
	case "", "null", "{}", "[]", `""`:
		return true
	}
	return false
}

// cut cuts s to rawCap bytes, on a character's boundary, marking the cut.
func cut(s string) string {
	if len(s) <= rawCap {
		return s
	}
	i := rawCap
	for i > 0 && !utf8.RuneStart(s[i]) {
		i--
	}
	return s[:i] + "\n…"
}

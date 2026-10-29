// Ported from the Claude Agent SDK for Python (commit 27858cbb,
// src/claude_agent_sdk/_internal/sessions.py), MIT License,
// Copyright (c) 2025 Anthropic, PBC: see ../NOTICE.

package sessions

import (
	"encoding/json"
	"regexp"
	"strings"
	"unicode"
)

// firstString finds the first "key":"value" in text, a piece of JSONL that
// may be cut anywhere, without parsing it; "" when there is none.
func firstString(text, key string) string {
	for _, pattern := range []string{`"` + key + `":"`, `"` + key + `": "`} {
		if i := strings.Index(text, pattern); i >= 0 {
			if v, _, ok := stringAt(text, i+len(pattern)); ok {
				return v
			}
		}
	}
	return ""
}

// lastString is firstString's last match: a record written later wins.
func lastString(text, key string) string {
	last, at := "", -1
	for _, pattern := range []string{`"` + key + `":"`, `"` + key + `": "`} {
		for from := 0; ; {
			i := strings.Index(text[from:], pattern)
			if i < 0 {
				break
			}
			start := from + i + len(pattern)
			v, end, ok := stringAt(text, start)
			if !ok {
				break
			}
			if start > at {
				last, at = v, start
			}
			from = end + 1
		}
	}
	return last
}

// stringAt reads the JSON string whose text starts at text[start], up to
// its closing quote at end; false when text ends first.
func stringAt(text string, start int) (value string, end int, ok bool) {
	for i := start; i < len(text); i++ {
		switch text[i] {
		case '\\':
			i++
		case '"':
			raw := text[start:i]
			if !strings.Contains(raw, `\`) {
				return raw, i, true
			}
			if err := json.Unmarshal([]byte(`"`+raw+`"`), &value); err != nil {
				return raw, i, true
			}
			return value, i, true
		}
	}
	return "", 0, false
}

var (
	commandName = regexp.MustCompile(`<command-name>(.*?)</command-name>`)
	// Messages the CLI or an IDE wrote in the user's place.
	notAPrompt = regexp.MustCompile(`^(?:<local-command-stdout>|<session-start-hook>|<tick>|<goal>|` +
		`\[Request interrupted by user[^\]]*\]|` +
		`\s*<ide_opened_file>[\s\S]*</ide_opened_file>\s*$|` +
		`\s*<ide_selection>[\s\S]*</ide_selection>\s*$)`)
)

// firstPrompt finds the first thing the user typed in a transcript's start,
// on one line and cut to 200 characters. Tool results, meta records,
// compaction summaries and what the CLI wrote itself don't count; a slash
// command's name is the answer only when nothing else is.
func firstPrompt(head string) string {
	command := ""
	for line := range strings.SplitSeq(head, "\n") {
		if !strings.Contains(line, `"type":"user"`) && !strings.Contains(line, `"type": "user"`) ||
			strings.Contains(line, `"tool_result"`) ||
			strings.Contains(line, `"isMeta":true`) || strings.Contains(line, `"isMeta": true`) ||
			strings.Contains(line, `"isCompactSummary":true`) || strings.Contains(line, `"isCompactSummary": true`) {
			continue
		}
		var r struct {
			Type    any
			Message *struct{ Content json.RawMessage }
		}
		if json.Unmarshal([]byte(line), &r) != nil || r.Type != "user" || r.Message == nil {
			continue
		}
		for _, text := range texts(r.Message.Content) {
			text = strings.TrimSpace(strings.ReplaceAll(text, "\n", " "))
			if text == "" {
				continue
			}
			if m := commandName.FindStringSubmatch(text); m != nil {
				if command == "" {
					command = m[1]
				}
				continue
			}
			if notAPrompt.MatchString(text) {
				continue
			}
			if r := []rune(text); len(r) > 200 {
				text = strings.TrimRightFunc(string(r[:200]), unicode.IsSpace) + "…"
			}
			return text
		}
	}
	return command
}

// texts returns a message content's text: the string, or each text block's.
func texts(content json.RawMessage) []string {
	var s string
	if json.Unmarshal(content, &s) == nil {
		return []string{s}
	}
	var blocks []json.RawMessage
	if json.Unmarshal(content, &blocks) != nil {
		return nil
	}
	var out []string
	for _, raw := range blocks {
		var b struct {
			Type string
			Text *string
		}
		if json.Unmarshal(raw, &b) == nil && b.Type == "text" && b.Text != nil {
			out = append(out, *b.Text)
		}
	}
	return out
}

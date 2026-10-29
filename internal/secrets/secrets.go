// Package secrets masks what looks like a key or token in text: the shapes
// both the log (internal/logs) and tool calls' input (the chats feature)
// mask. Each keeps its own rule for NAME=value pairs: the log's is broad,
// and a tool call's input holds code, which that rule would mask.
package secrets

import (
	"regexp"
	"strings"
)

// shapes are what keys and tokens look like in any string: vendors'
// prefixes, AWS key ids, JWTs, PEM blocks, the values of bearer and basic
// credentials, and a password in a URL. A match's first group that isn't
// empty (what names the secret) is kept.
var shapes = regexp.MustCompile(strings.Join([]string{
	`()\bsk-[A-Za-z0-9_-]{16,}`,                                          // Anthropic (sk-ant-…), OpenAI (sk-proj-…)
	`()\bfw_[A-Za-z0-9]{16,}`,                                            // Fireworks
	`()\b(?:gh[pousr]_|github_pat_)\w{20,}`,                              // GitHub
	`()\bxox[abposr]-[A-Za-z0-9-]{10,}`,                                  // Slack
	`()\bAIza[0-9A-Za-z_-]{30,}`,                                         // Google
	`()\b(?:AKIA|ASIA)[0-9A-Z]{16}\b`,                                    // AWS key ids
	`()\beyJ[\w-]{8,}\.[\w-]{8,}\.[\w-]{8,}`,                             // JWTs
	`(-----BEGIN [A-Z0-9 ]+-----)[\s\S]*?(?:-----END [A-Z0-9 ]+-----|$)`, // PEM, to its end or the text's
	`((?i)\b(?:bearer|basic)\s+)[\w.~+/=-]{8,}`,
	`(://[^/\s:@]+:)[^/\s@]+@`, // a password in a URL
}, "|"))

// Mask replaces what looks like a secret in s with with: the shapes
// above, then what extra matches (nil: nothing more), whose first group
// is kept as theirs is ("NAME="). A URL keeps its user and its '@'.
func Mask(s, with string, extra *regexp.Regexp) string {
	s = replace(shapes, s, with)
	if extra != nil {
		s = replace(extra, s, with)
	}
	return s
}

// replace replaces each match of re in s with its first group that isn't
// empty and with.
func replace(re *regexp.Regexp, s, with string) string {
	matches := re.FindAllStringSubmatchIndex(s, -1)
	if matches == nil {
		return s
	}
	var b strings.Builder
	last := 0
	for _, m := range matches {
		b.WriteString(s[last:m[0]])
		keep := ""
		for i := 2; i+1 < len(m); i += 2 {
			if m[i] >= 0 && m[i+1] > m[i] {
				keep = s[m[i]:m[i+1]]
				break
			}
		}
		b.WriteString(keep)
		b.WriteString(with)
		if strings.HasPrefix(keep, "://") {
			b.WriteByte('@')
		}
		last = m[1]
	}
	b.WriteString(s[last:])
	return b.String()
}

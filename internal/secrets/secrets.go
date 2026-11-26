// Package secrets masks what looks like a key or token in text: the shapes
// both the log (internal/logs) and tool calls' input (MaskInput: a chat's
// transcript, a workflow agent's steps) mask. Each keeps its own rule for
// NAME=value pairs: the log's is broad, and a tool call's input holds
// code, which that rule would mask.
package secrets

import (
	"regexp"
	"strings"
)

// shapes are what keys and tokens look like in any string: vendors'
// prefixes (Anthropic, OpenAI, Fireworks, GitHub, Slack, Google and its
// OAuth clients', Stripe, GitLab, npm, Hugging Face, Twilio,
// DigitalOcean, SendGrid, Shopify), AWS key ids, JWTs, PEM
// blocks, the values of bearer and basic credentials, and a password in a
// URL. A match's first group that isn't empty (what names the secret) is
// kept.
var shapes = regexp.MustCompile(strings.Join([]string{
	`()\bsk-[A-Za-z0-9_-]{16,}`,                                          // Anthropic (sk-ant-…), OpenAI (sk-proj-…)
	`()\bfw_[A-Za-z0-9]{16,}`,                                            // Fireworks
	`()\b(?:gh[pousr]_|github_pat_)\w{20,}`,                              // GitHub
	`()\bxox[abposr]-[A-Za-z0-9-]{10,}`,                                  // Slack
	`()\bAIza[0-9A-Za-z_-]{30,}`,                                         // Google
	`()\b[sr]k_(?:live|test)_[A-Za-z0-9]{16,}`,                           // Stripe's secret and restricted keys
	`()\bglpat-[A-Za-z0-9_-]{20,}`,                                       // GitLab
	`()\bnpm_[A-Za-z0-9]{30,}`,                                           // npm
	`()\bhf_[A-Za-z0-9]{30,}`,                                            // Hugging Face
	`()\bSK[0-9a-fA-F]{32}\b`,                                            // Twilio's API keys
	`()\bGOCSPX-[A-Za-z0-9_-]{24,}`,                                      // Google's OAuth client secrets
	`()\bdop_v1_[0-9a-f]{64}\b`,                                          // DigitalOcean
	`()\bSG\.[\w-]{22}\.[\w-]{43}`,                                       // SendGrid
	`()\bshp(?:at|ss)_[0-9a-fA-F]{32}\b`,                                 // Shopify's access tokens and shared secrets
	`()\b(?:AKIA|ASIA)[0-9A-Z]{16}\b`,                                    // AWS key ids
	`()\beyJ[\w-]{8,}\.[\w-]{8,}\.[\w-]{8,}`,                             // JWTs
	`(-----BEGIN [A-Z0-9 ]+-----)[\s\S]*?(?:-----END [A-Z0-9 ]+-----|$)`, // PEM, to its end or the text's
	`((?i)\b(?:bearer|basic)\s+)[\w.~+/=-]{8,}`,
	`(://[^/\s:@]+:)[^/\s@]+@`, // a password in a URL
}, "|"))

// Names are NAME=value, NAME: value, "name": "value" or 'name': 'value'
// pairs (TOML's and a Node object dump's single quotes) whose name says
// secret, in a line of a program's output (an agent's stderr, a
// failed MCP server's), masked after the shapes: the log's rule
// (internal/logs), and the MCP page's, so the app is never sent more than
// the log shows. Broader than a tool call's input's rule: a line of
// output isn't code.
var Names = regexp.MustCompile(`((?i)\b[\w.-]*(?:key|token|secret|passw(?:or)?d|credential)[\w.-]*['"]?\s*[:=]\s*['"]?)[^\s"',;]{4,}`)

// plainName is a name that says secret but names something else: an
// error's (Python's KeyError: 'NAME'), a tokenizer, a key's path. Its
// value shows, as a count's does (countKey).
var plainName = regexp.MustCompile(`(?i)(?:error|exception)$|tokeni[sz]er|key[_-]?path`)

// NotSecret says whether name, though named like a secret, names a count
// of tokens (max_tokens, token_count), an error, a tokenizer or a key's
// path: its value isn't one.
func NotSecret(name string) bool { return countKey.MatchString(name) || plainName.MatchString(name) }

// Mask replaces what looks like a secret in s with with: the shapes
// above, then what extra matches (nil: nothing more), whose first group
// is kept as theirs is ("NAME="), unless that names no secret
// (NotSecret). A URL keeps its user and its '@'.
func Mask(s, with string, extra *regexp.Regexp) string {
	s = replace(shapes, s, with, false)
	if extra != nil {
		s = replace(extra, s, with, true)
	}
	return s
}

// replace replaces each match of re in s with its first group that isn't
// empty and with; named, a match whose group names no secret
// (NotSecret) stays.
func replace(re *regexp.Regexp, s, with string, named bool) string {
	matches := re.FindAllStringSubmatchIndex(s, -1)
	if matches == nil {
		return s
	}
	var b strings.Builder
	last := 0
	for _, m := range matches {
		keep := ""
		for i := 2; i+1 < len(m); i += 2 {
			if m[i] >= 0 && m[i+1] > m[i] {
				keep = s[m[i]:m[i+1]]
				break
			}
		}
		if named && NotSecret(strings.TrimRight(keep, " \t:='\"")) {
			continue
		}
		b.WriteString(s[last:m[0]])
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

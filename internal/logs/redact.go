package logs

import (
	"regexp"
	"strings"
	"sync"
)

// secretShapes are what keys and tokens look like when they turn up in a
// line, an agent's stderr above all: vendors' key prefixes, bearer tokens,
// JWTs, a password in a URL, and NAME=value or "name": "value" pairs whose
// name says secret. Each match is replaced by its first group and
// [redacted].
var secretShapes = regexp.MustCompile(strings.Join([]string{
	`()\bsk-[A-Za-z0-9_-]{16,}`,              // Anthropic (sk-ant-…), OpenAI (sk-proj-…)
	`()\bfw_[A-Za-z0-9]{16,}`,                // Fireworks
	`()\b(?:gh[pousr]_|github_pat_)\w{20,}`,  // GitHub
	`()\bxox[abprs]-[A-Za-z0-9-]{10,}`,       // Slack
	`()\bAIza[0-9A-Za-z_-]{30,}`,             // Google
	`()\b(?:AKIA|ASIA)[0-9A-Z]{16}\b`,        // AWS key ids
	`()\beyJ[\w-]{8,}\.[\w-]{8,}\.[\w-]{8,}`, // JWTs
	`((?i)\bbearer\s+)[\w.~+/=-]{8,}`,
	`(://[^/\s:@]+:)[^/\s@]+@`,
	`((?i)\b[\w.-]*(?:key|token|secret|passw(?:or)?d|credential)[\w.-]*"?\s*[:=]\s*"?)[^\s"',;]{4,}`,
	`(-----BEGIN [A-Z ]*PRIVATE KEY-----)`,
}, "|"))

var (
	maskMu sync.RWMutex
	masked []string
)

// Mask adds an exact secret to replace wherever it turns up (the client
// token).
func Mask(secret string) {
	if len(secret) < 8 {
		return
	}
	maskMu.Lock()
	masked = append(masked, secret)
	maskMu.Unlock()
}

// Redact replaces what looks like a secret in s with [redacted].
func Redact(s string) string {
	maskMu.RLock()
	for _, m := range masked {
		s = strings.ReplaceAll(s, m, "[redacted]")
	}
	maskMu.RUnlock()
	return secretShapes.ReplaceAllStringFunc(s, func(m string) string {
		for _, g := range secretShapes.FindStringSubmatch(m)[1:] {
			if g != "" {
				return g + "[redacted]"
			}
		}
		return "[redacted]"
	})
}

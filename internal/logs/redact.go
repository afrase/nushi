package logs

import (
	"regexp"
	"strings"
	"sync"

	"github.com/afrase/nushi/internal/secrets"
)

// secretNames are NAME=value or "name": "value" pairs whose name says
// secret, in a line (an agent's stderr above all), masked after the
// shapes every secret mask knows (internal/secrets). Broader than a tool
// call's input's rule: a log line isn't code.
var secretNames = regexp.MustCompile(`((?i)\b[\w.-]*(?:key|token|secret|passw(?:or)?d|credential)[\w.-]*"?\s*[:=]\s*"?)[^\s"',;]{4,}`)

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
	return secrets.Mask(s, "[redacted]", secretNames)
}

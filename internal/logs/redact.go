package logs

import (
	"strings"
	"sync"

	"github.com/afrase/nushi/internal/secrets"
)

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
	return secrets.Mask(s, "[redacted]", secrets.Names)
}

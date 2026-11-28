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

// Redacted stands in for a secret in the log.
const Redacted = "[redacted]"

// Redact replaces what looks like a secret in s with Redacted: the exact
// secrets Mask was given, then, on what that leaves, the shapes and the
// rule for names (secrets.Names), as origin/main did.
func Redact(s string) string {
	maskMu.RLock()
	for _, m := range masked {
		s = strings.ReplaceAll(s, m, Redacted)
	}
	maskMu.RUnlock()
	return secrets.Mask(s, Redacted, secrets.Names)
}

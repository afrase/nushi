package secrets

import (
	"math/rand/v2"
	"regexp"
	"strings"
	"testing"
)

// mainNames is the log's rule for names as origin/main had it at
// b69d6e0bd (internal/logs/redact.go's secretNames), before it took a
// single quote: the reference the log's rule must hide at least as much
// as.
var mainNames = regexp.MustCompile(`((?i)\b[\w.-]*(?:key|token|secret|passw(?:or)?d|credential)[\w.-]*"?\s*[:=]\s*"?)[^\s"',;]{4,}`)

// mainMasked is which bytes of s origin/main's log masked with its rule
// for names: its replace (internal/secrets/secrets.go at b69d6e0bd),
// which kept each match's first group that isn't empty and replaced the
// rest, with the bytes it replaced marked instead of written.
func mainMasked(s string) []bool {
	hidden := make([]bool, len(s))
	for _, m := range mainNames.FindAllStringSubmatchIndex(s, -1) {
		keep := 0
		for i := 2; i+1 < len(m); i += 2 {
			if m[i] >= 0 && m[i+1] > m[i] {
				keep = m[i+1] - m[i]
				break
			}
		}
		for i := m[0] + keep; i < m[1]; i++ {
			hidden[i] = true
		}
	}
	return hidden
}

// nowMasked is which bytes of s the log's rule (Names) masks now.
func nowMasked(s string) []bool {
	hidden := make([]bool, len(s))
	for _, re := range Names {
		for _, sp := range spans(re, s, true) {
			for i := sp[0]; i < sp[1]; i++ {
				hidden[i] = true
			}
		}
	}
	return hidden
}

// line is a made-up line of a program's output: secret-ish names,
// separators, quotes, KeyError's forms and values, in any order.
func line(r *rand.Rand) string {
	pick := func(of ...string) string { return of[r.IntN(len(of))] }
	value := func() string {
		const chars = "abcdefXYZ0123456789_.-"
		b := make([]byte, 1+r.IntN(10))
		for i := range b {
			b[i] = chars[r.IntN(len(chars))]
		}
		return string(b)
	}
	var b strings.Builder
	for range 3 + r.IntN(10) {
		switch r.IntN(6) {
		case 0, 1:
			b.WriteString(pick("token", "api_key", "MY_TOKEN", "password", "passwd", "secret", "x-api-key",
				"credentials", "Key", "keyPath", "max_tokens", "a_token", "zzzz_key", "missing_token", "TokenError", "user"))
		case 2:
			b.WriteString(pick("=", ": ", " = ", ":", " : ", "= ", "=", ": "))
		case 3:
			b.WriteString(pick("'", `"`, "'", `"`, " ", ", ", "; ", "{", "}"))
		case 4:
			b.WriteString(pick("KeyError: '", "KeyError: ", `KeyError: "`, "x.KeyError: '", "keyerror: '", "'KeyError': '", "KeyError:'", "\nKeyError: '"))
		default:
			b.WriteString(value())
		}
	}
	return b.String()
}

// The log hides at least what origin/main's log hid, byte for byte, on
// any line: a few thousand made-up ones through main's rule (above) and
// through the log's rule now.
func TestNamesHideWhatMainHid(t *testing.T) {
	r := rand.New(rand.NewPCG(1, 2)) //nolint:gosec // seeded test lines, not a secret
	checked := 0
	for range 5000 {
		l := line(r)
		if Mask(l, "**", nil) != l { // a shape: both masked it before the names
			continue
		}
		checked++
		was, now := mainMasked(l), nowMasked(l)
		for i := range was {
			if was[i] && !now[i] {
				t.Errorf("%q: main masked byte %d (%q), now it shows: %q", l, i, l[i], Mask(l, "**", Names))
				break
			}
		}
	}
	if checked < 4000 {
		t.Errorf("only %d lines without a shape", checked)
	}
}

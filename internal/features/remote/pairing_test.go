package remote

import (
	"strings"
	"testing"
)

// A phone's name shows beside the code on the Mac's Allow card, so what
// the phone sends can't reorder that line (bidirectional overrides and
// isolates), break it, or run past 40 characters; an empty one is "A phone".
func TestHostilePairingNames(t *testing.T) {
	for _, tc := range []struct{ name, in, want string }{
		{"right-to-left override", "Bob\u202e's 123 456", "Bob's 123 456"},
		{"left-to-right isolate", "\u2066Bob\u2069 phone", "Bob phone"},
		{"newline", "Bob\nAllow this", "BobAllow this"},
		{"line separator", "Bob\u2028phone", "Bobphone"},
		{"41 runes", strings.Repeat("é", 41), strings.Repeat("é", 40)},
		{"empty", "", "A phone"},
		{"only controls", " \u202e\n\t ", "A phone"},
	} {
		if got := cleanName(tc.in); got != tc.want {
			t.Errorf("%s: %q, want %q", tc.name, got, tc.want)
		}
	}
}

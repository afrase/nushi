package mcp

import (
	"strings"
	"testing"
)

// An Authorization header's value is found in one pass over a line,
// however many headers it holds: the searches for the line's end and the
// closing quote read each byte a bounded number of times. Counted, not
// timed.
func TestMaskAuthorizationIsLinear(t *testing.T) {
	const size = 2 << 20
	for name, h := range map[string]string{
		"quoted value":    `Authorization: "x" `,
		"quoted argument": `'Authorization: token x' `,
		"quoted name":     `"Authorization": "x", `,
		"no value":        `Authorization: "" `,
		"masked value":    `Authorization: ` + Mask + `"`,
	} {
		s := strings.Repeat(h, size/len(h)) + "\nnext"
		if _, read := authorizationSpans(s); read > 2*len(s) {
			t.Errorf("%s: read %d bytes of %d (%.0f times)", name, read, len(s), float64(read)/float64(len(s)))
		}
	}
}

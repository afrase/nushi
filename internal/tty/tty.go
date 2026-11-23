// Package tty runs a CLI that won't run without a terminal under
// script(1), which gives it one (Terminal), and reads what it said
// (LastLine): Claude's and Ante's MCP sign-ins.
package tty

import (
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/ansi"
)

// LastLine is the last line of a terminal's output with text, without its
// escape sequences.
func LastLine(out string) string {
	out = ansi.Strip(out)
	lines := strings.FieldsFunc(out, func(r rune) bool { return r == '\n' || r == '\r' })
	for _, line := range slices.Backward(lines) {
		if l := strings.TrimSpace(line); l != "" {
			return l
		}
	}
	return "no output"
}

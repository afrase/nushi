package claudemcp

import "strings"

// shellQuote is s as one word of a POSIX shell's line: in single quotes,
// inside which nothing is special, a single quote of s ending them, then
// a backslash's quote, then single quotes begun again.
func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

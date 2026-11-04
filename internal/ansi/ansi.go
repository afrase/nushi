// Package ansi takes a terminal's escape sequences out of a program's
// output, to show it as plain text.
package ansi

import "regexp"

// escape is a CSI sequence (colours, cursor moves, modes such as
// "\x1b[?25l"): its parameter, intermediate and final bytes (ECMA-48); or
// an OSC one (a window title, an OSC 8 link's ends), up to BEL, ST or the
// text's end.
var escape = regexp.MustCompile(`\x1b(\[[\x30-\x3f]*[\x20-\x2f]*[\x40-\x7e]|\][^\x07\x1b]*(\x07|\x1b\\)?)`)

// Strip is s without its escape sequences; an OSC 8 link keeps its text.
func Strip(s string) string { return escape.ReplaceAllString(s, "") }

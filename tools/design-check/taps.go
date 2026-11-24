package main

import (
	"regexp"
	"strings"
)

// ownTap finds, in a GestureDetector's own arguments, a primary tap that
// makes it a press: a right-click's or a drag's detector isn't one.
var ownTap = regexp.MustCompile(`(?:^|[\s,(])(?:onTap|onTapUp|onTapDown|onDoubleTap):`)

// tapCall is a GestureDetector( call followed across lines: the line it
// opens on, whether that line is marked, how many of its brackets are
// open and its own arguments, nested calls' left out.
type tapCall struct {
	line   int
	marked bool
	depth  int
	own    strings.Builder
}

// tapCalls follows the GestureDetector calls open at a line, outermost
// first, for the press rule: a hand-made press (a tap but no tint, no
// focus, not a button to a screen reader) is a second press path.
type tapCalls struct{ open []*tapCall }

// gestureOpen finds where a GestureDetector's arguments begin.
var gestureOpen = regexp.MustCompile(`\bGestureDetector\($`)

// pressLines reads one line of code (its comment cut), number line,
// marked when it or the line above holds the marker, and lists the lines
// of the calls it closes that take a primary tap and aren't marked.
func (c *tapCalls) pressLines(code string, line int, marked bool) []int {
	masked := stringLiteral.ReplaceAllStringFunc(code, func(s string) string { return strings.Repeat(" ", len(s)) })
	var found []int
	for i := range len(masked) {
		ch := masked[i]
		var top *tapCall
		if n := len(c.open); n > 0 {
			top = c.open[n-1]
		}
		switch {
		case ch == '(' && gestureOpen.MatchString(masked[:i+1]):
			c.open = append(c.open, &tapCall{line: line, marked: marked, depth: 1})
		case top == nil:
		case ch == '(':
			top.depth++
		case ch == ')':
			top.depth--
			if top.depth == 0 {
				c.open = c.open[:len(c.open)-1]
				if !top.marked && ownTap.MatchString(top.own.String()) {
					found = append(found, top.line)
				}
			}
		case top.depth == 1:
			top.own.WriteByte(ch)
		}
	}
	for _, t := range c.open {
		if t.depth == 1 {
			t.own.WriteByte('\n') // an argument per line still starts one
		}
	}
	return found
}

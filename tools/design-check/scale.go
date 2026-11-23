package main

import (
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
)

// The type scale (docs/design.md's Type): the sizes ui() and code() are
// given, nothing set between the steps; the phone's text adds 16
// (phoneText).
var (
	scale      = []float64{11, 11.5, 12, 13, 14, 15, 20}
	phoneScale = []float64{16}
)

// offScale is the type-scale rule's verdict.
const offScale = "a size off the type scale (11, 11.5, 12, 13, 14, 15, 20; the phone's 16): the nearest step, docs/design.md's Type"

// number is a size written as a plain number.
var number = regexp.MustCompile(`^\d+(?:\.\d+)?$`)

// styleCall follows a call of ui( or code( across lines, for the sizes
// it sets: depth is how many of its brackets are open, 0 outside one.
type styleCall struct{ depth int }

// sizes lists the numbers given as size: to a ui( or code( call on one
// line of code (its comment cut), the call carried over from the lines
// before it: a plain number, or each branch of a ternary that is one. A
// size: inside a nested call (an Icon's) isn't the call's own.
func (c *styleCall) sizes(code string) []string {
	masked := stringLiteral.ReplaceAllStringFunc(code, func(s string) string { return strings.Repeat(" ", len(s)) })
	var found []string
	var own strings.Builder // the call's own arguments, nested brackets left out
	end := func() {
		found = append(found, sizesIn(own.String())...)
		own.Reset()
	}
	for i := range len(masked) {
		ch := masked[i]
		switch {
		case c.depth == 0:
			if ch == '(' && (strings.HasSuffix(masked[:i], ".ui") || strings.HasSuffix(masked[:i], ".code")) {
				c.depth = 1
			}
		case ch == '(':
			c.depth++
		case ch == ')':
			c.depth--
			if c.depth == 0 {
				end()
			}
		case c.depth == 1:
			own.WriteByte(ch)
		}
	}
	if c.depth > 0 {
		end()
	}
	return found
}

// sizesIn lists the sizes given as size: in a call's own arguments.
func sizesIn(args string) []string {
	var found []string
	for arg := range strings.SplitSeq(args, ",") {
		value, ok := strings.CutPrefix(strings.TrimSpace(arg), "size:")
		if !ok {
			continue
		}
		branches := []string{value}
		if _, choice, ok := strings.Cut(value, "?"); ok {
			yes, no, _ := strings.Cut(choice, ":")
			branches = []string{yes, no}
		}
		for _, b := range branches {
			if b = strings.TrimSpace(b); number.MatchString(b) {
				found = append(found, b)
			}
		}
	}
	return found
}

// onScale says whether size is a step of the scale, in the file at path
// (the phone's files, under phone/ or named phone_*, have its steps too).
func onScale(size, path string) bool {
	v, err := strconv.ParseFloat(size, 64)
	if err != nil {
		return false
	}
	slashed := "/" + filepath.ToSlash(path)
	phone := strings.Contains(slashed, "/phone/") || strings.HasPrefix(filepath.Base(path), "phone_")
	return slices.Contains(scale, v) || phone && slices.Contains(phoneScale, v)
}

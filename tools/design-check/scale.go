package main

import (
	"regexp"
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

// sizeArg finds a number given as size: inside a call's arguments.
var sizeArg = regexp.MustCompile(`\bsize:\s*([0-9]+(?:\.[0-9]+)?)\s*(?:[,)]|$)`)

// styleCall follows a call of ui( or code( across lines, for the sizes
// it sets: depth is how many of its brackets are open, 0 outside one.
type styleCall struct{ depth int }

// sizes lists the numbers given as size: to a ui( or code( call on one
// line of code (its comment cut), the call carried over from the lines
// before it.
func (c *styleCall) sizes(code string) []string {
	masked := stringLiteral.ReplaceAllStringFunc(code, func(s string) string { return strings.Repeat(" ", len(s)) })
	var args []string
	start := 0
	for i := range len(masked) {
		switch {
		case c.depth == 0:
			if masked[i] == '(' && (strings.HasSuffix(masked[:i], ".ui") || strings.HasSuffix(masked[:i], ".code")) {
				c.depth, start = 1, i+1
			}
		case masked[i] == '(':
			c.depth++
		case masked[i] == ')':
			c.depth--
			if c.depth == 0 {
				args = append(args, masked[start:i+1])
			}
		}
	}
	if c.depth > 0 {
		args = append(args, masked[start:])
	}
	var found []string
	for _, a := range args {
		for _, m := range sizeArg.FindAllStringSubmatch(a, -1) {
			found = append(found, m[1])
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
	steps := scale
	if strings.Contains(path, "/phone/") || strings.HasPrefix(path, "phone/") || strings.HasPrefix(baseName(path), "phone_") {
		steps = append(append([]float64{}, scale...), phoneScale...)
	}
	for _, s := range steps {
		if v == s {
			return true
		}
	}
	return false
}

func baseName(path string) string {
	return path[strings.LastIndexAny(path, `/\`)+1:]
}

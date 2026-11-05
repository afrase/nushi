package launchfile

import (
	"encoding/json"
	"errors"
	"math"
	"regexp"
	"strconv"
	"strings"
)

// errPort is a port that is neither a number from 1 to 65535 nor unset.
var errPort = errors.New(`"port" must be a number from 1 to 65535`)

// decodePort is an entry's port as Claude takes it: a number from 1 to
// 65535, or a string of one to five digits making one; 0, "", false and
// null are unset (0 back).
func decodePort(raw json.RawMessage) (int, error) {
	if raw == nil {
		return 0, nil
	}
	var v any // a number or a string: either is a port
	if err := json.Unmarshal(raw, &v); err != nil {
		return 0, errPort
	}
	switch v := v.(type) {
	case nil:
		return 0, nil
	case bool:
		if !v {
			return 0, nil
		}
	case float64:
		if v == 0 {
			return 0, nil
		}
		if v == math.Trunc(v) && v >= 1 && v <= 65535 {
			return int(v), nil
		}
	case string:
		if v == "" {
			return 0, nil
		}
		if t := strings.TrimFunc(v, isJSSpace); fiveDigits.MatchString(t) {
			if n, _ := strconv.Atoi(t); n >= 1 && n <= 65535 {
				return n, nil
			}
		}
	}
	return 0, errPort
}

// fiveDigits is a port written as a string.
var fiveDigits = regexp.MustCompile(`^\d{1,5}$`)

// decodeAutoPort is an entry's autoPort: nil when absent, else it must be
// true or false (a string or null won't do, as for Claude).
func decodeAutoPort(raw json.RawMessage) (*bool, error) {
	if raw == nil {
		return nil, nil //nolint:nilnil // unset is no error
	}
	var b bool
	if string(raw) == "null" || json.Unmarshal(raw, &b) != nil {
		return nil, errors.New(`"autoPort" must be true or false, unquoted`)
	}
	return &b, nil
}

// The patterns Claude looks for a port by in a command's words, in its
// order, once no word is --port, -p or --port=N on its own.
var (
	portFlag     = regexp.MustCompile(`^(?:--port|-p)=(\d+)$`)
	allDigits    = regexp.MustCompile(`^\d+$`)
	portPatterns = []*regexp.Regexp{
		regexp.MustCompile(`(?:--port|--PORT|-p)` + jsSpace + `+(\d+)`),
		regexp.MustCompile(`localhost:(\d+)`),
		regexp.MustCompile(`:(\d{4,5})(?:` + jsSpace + `|$)`),
	}
)

// jsSpace is JavaScript's \s, which is wider than RE2's.
const jsSpace = `[\t\n\v\f\r \x{a0}\x{1680}\x{2000}-\x{200a}\x{2028}\x{2029}\x{202f}\x{205f}\x{3000}\x{feff}]`

// commandPort is the port Claude reads from an entry as written (its
// variables not resolved), 0 for none: env PORT when set (parsed as
// JavaScript's parseInt, so a word that isn't a number stops the search
// with none); else the first --port N, -p N, --port=N or -p=N among
// program, runtimeExecutable, runtimeArgs and args; else the first word
// matching one of portPatterns, pattern by pattern.
func (c config) commandPort() int {
	if p := c.env["PORT"]; p != "" {
		return parseInt(p)
	}
	words := append([]string{c.program, c.runtimeExecutable}, c.runtimeArgs...)
	words = append(words, c.args...)
	for i, w := range words {
		if (w == "--port" || w == "-p") && i+1 < len(words) && allDigits.MatchString(words[i+1]) {
			return parseInt(words[i+1])
		}
		if m := portFlag.FindStringSubmatch(w); m != nil {
			return parseInt(m[1])
		}
	}
	for _, re := range portPatterns {
		for _, w := range words {
			if m := re.FindStringSubmatch(w); m != nil {
				return parseInt(m[1])
			}
		}
	}
	return 0
}

// parseInt is JavaScript's parseInt(s, 10), with 0 for NaN: leading
// white space, a sign, then digits as far as they go. One too large for a
// port stays too large.
func parseInt(s string) int {
	s = strings.TrimLeftFunc(s, isJSSpace)
	sign := 1
	switch {
	case strings.HasPrefix(s, "-"):
		sign, s = -1, s[1:]
	case strings.HasPrefix(s, "+"):
		s = s[1:]
	}
	n := 0
	for _, r := range s {
		if r < '0' || r > '9' {
			break
		}
		n = min(n*10+int(r-'0'), 1<<20)
	}
	return sign * n
}

// isJSSpace says r is white space to JavaScript's trim and \s.
func isJSSpace(r rune) bool {
	switch r {
	case '\t', '\n', '\v', '\f', '\r', ' ', 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff:
		return true
	}
	return r >= 0x2000 && r <= 0x200a
}

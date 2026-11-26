package secrets

import (
	"encoding/json"
	"slices"
	"strings"
)

// maxJSONDepth is how deep objects and arrays nest before the scan gives
// up on the object it is in, as on any other byte that isn't JSON: real
// output nests far less. Past the cap, what is masked is what each object
// found from the brace the cap stopped at holds under its own secret
// keys, and what the whole objects read inside the given-up one hold
// under theirs, each read again alone. What isn't: a value whose secret
// key is above the cap ({"secret": … 70 levels … "x"}), and the members
// of the objects open at the cap that come after the deep part, which
// are left to the name rules (they mask "password": "value" of four
// characters or more, not an array's values or a shorter one).
const maxJSONDepth = 64

// MaskJSONIn masks, where they stand, the values under keys named like a
// secret (MaskInput's rule: every value under such a key, however deep)
// in each JSON object found in s: a line that is one, or a fragment of a
// line or of several ("HTTP 401: {…}"). Every other byte is kept; a
// brace that starts no JSON object is left as it is.
func MaskJSONIn(s, with string) string {
	out, _ := maskJSONIn(s, with)
	return out
}

// maskJSONIn is MaskJSONIn, and how many bytes it read: at most five
// times len(s), whatever s holds. Each brace not inside an object already
// read starts a try, and a failed try is never tried again from inside
// the bytes it read: the next starts at the byte it failed on, and only
// the whole objects it read inside (a cut-off object's complete members)
// are read once more, each on its own: three times len(s) at most. A
// brace inside a failed try's strings (JSON pasted unescaped into a JSON
// string: "body was {"password": …}") starts a try too, out of a budget
// of twice len(s) more bytes for all of them, each cut short where its
// share runs out.
func maskJSONIn(s, with string) (out string, read int) {
	if !strings.Contains(s, "{") {
		return s, 0
	}
	f := jsonFinder{s: s, extra: 2 * len(s), tried: map[int]bool{}}
	for i := 0; i < len(s); {
		at := strings.IndexByte(s[i:], '{')
		if at < 0 {
			f.read += len(s) - i
			break
		}
		at += i
		f.read += at - i
		pos, braces := f.try(at, len(s))
		f.retry(braces)
		i = pos // past at: its brace was read
	}
	return masked(s, `"`+with+`"`, f.spans), f.read
}

// jsonFinder finds the JSON objects in s and the values in them to mask.
type jsonFinder struct {
	s     string
	spans [][2]int     // the values to mask, those that overlap as one
	read  int          // the bytes read
	extra int          // what tries from braces inside strings may still read
	tried map[int]bool // the braces inside strings tried
}

// try reads an object of s[:end] from at, keeping the values to mask in
// it or, if it isn't one, in the whole objects it read inside; it says
// where it stopped, and, if it failed, the braces inside the strings it
// read. It reads at most twice end-at.
func (f *jsonFinder) try(at, end int) (pos int, braces []int) {
	t := jsonScan{s: f.s[:end], pos: at}
	ok := t.value(0, false)
	f.read += min(t.pos+1, end) - at
	if ok {
		f.spans = append(f.spans, t.spans...)
		return t.pos, nil
	}
	for _, w := range t.whole {
		again := jsonScan{s: t.s, pos: w[0]}
		again.value(0, false) // read whole once, so whole again
		f.read += w[1] - w[0]
		f.spans = append(f.spans, again.spans...)
	}
	return t.pos, t.braces
}

// retry tries the braces inside a failed try's strings, first to last,
// and those inside theirs that fail too, while the budget lasts: each
// reads at most what is left of it.
func (f *jsonFinder) retry(braces []int) {
	slices.Reverse(braces)
	for len(braces) > 0 && f.extra >= 2 {
		b := braces[len(braces)-1]
		braces = braces[:len(braces)-1]
		if f.tried[b] {
			continue
		}
		f.tried[b] = true
		before := f.read
		_, more := f.try(b, min(len(f.s), b+f.extra/2))
		f.extra -= f.read - before
		slices.Reverse(more)
		braces = append(braces, more...)
	}
}

// jsonScan reads one JSON value of s from pos, never going back: pos is
// where it stopped, past the value or on the byte that ended the try.
type jsonScan struct {
	s      string
	pos    int
	spans  [][2]int // the values to mask, in order
	whole  [][2]int // the outermost objects read whole inside the first one
	braces []int    // the braces read inside strings
}

// value reads a value nested in depth objects or arrays; under secret
// every value in it is masked (strings that aren't empty, numbers and
// bools), else only those under a key named like a secret.
func (j *jsonScan) value(depth int, secret bool) bool {
	j.space()
	if j.pos >= len(j.s) {
		return false
	}
	start := j.pos
	switch c := j.s[j.pos]; c {
	case '{', '[':
		if depth >= maxJSONDepth {
			return false
		}
		if c == '[' {
			return j.array(depth, secret)
		}
		if !j.object(depth, secret) {
			return false
		}
		if depth > 0 {
			j.keepWhole(start)
		}
		return true
	case '"':
		if !j.str() {
			return false
		}
		if secret && j.pos-start > len(`""`) {
			j.spans = append(j.spans, [2]int{start, j.pos})
		}
		return true
	case 'n':
		return j.literal("null")
	case 't', 'f':
		if !j.literal("true") && !j.literal("false") {
			return false
		}
	default:
		if !j.number() {
			return false
		}
	}
	if secret {
		j.spans = append(j.spans, [2]int{start, j.pos})
	}
	return true
}

// object reads an object at depth whose '{' is at pos.
func (j *jsonScan) object(depth int, secret bool) bool {
	j.pos++
	if j.space(); j.at('}') {
		j.pos++
		return true
	}
	for {
		if j.space(); !j.at('"') {
			return false
		}
		start := j.pos
		if !j.str() {
			return false
		}
		key := jsonKey(j.s[start:j.pos])
		if j.space(); !j.at(':') {
			return false
		}
		j.pos++
		if !j.value(depth+1, secret || secretKey.MatchString(key) && !NotSecret(key)) {
			return false
		}
		if j.space(); j.at('}') {
			j.pos++
			return true
		}
		if !j.at(',') {
			return false
		}
		j.pos++
	}
}

// array reads an array at depth whose '[' is at pos.
func (j *jsonScan) array(depth int, secret bool) bool {
	j.pos++
	if j.space(); j.at(']') {
		j.pos++
		return true
	}
	for {
		if !j.value(depth+1, secret) {
			return false
		}
		if j.space(); j.at(']') {
			j.pos++
			return true
		}
		if !j.at(',') {
			return false
		}
		j.pos++
	}
}

// keepWhole notes the object read from start to pos, in place of those
// it holds.
func (j *jsonScan) keepWhole(start int) {
	n := len(j.whole)
	for n > 0 && j.whole[n-1][0] >= start {
		n--
	}
	j.whole = append(j.whole[:n], [2]int{start, j.pos})
}

// str reads a string whose '"' is at pos, as JSON allows one: no control
// characters, only JSON's escapes.
func (j *jsonScan) str() bool {
	j.pos++
	for j.pos < len(j.s) {
		switch c := j.s[j.pos]; {
		case c == '"':
			j.pos++
			return true
		case c < 0x20:
			return false
		case c == '{':
			j.braces = append(j.braces, j.pos)
			j.pos++
		case c != '\\':
			j.pos++
		case j.pos+1 < len(j.s) && strings.IndexByte(`"\/bfnrt`, j.s[j.pos+1]) >= 0:
			j.pos += 2
		case j.pos+1 < len(j.s) && j.s[j.pos+1] == 'u':
			j.pos += 2
			for range 4 {
				if !j.at('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'A', 'B', 'C', 'D', 'E', 'F') {
					return false
				}
				j.pos++
			}
		default:
			return false
		}
	}
	return false
}

// number reads a number as JSON writes one: -?(0|[1-9]d*)(.d+)?([eE][+-]?d+)?
func (j *jsonScan) number() bool {
	if j.at('-') {
		j.pos++
	}
	switch {
	case j.at('0'):
		j.pos++
	case j.digits() == 0:
		return false
	}
	if j.at('.') {
		j.pos++
		if j.digits() == 0 {
			return false
		}
	}
	if j.at('e', 'E') {
		j.pos++
		if j.at('+', '-') {
			j.pos++
		}
		if j.digits() == 0 {
			return false
		}
	}
	return true
}

// digits reads digits and says how many.
func (j *jsonScan) digits() int {
	start := j.pos
	for j.pos < len(j.s) && '0' <= j.s[j.pos] && j.s[j.pos] <= '9' {
		j.pos++
	}
	return j.pos - start
}

// literal reads word if it is at pos.
func (j *jsonScan) literal(word string) bool {
	if !strings.HasPrefix(j.s[j.pos:], word) {
		return false
	}
	j.pos += len(word)
	return true
}

// space reads JSON's white space.
func (j *jsonScan) space() {
	for j.at(' ', '\t', '\n', '\r') {
		j.pos++
	}
}

// at says whether the byte at pos is one of cs.
func (j *jsonScan) at(cs ...byte) bool {
	if j.pos >= len(j.s) {
		return false
	}
	return slices.Contains(cs, j.s[j.pos])
}

// jsonKey is a key's text from its quoted JSON, escapes read ("token"
// is token).
func jsonKey(quoted string) string {
	if !strings.Contains(quoted, `\`) {
		return quoted[1 : len(quoted)-1]
	}
	var key string
	_ = json.Unmarshal([]byte(quoted), &key) // str read it as JSON's
	return key
}

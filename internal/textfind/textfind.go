// Package textfind finds plain text, case aside, in agents' transcripts
// (ADR 0035's search): a quick test of each raw JSON line, so a line that
// can't say the text is never decoded, then the hits in a message's text
// and an excerpt around the first. No index is kept: each search reads the
// files again.
package textfind

import (
	"bytes"
	"slices"
	"strings"
	"unicode"
	"unicode/utf8"
)

// Query is text to find: case aside, its whitespace matching any run of
// whitespace.
type Query struct {
	text []rune // the query, its whitespace squashed to single spaces
	// anchor is the longest run of the query's ASCII that JSON writes as
	// it is (no space, quote, backslash or control), lowered; a line
	// without it can't hold the query. pivot is its rarest byte's place.
	anchor []byte
	pivot  int
	// literal says text is the query as written, matched so (Literal).
	literal bool
}

// New is the query q.
func New(q string) Query {
	squashed := squash(q)
	out := Query{text: []rune(squashed)}
	out.anchor, out.pivot = anchorOf(squashed)
	return out
}

// Literal is the query q as written: case aside, its whitespace as it is,
// as the app's find in a chat's transcript matches the text laid out.
func Literal(q string) Query {
	out := Query{text: []rune(q), literal: true}
	out.anchor, out.pivot = anchorOf(q)
	return out
}

// anchorOf is q's longest run of the ASCII that JSON writes as it is,
// lowered, and its rarest byte's place (Query's anchor and pivot).
func anchorOf(q string) (anchor []byte, pivot int) {
	run := 0
	for i := 0; i <= len(q); i++ {
		if i < len(q) && verbatim(q[i]) {
			run++
			continue
		}
		if run > len(anchor) {
			anchor = bytes.ToLower([]byte(q[i-run : i]))
		}
		run = 0
	}
	for i, b := range anchor {
		if rank(b) < rank(anchor[pivot]) {
			pivot = i
		}
	}
	return anchor, pivot
}

// Empty says there's nothing to find.
func (q Query) Empty() bool { return len(q.text) == 0 }

// verbatim says JSON writes b as it is (JavaScript's JSON.stringify and
// Rust's serde_json escape only quotes, backslashes and controls), and
// that it isn't whitespace, which a query matches loosely.
func verbatim(b byte) bool { return b > ' ' && b < 0x7f && b != '"' && b != '\\' }

// rank is how common b is in a transcript's lines, the rarest lowest:
// letters as in English, digits common (ids and times), the rest between.
func rank(b byte) int {
	const letters = "zqjxkvbpygfwmucldrhsnioate"
	if i := strings.IndexByte(letters, lower(b)); i >= 0 {
		return i
	}
	if b >= '0' && b <= '9' {
		return 20
	}
	return 12
}

func lower(b byte) byte {
	if b >= 'A' && b <= 'Z' {
		return b + 'a' - 'A'
	}
	return b
}

func upper(b byte) byte {
	if b >= 'a' && b <= 'z' {
		return b - ('a' - 'A')
	}
	return b
}

// MayHold says whether a raw line of JSON may hold the query once decoded:
// false only when it can't. Two folds into ASCII aren't seen here (the
// Kelvin sign as a k, the long s as an s): a line saying the query only so
// is passed over.
func (q Query) MayHold(line []byte) bool {
	return mayHold(q, line, func(from int, b byte) int {
		if i := bytes.IndexByte(line[from:], b); i >= 0 {
			return from + i
		}
		return -1
	})
}

// mayHoldText is MayHold for plain text.
func (q Query) mayHoldText(text string) bool {
	return mayHold(q, text, func(from int, b byte) int {
		if i := strings.IndexByte(text[from:], b); i >= 0 {
			return from + i
		}
		return -1
	})
}

// mayHold says line may hold the query: it has the anchor, ASCII's case
// aside. next(at, b) is the place of the first b in line at or after at,
// or -1.
func mayHold[T string | []byte](q Query, line T, next func(from int, b byte) int) bool {
	a := q.anchor
	if len(a) == 0 {
		return true
	}
	lo, up := a[q.pivot], upper(a[q.pivot])
	nl, nu := next(0, lo), -1
	if up != lo {
		nu = next(0, up)
	}
	for nl >= 0 || nu >= 0 {
		c := nl
		if c < 0 || nu >= 0 && nu < c {
			c = nu
		}
		if s := c - q.pivot; s >= 0 && s+len(a) <= len(line) && asciiFold(line, s, a) {
			return true
		}
		if c == nl {
			nl = next(c+1, lo)
		} else {
			nu = next(c+1, up)
		}
	}
	return false
}

// asciiFold says b holds a at at, ASCII's case aside (a is lower case).
func asciiFold[T string | []byte](b T, at int, a []byte) bool {
	for i := range a {
		if lower(b[at+i]) != a[i] {
			return false
		}
	}
	return true
}

// Excerpt is the text around a hit, on one line.
type Excerpt struct {
	// Before and After are cut to a few words each, "…" where cut;
	// Match is the hit as written.
	Before, Match, After string
}

// How much of the text an excerpt keeps on each side of the hit, in
// characters.
const (
	beforeChars = 48
	afterChars  = 120
	// wordSlack is how far a cut moves to fall between words.
	wordSlack = 16
)

// Find counts the hits in text and makes an excerpt around the first;
// 0 and no excerpt when there are none. The text is always squashed, a
// Literal query's too, so the excerpt stays on one line.
func (q Query) Find(text string) (int, Excerpt) {
	if q.Empty() || !q.mayHoldText(text) {
		return 0, Excerpt{}
	}
	s := squash(text)
	n, first, end := q.walk(s)
	if n == 0 {
		return 0, Excerpt{}
	}
	return n, Excerpt{Before: cutBefore(s[:first]), Match: s[first:end], After: cutAfter(s[end:])}
}

// Count is how many times the query is in text, case aside, each match
// after the one before it ends; a quick test of the anchor first, so text
// that can't hold it isn't walked.
func (q Query) Count(text string) int {
	if q.Empty() || !q.mayHoldText(text) {
		return 0
	}
	if !q.literal {
		text = squash(text)
	}
	n, _, _ := q.walk(text)
	return n
}

// walk counts the query's hits in s, prepared (squashed or not), each
// after the one before it ends, and says where the first starts and ends.
func (q Query) walk(s string) (n, first, end int) {
	for i := 0; i < len(s); {
		if j, ok := q.prefixOf(s[i:]); ok {
			if n == 0 {
				first, end = i, i+j
			}
			n++
			i += j
			continue
		}
		_, size := utf8.DecodeRuneInString(s[i:])
		i += size
	}
	return n, first, end
}

// prefixOf says whether s starts with the query, case aside, and how many
// of s's bytes that takes.
func (q Query) prefixOf(s string) (int, bool) {
	at := 0
	for _, want := range q.text {
		r, size := utf8.DecodeRuneInString(s[at:])
		if size == 0 || !sameFold(r, want) {
			return 0, false
		}
		at += size
	}
	return at, true
}

// sameFold says r and want are one letter, case aside (Unicode's simple
// folding, as strings.EqualFold).
func sameFold(r, want rune) bool {
	if r == want {
		return true
	}
	for f := unicode.SimpleFold(r); f != r; f = unicode.SimpleFold(f) {
		if f == want {
			return true
		}
	}
	return false
}

// squash is s with each run of whitespace one space, and none at its ends.
func squash(s string) string { return strings.Join(strings.Fields(s), " ") }

// cutBefore keeps the end of s, beforeChars at most, starting at a word.
func cutBefore(s string) string {
	r := []rune(s)
	if len(r) <= beforeChars {
		return s
	}
	kept := r[len(r)-beforeChars:]
	if i := runeIndex(kept[:wordSlack], ' '); i >= 0 {
		kept = kept[i+1:]
	}
	return "…" + string(kept)
}

// cutAfter keeps the start of s, afterChars at most, ending at a word.
func cutAfter(s string) string {
	r := []rune(s)
	if len(r) <= afterChars {
		return s
	}
	kept := r[:afterChars]
	if i := lastRuneIndex(kept[afterChars-wordSlack:], ' '); i >= 0 {
		kept = kept[:afterChars-wordSlack+i]
	}
	return string(kept) + "…"
}

func runeIndex(rs []rune, r rune) int {
	for i, x := range rs {
		if x == r {
			return i
		}
	}
	return -1
}

func lastRuneIndex(rs []rune, r rune) int {
	for i, x := range slices.Backward(rs) {
		if x == r {
			return i
		}
	}
	return -1
}

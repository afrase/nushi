package main

import (
	"regexp"
	"strconv"
	"strings"
	"unicode/utf8"
)

// separator is the verdict on a string that joins a line's parts with a
// middle dot, a dash or a bullet, which the owner reads as an AI tell
// (docs/design.md's Words): a comma, a second line, or the second part in
// muted ink after a space instead.
const separator = "a middle dot or spaced dash between a line's parts: a comma, a second line, " +
	"or muted ink after a space (a dot or dash that's data takes // design: <why>)"

// A space, in the patterns below, is any of Unicode's spaces as well as
// ASCII's (Go's \s is ASCII only): a no-break space ("a – b",
// as the daemon's own lines hold them), a narrow or a thin one, and a
// zero-width space (U+200B, a format character, not a Zs), which hides a
// join's spaces from sight but not from the reader.
//
// What it can't see: two literals joined with + ('$a ' + '- $b') are two
// strings to the lexer, each judged on its own, since it reads literals,
// not expressions; adjacent literals with no + between ('$a ' '- $b') are
// one string to Dart and are judged as one.
var (
	// spacedDash is a dash of the class (‒ – — ― ⸺) with a space or the
	// text's end either side; a range ("3–5", "3‒5") isn't one.
	spacedDash = regexp.MustCompile(`(?:^|[\s\p{Zs}\x{200B}])[‒–—―⸺](?:[\s\p{Zs}\x{200B}]|$)`)
	// spacedHyphen is a hyphen with a space after it and, before it, a
	// space after some text or at the text's start (" - done"); a
	// Markdown bullet ("- item") and a minus ("x-1") aren't one.
	spacedHyphen = regexp.MustCompile(`(?:^|[^\s\p{Zs}\x{200B}])[\s\p{Zs}\x{200B}]+-[\s\p{Zs}\x{200B}]`)
	// joiningBullet is a bullet (•, ‣, ◦, ⁃, ● or ▪) with a space after it
	// and a space before it, as a join (" • "); one that starts an item
	// ("• first") or a masked secret ("••••") isn't one.
	joiningBullet = regexp.MustCompile(`(?:^|[^\s\p{Zs}\x{200B}])[\s\p{Zs}\x{200B}]+[•‣◦⁃●▪](?:[\s\p{Zs}\x{200B}]|$)`)
)

// dots read as a middle dot wherever they are: the middle dot, the bullet
// and dot operators (∙ U+2219, ⋅ U+22C5), the hyphenation point (‧ U+2027),
// the katakana middle dot (・ U+30FB) and its halfwidth form (･ U+FF65),
// the Greek ano teleia (· U+0387) and the word separator middle dot (⸱
// U+2E31).
const dots = "·∙⋅‧・･\u0387⸱"

// emDashes join wherever they are, spaced or not: the em dash, the
// horizontal bar and the two-em dash. The en and figure dashes join only
// spaced, since unspaced they make a range.
const emDashes = "—―⸺"

// joins says whether a string's text (its interpolations each put as x,
// its escapes read) joins a line's parts: a middle dot or one that looks
// like it anywhere, an em dash anywhere but as the whole text (a blank's
// '—'), a spaced dash of the class, a spaced hyphen, or a bullet as a
// join.
func joins(text string) bool {
	alone := utf8.RuneCountInString(text) == 1
	return strings.ContainsAny(text, dots) ||
		strings.ContainsAny(text, emDashes) && !alone ||
		spacedDash.MatchString(text) && !alone ||
		spacedHyphen.MatchString(text) ||
		joiningBullet.MatchString(text)
}

// separatorLines reads a Dart file's source as the language does, its
// strings, their interpolations (strings nested in them included), raw
// strings, escapes, multi-line strings and comments, and says which lines
// (from 1) hold string text that [joins] parts. A multi-line string's text
// is judged a line at a time, so its marker is a line's own.
func separatorLines(src string) map[int]bool {
	l := lexer{found: map[int]bool{}, line: 1}
	l.read(src)
	return l.found
}

// frame is where the lexer stands: in code (a string's interpolation, or
// the file itself), or in a string.
type frame struct {
	str    bool
	quote  byte // the string's quote
	triple bool // ''' or """
	raw    bool
	depth  int // in code: the braces open inside an interpolation
	text   strings.Builder
	// In code: the last line's text of the string literal just closed,
	// while only spaces, line ends and comments follow it, since a
	// literal next to it goes on with it ('$a ' '- $b' is one string to
	// Dart).
	before  string
	adjoins bool
	// In a string: where its own text starts after [before]'s.
	from int
}

type lexer struct {
	stack []*frame
	found map[int]bool
	line  int
}

func (l *lexer) top() *frame { return l.stack[len(l.stack)-1] }

// judge looks at the text a string holds so far on this line, and starts
// the next line's afresh. Text it goes on from (an adjacent literal's,
// [frame.before]) counts only for a join across the two: one already in
// that text was found on its own line, which its marker covers.
func (l *lexer) judge(f *frame) {
	text := f.text.String()
	own := text[f.from:]
	if joins(own) || joins(text) && !joins(text[:f.from]) {
		l.found[l.line] = true
	}
	f.text.Reset()
	f.from = 0
}

func (l *lexer) read(src string) {
	l.stack = []*frame{{}}
	for i := 0; i < len(src); {
		f := l.top()
		c := src[i]
		if c == '\n' {
			for _, g := range l.stack {
				if g.str {
					l.judge(g)
				}
			}
			// A single-quoted string ends with its line (Dart allows no
			// more); only a multi-line one, and the code around it, go on.
			for len(l.stack) > 1 && l.top().str && !l.top().triple {
				l.stack = l.stack[:len(l.stack)-1]
			}
			l.line++
			i++
			continue
		}
		if !f.str {
			i = l.code(src, i, f)
			continue
		}
		i = l.inString(src, i, f)
	}
}

// code reads one step of code at src[i] in frame f.
func (l *lexer) code(src string, i int, f *frame) int {
	c := src[i]
	if !adjacent(src[i:]) {
		f.adjoins = false
	}
	switch {
	case strings.HasPrefix(src[i:], "//"):
		// A comment, to the line's end.
		for i < len(src) && src[i] != '\n' {
			i++
		}
		return i
	case strings.HasPrefix(src[i:], "/*"):
		end := strings.Index(src[i+2:], "*/")
		if end < 0 {
			return len(src)
		}
		l.line += strings.Count(src[i:i+2+end], "\n")
		return i + 2 + end + 2
	case c == '\'' || c == '"':
		s := &frame{str: true, quote: c}
		s.raw = i > 0 && src[i-1] == 'r' && (i < 2 || !identChar(src[i-2]))
		if f.adjoins {
			s.text.WriteString(f.before)
			s.from = len(f.before)
			f.adjoins = false
		}
		if strings.HasPrefix(src[i:], strings.Repeat(string(c), 3)) {
			s.triple = true
			i += 2
		}
		l.stack = append(l.stack, s)
		return i + 1
	case c == '{':
		f.depth++
	case c == '}':
		if f.depth > 0 {
			f.depth--
			break
		}
		// The interpolation ends: back in its string, which holds an x
		// where it was.
		if len(l.stack) > 1 {
			l.stack = l.stack[:len(l.stack)-1]
			l.top().text.WriteByte('x')
		}
	}
	return i + 1
}

// inString reads one step of a string's text at src[i] in frame f.
func (l *lexer) inString(src string, i int, f *frame) int {
	c := src[i]
	switch {
	case c == f.quote && (!f.triple || strings.HasPrefix(src[i:], strings.Repeat(string(c), 3))):
		text := f.text.String()
		l.judge(f)
		l.stack = l.stack[:len(l.stack)-1]
		out := l.top()
		out.before, out.adjoins = text, true
		if f.triple {
			return i + 3
		}
		return i + 1
	case f.raw:
	case c == '\\' && i+1 < len(src):
		r, n := escape(src[i+1:])
		f.text.WriteRune(r)
		return i + 1 + n
	case c == '$' && strings.HasPrefix(src[i:], "${"):
		l.stack = append(l.stack, &frame{})
		return i + 2
	case c == '$':
		// $name: an x, as an interpolation.
		j := i + 1
		for j < len(src) && identChar(src[j]) {
			j++
		}
		f.text.WriteByte('x')
		return j
	}
	r, n := utf8.DecodeRuneInString(src[i:])
	f.text.WriteRune(r)
	return i + n
}

// escape reads the escape after a backslash in s: \uXXXX, \u{X…} and \xXX
// as the character they name, anything else as itself; it answers the
// character and how many bytes of s it took.
func escape(s string) (rune, int) {
	hex := func(h string) (rune, bool) {
		if len(h) > 8 {
			return 0, false
		}
		r, _, _, err := strconv.UnquoteChar(`\U`+strings.Repeat("0", 8-len(h))+h, '\'')
		return r, err == nil
	}
	switch {
	case strings.HasPrefix(s, "u{"):
		if end := strings.IndexByte(s, '}'); end > 2 {
			if r, ok := hex(s[2:end]); ok {
				return r, end + 1
			}
		}
	case s[0] == 'u' && len(s) >= 5:
		if r, ok := hex(s[1:5]); ok {
			return r, 5
		}
	case s[0] == 'x' && len(s) >= 3:
		if r, ok := hex(s[1:3]); ok {
			return r, 3
		}
	}
	r, n := utf8.DecodeRuneInString(s)
	return r, n
}

func identChar(c byte) bool {
	return c == '_' || c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9'
}

// adjacent says whether code at s keeps a string literal just closed
// next to the one that may follow: a space, a comment, or the next
// literal itself (raw or not).
func adjacent(s string) bool {
	switch {
	case s[0] == ' ' || s[0] == '\t' || s[0] == '\r' || s[0] == '\'' || s[0] == '"':
		return true
	case strings.HasPrefix(s, "//") || strings.HasPrefix(s, "/*"):
		return true
	}
	return len(s) > 1 && s[0] == 'r' && (s[1] == '\'' || s[1] == '"')
}

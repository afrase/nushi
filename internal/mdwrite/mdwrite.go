// Package mdwrite writes Markdown for anyone's text: text escaped so it
// can't read as Markdown, code spans and fences no text can end, link
// destinations nothing can break out of, quotes and indents. Jira's ADF
// and GitHub's text both go to the app through it.
package mdwrite

import (
	"fmt"
	"strings"
	"unicode"
)

// Escape keeps a text's characters from reading as Markdown: an
// underscore only where it could start or end emphasis (snake_case
// stays), what starts a block only at a line's start, a "!" only at the
// end (where a link that follows would make it an image).
func Escape(s string) string {
	var b strings.Builder
	r := []rune(s)
	lineStart := true
	for i := 0; i < len(r); i++ {
		c := r[i]
		switch {
		case strings.ContainsRune("\\`*[]<~&", c): // one ~ is a strikethrough too (GFM); & could start an entity
			b.WriteRune('\\')
		case c == '_' && (i == 0 || i == len(r)-1 || !isWord(r[i-1]) || !isWord(r[i+1])):
			b.WriteRune('\\')
		case lineStart && strings.ContainsRune("#+-=>", c):
			b.WriteRune('\\')
		case lineStart && unicode.IsDigit(c): // "1." or "1)" would start a list
			j := i
			for j < len(r) && unicode.IsDigit(r[j]) {
				j++
			}
			if j < len(r) && (r[j] == '.' || r[j] == ')') {
				b.WriteString(string(r[i:j]) + "\\" + string(r[j]))
				i, lineStart = j, false
				continue
			}
		}
		if c == '!' && i == len(r)-1 { // a link written after it would be an image
			b.WriteRune('\\')
		}
		b.WriteRune(c)
		lineStart = c == '\n' || c == '\r' || lineStart && c == ' '
	}
	return b.String()
}

func isWord(r rune) bool { return unicode.IsLetter(r) || unicode.IsDigit(r) }

// Code is s as a code span: on one line, in more backticks than it
// holds.
func Code(s string) string {
	// A code span reads a line break as a space; one left in could let
	// the next line start a block (a heading, HTML) and end the span.
	s = strings.NewReplacer("\r\n", " ", "\n", " ", "\r", " ").Replace(s)
	ticks := "`"
	for strings.Contains(s, ticks) {
		ticks += "`"
	}
	if strings.HasPrefix(s, "`") || strings.HasSuffix(s, "`") {
		s = " " + s + " "
	}
	return ticks + s + ticks
}

// Fence is s as a fenced code block in lang (dropped unless it's a
// language's name), in a fence longer than any it holds.
func Fence(s, lang string) string {
	if strings.TrimLeft(lang, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+#.-") != "" {
		lang = "" // only a language's name may follow the fence
	}
	f := "```"
	for strings.Contains(s, f) {
		f += "`"
	}
	return f + lang + "\n" + strings.TrimSuffix(s, "\n") + "\n" + f
}

// Dest makes a URL safe as a link's destination: nothing in it can end
// the destination or the link (spaces and control characters, brackets,
// angle brackets, backslashes are percent-encoded).
func Dest(href string) string {
	var b strings.Builder
	// The ends' spaces go, as SafeLink reads the address without them.
	for _, c := range []byte(strings.TrimSpace(href)) {
		if c <= ' ' || c == 0x7f || strings.IndexByte("()<>\\", c) >= 0 {
			fmt.Fprintf(&b, "%%%02X", c)
		} else {
			b.WriteByte(c)
		}
	}
	return b.String()
}

// Quote puts "> " before each of s's lines.
func Quote(s string) string {
	lines := strings.Split(s, "\n")
	for i, l := range lines {
		lines[i] = strings.TrimRight("> "+l, " ")
	}
	return strings.Join(lines, "\n")
}

// Indent puts pad before each of s's lines but the first.
func Indent(s, pad string) string {
	return strings.ReplaceAll(s, "\n", "\n"+pad)
}

// SafeLink says a link may be followed or put into Markdown: http, https
// and mailto only (anyone's text, an issue's or a pull request's, could
// name a file:, a javascript: or an app's own scheme, which could open
// something on the Mac).
func SafeLink(href string) bool {
	h := strings.ToLower(strings.TrimSpace(href))
	return strings.HasPrefix(h, "https://") || strings.HasPrefix(h, "http://") || strings.HasPrefix(h, "mailto:")
}

// SafeImage says an image's address may be shown (as a link the user
// clicks; nothing fetches it on its own): http and https only.
func SafeImage(src string) bool {
	h := strings.ToLower(strings.TrimSpace(src))
	return strings.HasPrefix(h, "https://") || strings.HasPrefix(h, "http://")
}

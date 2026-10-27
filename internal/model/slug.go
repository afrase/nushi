package model

import (
	"strings"
	"unicode"
)

// Slug is s's words for a branch's name: its ASCII letters and digits,
// lowercase, words joined by "-", cut between words at n characters (a
// first word longer than that cut short). Nothing else is kept, so it is
// a name git takes; empty when s has no such words.
func Slug(s string, n int) string {
	words := strings.FieldsFunc(strings.ToLower(s), func(r rune) bool {
		return r > unicode.MaxASCII || !unicode.IsLetter(r) && !unicode.IsDigit(r)
	})
	out := ""
	for _, w := range words {
		if len(out)+len(w)+1 > n && out != "" {
			break
		}
		out = strings.TrimPrefix(out+"-"+w, "-")
	}
	return out[:min(len(out), n)]
}

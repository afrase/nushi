package githubapi

import (
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"
)

// plain is someone else's text for a field of its own, shown and not
// rendered: valid UTF-8, without control or format characters (bidi marks,
// zero-width ones, which could hide or reorder what's around it; line
// breaks and tabs stay), at most limit bytes.
func plain(s string, limit int) string {
	var b strings.Builder
	for _, r := range strings.ToValidUTF8(s, "") {
		if r != '\n' && r != '\t' && (unicode.IsControl(r) || unicode.Is(unicode.Cf, r) || r == '\u2028' || r == '\u2029') {
			continue
		}
		if b.Len()+utf8.RuneLen(r) > limit {
			break
		}
		b.WriteRune(r)
	}
	return b.String()
}

// loginRE is a GitHub login: letters, digits and dashes, 39 at most, a
// bot's with its [bot].
var loginRE = regexp.MustCompile(`^[A-Za-z0-9-]{1,39}(\[bot\])?$`)

// shown is a login for a view's own sentence, where anything else ("someone")
// would read as Nushi's words.
func shown(login string) string {
	if !loginRE.MatchString(login) {
		return "someone"
	}
	return login
}

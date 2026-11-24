package githubapi

import (
	"encoding/json"
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

// maxText bounds a text field as it's decoded: generous, so a field
// with its own, smaller cap (a label's, a commit title's, an annotation's
// in Brief) is cut there and not before.
const maxText = 64 << 10

// text is a string field of GitHub's answer that holds someone else's
// words (a title, a check's name, an annotation's message), plain as it's
// decoded, so no decoder can forget to clean one. Markdown fields (bodies,
// summaries) are cleaned by Markdown instead, and ids, enums, logins and
// addresses stay strings.
type text string

// UnmarshalJSON decodes a JSON string (or null, which is "") through plain.
func (t *text) UnmarshalJSON(b []byte) error {
	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		return err
	}
	*t = text(plain(s, maxText))
	return nil
}

// loginRE is a GitHub login: letters, digits and dashes, 39 at most, an
// Enterprise Managed User's with an underscore and its enterprise's short
// code after them (mona-cat_octo), a bot's with its [bot].
var loginRE = regexp.MustCompile(`^[A-Za-z0-9-]{1,39}(_[A-Za-z0-9]{1,39})?(\[bot\])?$`)

// shown is a login for a view's own sentence, where anything else ("someone")
// would read as Nushi's words.
func shown(login string) string {
	if !loginRE.MatchString(login) {
		return "someone"
	}
	return login
}

package githubapi

import (
	"html"
	"regexp"
	"strings"
)

var (
	commentRE = regexp.MustCompile(`(?s)<!--.*?-->`)
	imgRE     = regexp.MustCompile(`(?i)<img\b[^>]*>`)
	attrRE    = regexp.MustCompile(`(?i)\b(src|alt|href)\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)`)
	linkRE    = regexp.MustCompile(`(?is)<a\b([^>]*)>(.*?)</a>`)
	breakRE   = regexp.MustCompile(`(?i)<br\s*/?>`)
	tagRE     = regexp.MustCompile(`</?[A-Za-z][A-Za-z0-9-]*(?:\s[^<>]*)?/?>`)
	fenceRE   = regexp.MustCompile("^ {0,3}(```+|~~~+)")
)

// Markdown is GitHub-flavoured Markdown from GitHub (a pull request's
// text, a comment) as Nushi shows it and gives it to an agent: what
// GitHub's page shows of it, as Markdown. HTML comments go (GitHub hides
// them: a pull request template's notes, or text meant for an agent and
// not for the reader); an <img> is an image (which the app shows as a
// link, never fetched), an <a> a link, <br> a line break, and any other
// tag goes, its text kept. Code, fenced or inline, stays as written.
func Markdown(s string) string {
	s = strings.ReplaceAll(s, "\r\n", "\n")
	var out, prose strings.Builder
	flush := func() {
		out.WriteString(cleanHTML(prose.String()))
		prose.Reset()
	}
	fence := ""
	for line := range strings.Lines(s) {
		m := fenceRE.FindStringSubmatch(line)
		switch {
		case fence != "":
			out.WriteString(line)
			if len(m) > 1 && m[1][0] == fence[0] && len(m[1]) >= len(fence) && strings.TrimSpace(line) == m[1] {
				fence = ""
			}
		case m != nil:
			flush()
			fence = m[1]
			out.WriteString(line)
		default:
			prose.WriteString(line)
		}
	}
	flush()
	return strings.TrimRight(out.String(), "\n")
}

// cleanHTML cleans prose's HTML, leaving inline code spans as they
// are.
func cleanHTML(s string) string {
	s = commentRE.ReplaceAllString(s, "")
	parts := strings.Split(s, "`")
	for i := range parts {
		if i%2 == 0 || i == len(parts)-1 { // outside a code span (or an unclosed one's tail)
			parts[i] = cleanTags(parts[i])
		}
	}
	return strings.Join(parts, "`")
}

func cleanTags(s string) string {
	s = imgRE.ReplaceAllStringFunc(s, func(tag string) string {
		a := attrs(tag)
		if a["src"] == "" {
			return ""
		}
		return "![" + escapeAlt(a["alt"]) + "](" + a["src"] + ")"
	})
	s = linkRE.ReplaceAllStringFunc(s, func(tag string) string {
		m := linkRE.FindStringSubmatch(tag)
		text := strings.TrimSpace(tagRE.ReplaceAllString(m[2], ""))
		if href := attrs(m[1])["href"]; href != "" && text != "" {
			return "[" + text + "](" + href + ")"
		}
		return text
	})
	s = breakRE.ReplaceAllString(s, "  \n")
	return tagRE.ReplaceAllString(s, "")
}

// attrs are a tag's src, alt and href, unquoted and unescaped; an
// address with what would end a Markdown link escaped.
func attrs(tag string) map[string]string {
	out := map[string]string{}
	for _, m := range attrRE.FindAllStringSubmatch(tag, -1) {
		name, v := strings.ToLower(m[1]), html.UnescapeString(strings.Trim(m[2], `"'`))
		if name != "alt" {
			v = strings.NewReplacer("(", "%28", ")", "%29", " ", "%20", "<", "%3C", ">", "%3E").Replace(v)
		}
		out[name] = v
	}
	return out
}

func escapeAlt(s string) string {
	return strings.NewReplacer("[", `\[`, "]", `\]`).Replace(s)
}

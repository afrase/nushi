package githubapi

import (
	"fmt"
	"html"
	"regexp"
	"strings"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/extension"
	east "github.com/yuin/goldmark/extension/ast"
	"github.com/yuin/goldmark/text"

	"github.com/afrase/nushi/internal/mdwrite"
)

// gfm parses as GitHub does: CommonMark with GitHub's extensions, so a
// fence, a code span, an HTML block or comment and a table's cells begin
// and end where GitHub's do.
var gfm = goldmark.New(goldmark.WithExtensions(extension.GFM))

var (
	commentRE = regexp.MustCompile(`(?s)<!--.*?-->`)
	tagRE     = regexp.MustCompile(`(?s)<(/?)([A-Za-z][A-Za-z0-9-]*)((?:\s[^<>]*)?)/?>`)
	attrRE    = regexp.MustCompile(`(?i)\b(src|alt|href)\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)`)
)

// Markdown is GitHub-flavoured Markdown from GitHub (a pull request's
// text, a comment, a check's summary) as Nushi shows it and gives it to an
// agent: what GitHub's page shows of it, written again as Markdown. It is
// parsed as GitHub parses it (goldmark, GFM) and only what the page shows
// is written: no HTML comment (GitHub hides it: a template's notes, or
// text meant for an agent and not for the reader), nothing after a comment
// that never closes, no link reference definition, no table cell past the
// header's. Raw HTML becomes what it shows: an <img> an image (which the
// app shows as a link, never fetched), an <a> a link, <br> a line break,
// any other tag its text. Text is escaped, so nothing of it reads as
// Markdown it wasn't; code stays as written.
func Markdown(s string) string {
	src := []byte(strings.ReplaceAll(s, "\r\n", "\n"))
	w := &mdWriter{src: src}
	return strings.TrimSpace(w.blocks(gfm.Parser().Parse(text.NewReader(src)), "\n\n"))
}

type mdWriter struct {
	src []byte
	// hidden says a comment never closed: the rest of the page is in it.
	hidden bool
	hrefs  []string // the raw <a> tags open in the inline being written
	cell   bool     // writing a table's cell
}

func (w *mdWriter) blocks(parent ast.Node, sep string) string {
	var parts []string
	for n := parent.FirstChild(); n != nil && !w.hidden; n = n.NextSibling() {
		if b := w.block(n); b != "" {
			parts = append(parts, b)
		}
	}
	return strings.Join(parts, sep)
}

func (w *mdWriter) block(n ast.Node) string {
	switch n := n.(type) {
	case *ast.Paragraph, *ast.TextBlock:
		return w.inline(n)
	case *ast.Heading:
		return strings.Repeat("#", n.Level) + " " + w.inline(n)
	case *ast.ThematicBreak:
		return "---"
	case *ast.LinkReferenceDefinition:
		return "" // GitHub shows none (Markdown's own "comment": [//]: # (…))
	case *ast.FencedCodeBlock:
		return mdwrite.Fence(w.lines(n), string(n.Language(w.src)))
	case *ast.CodeBlock:
		return mdwrite.Fence(w.lines(n), "")
	case *ast.Blockquote:
		return mdwrite.Quote(w.blocks(n, "\n\n"))
	case *ast.List:
		return w.list(n)
	case *ast.HTMLBlock:
		raw := w.lines(n)
		if n.HasClosure() {
			raw += string(n.ClosureLine.Value(w.src))
		}
		return w.html(raw, false)
	case *east.Table:
		return w.table(n)
	}
	if n.FirstChild() != nil {
		return w.blocks(n, "\n\n")
	}
	return mdwrite.Escape(w.lines(n))
}

func (w *mdWriter) lines(n ast.Node) string {
	var b strings.Builder
	for i := range n.Lines().Len() {
		seg := n.Lines().At(i)
		b.Write(seg.Value(w.src))
	}
	return b.String()
}

func (w *mdWriter) list(l *ast.List) string {
	// Two lists in a row stay two: the second with the other marker.
	mark := "-"
	if p, ok := l.PreviousSibling().(*ast.List); ok && p.IsOrdered() == l.IsOrdered() && p.Marker == l.Marker {
		mark = "*"
	}
	sep := "\n\n"
	if l.IsTight {
		sep = "\n"
	}
	var items []string
	i := 0
	for it := l.FirstChild(); it != nil && !w.hidden; it = it.NextSibling() {
		m := mark + " "
		if l.IsOrdered() {
			end := "."
			if mark == "*" {
				end = ")"
			}
			m = fmt.Sprintf("%d%s ", l.Start+i, end)
		}
		body := w.blocks(it, sep)
		items = append(items, m+mdwrite.Indent(body, strings.Repeat(" ", len(m))))
		i++
	}
	return strings.Join(items, sep)
}

func (w *mdWriter) table(t *east.Table) string {
	var rows []string
	for r := t.FirstChild(); r != nil && !w.hidden; r = r.NextSibling() {
		var cells []string
		for c := r.FirstChild(); c != nil; c = c.NextSibling() {
			w.cell = true
			cells = append(cells, strings.ReplaceAll(strings.ReplaceAll(w.inline(c), "\n", " "), "|", `\|`))
			w.cell = false
		}
		rows = append(rows, "| "+strings.Join(cells, " | ")+" |")
		if _, ok := r.(*east.TableHeader); ok {
			var line []string
			for _, a := range t.Alignments {
				switch a {
				case east.AlignLeft:
					line = append(line, ":---")
				case east.AlignRight:
					line = append(line, "---:")
				case east.AlignCenter:
					line = append(line, ":---:")
				default:
					line = append(line, "---")
				}
			}
			rows = append(rows, "| "+strings.Join(line, " | ")+" |")
		}
	}
	return strings.Join(rows, "\n")
}

// inline writes a node's inlines.
func (w *mdWriter) inline(parent ast.Node) string {
	var b strings.Builder
	for n := parent.FirstChild(); n != nil && !w.hidden; n = n.NextSibling() {
		b.WriteString(w.span(n))
	}
	return b.String()
}

func (w *mdWriter) span(n ast.Node) string {
	switch n := n.(type) {
	case *ast.Text:
		s := mdwrite.Escape(string(n.Segment.Value(w.src)))
		switch {
		case n.HardLineBreak() && !w.cell:
			s += "\\\n"
		case n.SoftLineBreak() || n.HardLineBreak():
			s += "\n"
		}
		return s
	case *ast.String:
		return mdwrite.Escape(string(n.Value))
	case *ast.CodeSpan:
		var b strings.Builder
		for c := n.FirstChild(); c != nil; c = c.NextSibling() {
			if t, ok := c.(*ast.Text); ok {
				b.Write(t.Segment.Value(w.src))
			}
		}
		return mdwrite.Code(b.String())
	case *ast.Emphasis:
		m := strings.Repeat("*", n.Level)
		return m + w.inline(n) + m
	case *east.Strikethrough:
		return "~~" + w.inline(n) + "~~"
	case *east.TaskCheckBox:
		if n.IsChecked {
			return "[x] "
		}
		return "[ ] "
	case *ast.Link:
		return link(w.inline(n), string(n.Destination))
	case *ast.Image:
		return image(plain(n, w.src), string(n.Destination))
	case *ast.AutoLink:
		u := string(n.URL(w.src))
		if n.AutoLinkType == ast.AutoLinkEmail && !strings.HasPrefix(u, "mailto:") {
			u = "mailto:" + u
		}
		return link(mdwrite.Escape(string(n.Label(w.src))), u)
	case *ast.RawHTML:
		var b strings.Builder
		for i := range n.Segments.Len() {
			seg := n.Segments.At(i)
			b.Write(seg.Value(w.src))
		}
		return w.html(b.String(), true)
	}
	return w.inline(n)
}

// link is a link to href around text (Markdown already), or text alone
// when href isn't http, https or mailto.
func link(text, href string) string {
	if !mdwrite.SafeLink(href) {
		return text
	}
	return "[" + text + "](" + mdwrite.Dest(href) + ")"
}

// image is an image of src (http or https only) with alt text, else its
// alt text.
func image(alt, src string) string {
	if !mdwrite.SafeImage(src) {
		return mdwrite.Escape(alt)
	}
	return "![" + mdwrite.Escape(alt) + "](" + mdwrite.Dest(src) + ")"
}

// plain is a node's text without its marks (an image's alt text).
func plain(n ast.Node, src []byte) string {
	var b strings.Builder
	_ = ast.Walk(n, func(c ast.Node, entering bool) (ast.WalkStatus, error) {
		if t, ok := c.(*ast.Text); ok && entering {
			b.Write(t.Segment.Value(src))
		}
		return ast.WalkContinue, nil
	})
	return b.String()
}

// html writes raw HTML as what it shows: comments gone (and the rest of
// the page with one that never closes), <img> an image, <a href> a link
// around what it holds (inline, the tags come one at a time), <br> a line
// break (a space in an HTML block or a table's cell), any other tag
// nothing, the text between them escaped.
func (w *mdWriter) html(raw string, inline bool) string {
	raw = commentRE.ReplaceAllString(raw, "")
	if i := strings.Index(raw, "<!--"); i >= 0 {
		raw, w.hidden = raw[:i], true
	}
	var b strings.Builder
	at := 0
	text := func(s string) {
		s = html.UnescapeString(s)
		if !inline {
			s = strings.Join(strings.Fields(s), " ")
		}
		b.WriteString(mdwrite.Escape(s))
	}
	for _, m := range tagRE.FindAllStringSubmatchIndex(raw, -1) {
		text(raw[at:m[0]])
		at = m[1]
		closing, name, attrsAt := raw[m[2]:m[3]] == "/", strings.ToLower(raw[m[4]:m[5]]), raw[m[6]:m[7]]
		a := attrs(attrsAt)
		switch {
		case name == "img" && a["src"] != "":
			b.WriteString(image(a["alt"], a["src"]))
		case name == "a" && !closing:
			href := a["href"]
			if !mdwrite.SafeLink(href) {
				href = "" // no link: its text alone
			}
			w.hrefs = append(w.hrefs, href)
			if href != "" {
				b.WriteString("[")
			}
		case name == "a" && len(w.hrefs) > 0:
			href := w.hrefs[len(w.hrefs)-1]
			w.hrefs = w.hrefs[:len(w.hrefs)-1]
			if href != "" {
				b.WriteString("](" + mdwrite.Dest(href) + ")")
			}
		case name == "br" && inline && !w.cell:
			b.WriteString("\\\n")
		case !inline || name == "br":
			b.WriteString(" ")
		}
	}
	text(raw[at:])
	if inline {
		return b.String()
	}
	w.hrefs = nil // a block's links end with it
	return strings.TrimSpace(strings.Join(strings.Fields(b.String()), " "))
}

// attrs are a tag's src, alt and href, unquoted and unescaped.
func attrs(tag string) map[string]string {
	out := map[string]string{}
	for _, m := range attrRE.FindAllStringSubmatch(tag, -1) {
		out[strings.ToLower(m[1])] = html.UnescapeString(strings.Trim(m[2], `"'`))
	}
	return out
}

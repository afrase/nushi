package githubapi

import (
	"fmt"
	"strings"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/extension"
	east "github.com/yuin/goldmark/extension/ast"
	"github.com/yuin/goldmark/text"
	xhtml "golang.org/x/net/html"

	"github.com/afrase/nushi/internal/mdwrite"
)

// gfm parses as GitHub does: CommonMark with GitHub's extensions, so a
// fence, a code span, an HTML block or comment and a table's cells begin
// and end where GitHub's do.
var gfm = goldmark.New(goldmark.WithExtensions(extension.GFM))

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
	// skip is the hidden element (<script>, <style>…) whose contents are
	// being passed over, until its end tag.
	skip string
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
	if _, ok := n.(*ast.HTMLBlock); w.skip != "" && !ok && !hasRaw(n) {
		return "" // inside a <script> or <style> left open: none of it shows
	}
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
	if _, ok := n.(*ast.RawHTML); w.skip != "" && !ok && !hasRaw(n) {
		return ""
	}
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

// hasRaw says n holds raw HTML, which may end a hidden element.
func hasRaw(n ast.Node) bool {
	found := false
	_ = ast.Walk(n, func(c ast.Node, _ bool) (ast.WalkStatus, error) {
		switch c.(type) {
		case *ast.RawHTML, *ast.HTMLBlock:
			found = true
			return ast.WalkStop, nil
		}
		return ast.WalkContinue, nil
	})
	return found
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

// hiddenElements are the elements whose contents a page doesn't show
// (GitHub's sanitizer drops them with what they hold).
var hiddenElements = map[string]bool{"script": true, "style": true, "template": true, "noscript": true,
	"textarea": true, "title": true, "iframe": true, "object": true}

// html writes raw HTML as what it shows, read as a browser reads it
// (x/net/html's tokenizer): comments gone (and the rest of the page with
// one that never closes), hidden elements' contents gone, <img> an image,
// <a href> a link around what it holds (inline, the tags come one at a
// time), <br> a line break (a space in an HTML block or a table's cell),
// any other tag nothing, the text between them escaped.
func (w *mdWriter) html(raw string, inline bool) string {
	var b strings.Builder
	z := xhtml.NewTokenizer(strings.NewReader(raw))
	for {
		tt := z.Next()
		switch tt {
		case xhtml.ErrorToken:
			if inline {
				return b.String()
			}
			w.hrefs = nil // a block's links end with it
			return strings.Join(strings.Fields(b.String()), " ")
		case xhtml.CommentToken:
			if !closed(string(z.Raw())) {
				w.hidden = true
			}
		case xhtml.TextToken:
			if w.skip == "" {
				t := string(z.Text())
				if !inline {
					t = " " + strings.Join(strings.Fields(t), " ") + " "
				}
				b.WriteString(mdwrite.Escape(t))
			}
		case xhtml.StartTagToken, xhtml.SelfClosingTagToken:
			w.start(&b, z, inline)
		case xhtml.EndTagToken:
			w.end(&b, z, inline)
		case xhtml.DoctypeToken:
		}
		if w.hidden {
			return strings.TrimSpace(b.String())
		}
	}
}

// start writes what a start tag shows, or starts passing over a hidden
// element.
func (w *mdWriter) start(b *strings.Builder, z *xhtml.Tokenizer, inline bool) {
	name, a := tag(z)
	switch {
	case w.skip != "":
	case hiddenElements[name]: // a browser ignores "/>" on them: they still open
		w.skip = name
	case name == "img":
		b.WriteString(image(a["alt"], a["src"]))
	case name == "a":
		href := a["href"]
		if !mdwrite.SafeLink(href) {
			href = "" // no link: its text alone
		}
		w.hrefs = append(w.hrefs, href)
		if href != "" {
			b.WriteString("[")
		}
	case name == "br" && inline && !w.cell:
		b.WriteString("\\\n")
	case name == "br" || !inline:
		b.WriteString(" ")
	}
}

// end writes what an end tag shows, or ends passing over a hidden
// element.
func (w *mdWriter) end(b *strings.Builder, z *xhtml.Tokenizer, inline bool) {
	name, _ := tag(z)
	switch {
	case w.skip != "":
		if name == w.skip {
			w.skip = ""
		}
	case name == "a" && len(w.hrefs) > 0:
		href := w.hrefs[len(w.hrefs)-1]
		w.hrefs = w.hrefs[:len(w.hrefs)-1]
		if href != "" {
			b.WriteString("](" + mdwrite.Dest(href) + ")")
		}
	case !inline:
		b.WriteString(" ")
	}
}

// closed says a comment's raw text ends it, as a browser reads it; one
// that doesn't runs to the end of the page.
func closed(raw string) bool {
	if !strings.HasPrefix(raw, "<!--") {
		return strings.HasSuffix(raw, ">") // a bogus comment, <!x> or <?x>, ends at the first >
	}
	return raw == "<!-->" || raw == "<!--->" || strings.HasSuffix(raw, "-->") || strings.HasSuffix(raw, "--!>")
}

// tag is the tag the tokenizer is on: its name, and its src, alt and
// href.
func tag(z *xhtml.Tokenizer) (string, map[string]string) {
	name, more := z.TagName()
	a := map[string]string{}
	for more {
		var k, v []byte
		k, v, more = z.TagAttr()
		if key := string(k); key == "src" || key == "alt" || key == "href" {
			if _, seen := a[key]; !seen { // a browser takes the first
				a[key] = string(v)
			}
		}
	}
	return string(name), a
}

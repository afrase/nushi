package githubapi

import (
	"bytes"
	"cmp"
	"regexp"
	"strconv"
	"strings"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/extension"
	gmhtml "github.com/yuin/goldmark/renderer/html"
	xhtml "golang.org/x/net/html"
	"golang.org/x/net/html/atom"

	"github.com/afrase/nushi/internal/mdwrite"
)

// GitHub's text goes through what GitHub's own page does with it, then
// is written again from what that leaves: Markdown to HTML as GitHub's
// renderer makes it (CommonMark with GitHub's extensions; goldmark here),
// GFM's tag filter, the HTML read as a browser reads it (x/net/html's
// parser: nesting, implied end tags, comments that never close), and a
// walk of the tree that writes what the page shows, as Markdown.

// gfm renders as GitHub's renderer does: GFM, raw HTML kept (GitHub's
// sanitizer, not the renderer, decides what of it shows).
var gfm = goldmark.New(goldmark.WithExtensions(extension.GFM), goldmark.WithRendererOptions(gmhtml.WithUnsafe()))

// tagFilterRE is GFM's tag filter, which GitHub applies: raw HTML naming
// one of these elements is written as text (GitHub's page shows
// "<script>…" as it was typed).
var tagFilterRE = regexp.MustCompile(`(?i)<(/?(?:title|textarea|style|xmp|iframe|noembed|noframes|script|plaintext))([\s/>]|$)`)

// GitHub's sanitizer (html-pipeline's SanitizationFilter, its ALLOWLIST:
// the elements GitHub keeps) is the model: an element it keeps is written
// as what it is (a heading, a list, a link…); one it doesn't keep is
// unwrapped, its text kept, as GitHub does; a script goes with what it
// holds (its remove_contents), and so do comments, doctypes and
// processing instructions. Links keep only http, https and mailto, and
// images only http and https (stricter than GitHub's schemes): else
// their text.
var blockElements = map[atom.Atom]bool{
	atom.P: true, atom.Div: true, atom.H1: true, atom.H2: true, atom.H3: true, atom.H4: true, atom.H5: true, atom.H6: true,
	atom.Pre: true, atom.Blockquote: true, atom.Ol: true, atom.Ul: true, atom.Li: true, atom.Table: true, atom.Hr: true,
	atom.Dl: true, atom.Dt: true, atom.Dd: true, atom.Details: true, atom.Summary: true, atom.Figure: true,
	atom.Figcaption: true, atom.Caption: true,
}

// removed are the elements whose contents GitHub drops with them.
var removed = map[atom.Atom]bool{atom.Script: true}

// Markdown is GitHub-flavoured Markdown from GitHub (a pull request's
// text, a comment, a check's summary) as Nushi shows it and gives it to an
// agent: what GitHub's page shows of it, written again as Markdown. What
// the page hides isn't written: HTML comments (a template's notes, or
// text meant for an agent and not for the reader), everything after a
// comment that never closes, link reference definitions, a table's cells
// past the header's, scripts. Text is escaped, so none of it reads as
// Markdown it wasn't; an image is the app's to show as a link, never
// fetched.
func Markdown(s string) string {
	var page bytes.Buffer
	if err := gfm.Convert([]byte(strings.ReplaceAll(s, "\r\n", "\n")), &page); err != nil {
		return mdwrite.Escape(s) // goldmark fails only on a failing writer
	}
	filtered := tagFilterRE.ReplaceAllString(page.String(), "&lt;$1$2")
	nodes, err := xhtml.ParseFragment(strings.NewReader(filtered), &xhtml.Node{Type: xhtml.ElementNode, DataAtom: atom.Body, Data: "body"})
	if err != nil {
		return ""
	}
	return strings.TrimSpace((&mdWriter{}).blocks(nodes))
}

type mdWriter struct {
	cell bool // writing a table's cell: no line breaks
}

// isBlock says n is written as a block: a block element, or one GitHub
// unwraps that holds one.
func isBlock(n *xhtml.Node) bool {
	if n.Type != xhtml.ElementNode || removed[n.DataAtom] {
		return false
	}
	if blockElements[n.DataAtom] {
		return true
	}
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		if isBlock(c) {
			return true
		}
	}
	return false
}

func children(n *xhtml.Node) []*xhtml.Node {
	var out []*xhtml.Node
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		out = append(out, c)
	}
	return out
}

// blocks writes nodes as blocks: each block element as itself, the
// inline nodes between them as paragraphs, a blank line between.
func (w *mdWriter) blocks(ns []*xhtml.Node) string { return w.blocksSep(ns, "\n\n") }

// blocksSep is blocks with sep between them (a tight list item's: a line
// break).
func (w *mdWriter) blocksSep(ns []*xhtml.Node, sep string) string {
	var parts []string
	var run []*xhtml.Node
	var prev *xhtml.Node // the block written last, for lists in a row
	flush := func() {
		if t := strings.TrimSpace(w.inline(run)); t != "" {
			parts, prev = append(parts, t), nil
		}
		run = nil
	}
	for _, n := range ns {
		if !isBlock(n) {
			run = append(run, n)
			continue
		}
		flush()
		if b := w.block(n, prev); b != "" {
			parts, prev = append(parts, b), n
		}
	}
	flush()
	return strings.Join(parts, sep)
}

func (w *mdWriter) block(n, prev *xhtml.Node) string {
	switch n.DataAtom {
	case atom.H1, atom.H2, atom.H3, atom.H4, atom.H5, atom.H6:
		level, _ := strconv.Atoi(n.Data[1:])
		return strings.Repeat("#", level) + " " + oneLine(w.inline(children(n)))
	case atom.Hr:
		return "---"
	case atom.Pre:
		return mdwrite.Fence(text(n), language(n))
	case atom.Blockquote:
		return mdwrite.Quote(w.blocks(children(n)))
	case atom.Ul, atom.Ol:
		return w.list(n, prev != nil && prev.DataAtom == n.DataAtom)
	case atom.Table:
		return w.table(n)
	default: // p, div, li astray, details, summary, and what GitHub unwraps
		return w.blocks(children(n))
	}
}

// language is a code block's language, from its code's class.
func language(pre *xhtml.Node) string {
	for c := pre.FirstChild; c != nil; c = c.NextSibling {
		if c.DataAtom == atom.Code {
			for cl := range strings.FieldsSeq(attr(c, "class")) {
				if l, ok := strings.CutPrefix(cl, "language-"); ok {
					return l
				}
			}
		}
	}
	return ""
}

// text is what n holds as text, as a code block shows it (no comments).
func text(n *xhtml.Node) string {
	var b strings.Builder
	var walk func(*xhtml.Node)
	walk = func(n *xhtml.Node) {
		switch {
		case n.Type == xhtml.TextNode:
			b.WriteString(n.Data)
		case n.Type == xhtml.ElementNode && removed[n.DataAtom]:
		case n.DataAtom == atom.Br:
			b.WriteString("\n")
		default:
			for c := n.FirstChild; c != nil; c = c.NextSibling {
				walk(c)
			}
		}
	}
	walk(n)
	return b.String()
}

func attr(n *xhtml.Node, key string) string {
	for _, a := range n.Attr {
		if a.Key == key && a.Namespace == "" {
			return a.Val
		}
	}
	return ""
}

func hasAttr(n *xhtml.Node, key string) bool {
	for _, a := range n.Attr {
		if a.Key == key {
			return true
		}
	}
	return false
}

func oneLine(s string) string { return strings.Join(strings.Fields(s), " ") }

func (w *mdWriter) list(l *xhtml.Node, again bool) string {
	ordered := l.DataAtom == atom.Ol
	start, err := strconv.Atoi(attr(l, "start"))
	if err != nil {
		start = 1
	}
	mark, end := "-", "."
	if again { // two lists in a row stay two: the second with the other marker
		mark, end = "*", ")"
	}
	var items []string
	loose := false
	for _, it := range children(l) {
		for _, c := range children(it) {
			loose = loose || c.DataAtom == atom.P
		}
	}
	sep := "\n"
	if loose {
		sep = "\n\n"
	}
	for _, it := range children(l) {
		if it.Type == xhtml.TextNode && strings.TrimSpace(it.Data) == "" {
			continue
		}
		m := mark + " "
		if ordered {
			m = strconv.Itoa(start+len(items)) + end + " "
		}
		parts := []*xhtml.Node{it}
		if it.DataAtom == atom.Li {
			parts = children(it)
		}
		parts, box := taskBox(parts)
		body := box + w.blocksSep(parts, sep)
		items = append(items, m+mdwrite.Indent(body, strings.Repeat(" ", len(m))))
	}
	return strings.Join(items, sep)
}

// taskBox takes a task list item's box (its first element, a checkbox)
// out of its nodes, as Markdown's "[x] " or "[ ] ".
func taskBox(parts []*xhtml.Node) ([]*xhtml.Node, string) {
	for i, c := range parts {
		if c.DataAtom == atom.Input && attr(c, "type") == "checkbox" {
			box := "[ ] "
			if hasAttr(c, "checked") {
				box = "[x] "
			}
			return append(parts[:i:i], parts[i+1:]...), box
		}
		if c.Type != xhtml.TextNode || strings.TrimSpace(c.Data) != "" {
			break // a box comes first
		}
	}
	return parts, ""
}

func (w *mdWriter) table(t *xhtml.Node) string {
	var rows [][]string
	var aligns []string
	var walk func(*xhtml.Node)
	walk = func(n *xhtml.Node) {
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			switch c.DataAtom {
			case atom.Thead, atom.Tbody, atom.Tfoot:
				walk(c)
			case atom.Tr:
				var cells []string
				for cell := c.FirstChild; cell != nil; cell = cell.NextSibling {
					if cell.DataAtom != atom.Td && cell.DataAtom != atom.Th {
						continue
					}
					w.cell = true
					cells = append(cells, strings.ReplaceAll(oneLine(w.inline(children(cell))), "|", `\|`))
					w.cell = false
					if len(rows) == 0 {
						aligns = append(aligns, cmp.Or(attr(cell, "align"), attr(cell, "style")))
					}
				}
				rows = append(rows, cells)
			default: // what isn't a row (a caption)
			}
		}
	}
	walk(t)
	if len(rows) == 0 || len(rows[0]) == 0 {
		return ""
	}
	width := len(rows[0])
	line := make([]string, width)
	for i, a := range aligns {
		switch {
		case strings.Contains(a, "center"):
			line[i] = ":---:"
		case strings.Contains(a, "right"):
			line[i] = "---:"
		case strings.Contains(a, "left"):
			line[i] = ":---"
		default:
			line[i] = "---"
		}
	}
	out := make([]string, 0, len(rows)+1)
	for i, r := range rows {
		r = append(r, make([]string, max(0, width-len(r)))...)
		out = append(out, "| "+strings.Join(r[:width], " | ")+" |")
		if i == 0 {
			out = append(out, "| "+strings.Join(line, " | ")+" |")
		}
	}
	return strings.Join(out, "\n")
}

// inline writes nodes as a paragraph's text.
func (w *mdWriter) inline(ns []*xhtml.Node) string {
	var b strings.Builder
	for _, n := range ns {
		s := w.span(n)
		if strings.HasSuffix(b.String(), " ") { // one space, as the page lays it out
			s = strings.TrimLeft(s, " ")
		}
		b.WriteString(s)
	}
	return b.String()
}

func (w *mdWriter) span(n *xhtml.Node) string {
	switch n.Type {
	case xhtml.TextNode:
		return mdwrite.Escape(collapse(n.Data))
	case xhtml.ElementNode:
	default:
		return "" // comments, doctypes
	}
	inner := func() string { return w.inline(children(n)) }
	switch n.DataAtom {
	case atom.Script, atom.Input:
		return ""
	case atom.Br:
		if w.cell {
			return " "
		}
		return "\\\n"
	case atom.B, atom.Strong:
		return around("**", inner())
	case atom.I, atom.Em:
		return around("*", inner())
	case atom.Del, atom.S, atom.Strike:
		return around("~~", inner())
	case atom.Code, atom.Tt, atom.Kbd, atom.Samp:
		if t := text(n); t != "" {
			return mdwrite.Code(t)
		}
		return ""
	case atom.A:
		return link(inner(), attr(n, "href"))
	case atom.Img:
		return image(alt(attr(n, "alt")), attr(n, "src"))
	default:
		if blockElements[n.DataAtom] {
			return " " + inner() + " " // a block inside a line (a <p> in a <span>)
		}
		return inner() // what GitHub unwraps, and the inline elements it keeps as they are
	}
}

// collapse is text as a page lays it out: each run of white space one
// space.
func collapse(s string) string {
	var b strings.Builder
	space := false
	for _, r := range s {
		if r == ' ' || r == '\t' || r == '\n' || r == '\r' || r == '\f' {
			if !space {
				b.WriteByte(' ')
			}
			space = true
			continue
		}
		space = false
		b.WriteRune(r)
	}
	return b.String()
}

// around puts a mark around text (its spaces outside, where Markdown
// needs them), or is the text as it is when it's only space.
func around(mark, s string) string {
	t := strings.TrimSpace(s)
	if t == "" {
		return s
	}
	i := strings.Index(s, t)
	return s[:i] + mark + t + mark + s[i+len(t):]
}

// alt is an image's alt text as Nushi shows it (as the image's link):
// its text without anything that reads as markup (a tag, a comment), each
// such piece a space, so no comment or tag in it is shown, or given to an
// agent, as text.
func alt(s string) string {
	z := xhtml.NewTokenizer(strings.NewReader(s))
	var b strings.Builder
	for {
		switch z.Next() {
		case xhtml.ErrorToken:
			return oneLine(b.String())
		case xhtml.TextToken:
			b.Write(z.Text())
		default:
			b.WriteByte(' ')
		}
	}
}

// link is a link to href around text (Markdown already), or text alone
// when href isn't http, https or mailto, or there's no text.
func link(text, href string) string {
	if !mdwrite.SafeLink(href) || strings.TrimSpace(text) == "" {
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

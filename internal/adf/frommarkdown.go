package adf

import (
	"reflect"
	"strconv"
	"strings"

	"github.com/yuin/goldmark"
	gast "github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/extension"
	east "github.com/yuin/goldmark/extension/ast"
	"github.com/yuin/goldmark/text"
	"github.com/yuin/goldmark/util"
)

var md = goldmark.New(goldmark.WithExtensions(extension.Table, extension.Strikethrough, extension.TaskList, extension.Linkify))

// FromMarkdown turns Markdown (CommonMark with GitHub's tables, task
// lists, strikethrough and bare links) into an ADF document Jira takes. A
// line break is a line break, as in a comment box. What ADF can't hold
// (an image by URL, HTML) stays as its text.
func FromMarkdown(src string) Node {
	source := []byte(src)
	r := reader{src: source}
	return document(r.blocks(md.Parser().Parse(text.NewReader(source)))...)
}

type reader struct {
	src []byte
}

func (r reader) blocks(parent gast.Node) []Node {
	var out []Node
	for c := parent.FirstChild(); c != nil; c = c.NextSibling() {
		out = append(out, r.block(c)...)
	}
	return out
}

func (r reader) block(n gast.Node) []Node {
	switch n := n.(type) {
	case *gast.Paragraph, *gast.TextBlock:
		return []Node{{Type: "paragraph", Content: r.inline(n, nil)}}
	case *gast.Heading:
		return []Node{{Type: "heading", Attrs: map[string]any{"level": n.Level}, Content: r.inline(n, nil)}}
	case *gast.ThematicBreak:
		return []Node{{Type: "rule"}}
	case *gast.FencedCodeBlock:
		cb := Node{Type: "codeBlock", Content: textNodes(strings.TrimSuffix(r.lines(n), "\n"))}
		if lang := string(n.Language(r.src)); lang != "" {
			cb.Attrs = map[string]any{"language": lang}
		}
		return []Node{cb}
	case *gast.CodeBlock:
		return []Node{{Type: "codeBlock", Content: textNodes(strings.TrimSuffix(r.lines(n), "\n"))}}
	case *gast.HTMLBlock:
		return []Node{{Type: "paragraph", Content: textNodes(strings.TrimSuffix(r.lines(n), "\n"))}}
	case *gast.Blockquote:
		return []Node{{Type: "blockquote", Content: quotable(r.blocks(n))}}
	case *gast.List:
		return []Node{r.list(n)}
	case *east.Table:
		return []Node{r.table(n)}
	}
	return r.blocks(n) // a node goldmark adds later: its children
}

// quotable keeps to what ADF lets a quote hold: no quote in a quote (its
// blocks join this one), no heading (a bold paragraph).
func quotable(blocks []Node) []Node {
	var out []Node
	for _, b := range blocks {
		switch b.Type {
		case "blockquote":
			out = append(out, quotable(b.Content)...)
		case "heading":
			out = append(out, Node{Type: "paragraph", Content: withMark(b.Content, Mark{Type: "strong"})})
		case "rule", "table":
			out = append(out, Node{Type: "paragraph", Content: textNodes(ToMarkdown(document(b), nil))})
		default:
			out = append(out, b)
		}
	}
	return out
}

func (r reader) list(n *gast.List) Node {
	if tasks := r.tasks(n); tasks != nil {
		return *tasks
	}
	l := Node{Type: "bulletList"}
	if n.IsOrdered() {
		l = Node{Type: "orderedList", Attrs: map[string]any{"order": max(n.Start, 1)}}
	}
	for it := n.FirstChild(); it != nil; it = it.NextSibling() {
		item := Node{Type: "listItem", Content: r.blocks(it)}
		if len(item.Content) == 0 || item.Content[0].Type != "paragraph" {
			item.Content = append([]Node{{Type: "paragraph"}}, item.Content...)
		}
		l.Content = append(l.Content, item)
	}
	return l
}

// tasks makes a list whose every item starts with a box ("- [x] …") an
// ADF task list; nil for any other list.
func (r reader) tasks(n *gast.List) *Node {
	l := Node{Type: "taskList", Attrs: map[string]any{"localId": "list"}}
	i := 0
	for it := n.FirstChild(); it != nil; it = it.NextSibling() {
		first := it.FirstChild()
		if first == nil || first.FirstChild() == nil || first.NextSibling() != nil {
			return nil
		}
		box, ok := first.FirstChild().(*east.TaskCheckBox)
		if !ok {
			return nil
		}
		state := "TODO"
		if box.IsChecked {
			state = "DONE"
		}
		first.RemoveChild(first, box)
		i++
		id := strconv.Itoa(i)
		l.Content = append(l.Content, Node{Type: "taskItem", Attrs: map[string]any{"localId": id, "state": state}, Content: trimStart(r.inline(first, nil))})
	}
	return &l
}

func (r reader) table(t *east.Table) Node {
	tbl := Node{Type: "table", Attrs: map[string]any{"isNumberColumnEnabled": false, "layout": "default"}}
	for row := t.FirstChild(); row != nil; row = row.NextSibling() {
		kind := "tableCell"
		if _, ok := row.(*east.TableHeader); ok {
			kind = "tableHeader"
		}
		tr := Node{Type: "tableRow"}
		for c := row.FirstChild(); c != nil; c = c.NextSibling() {
			tr.Content = append(tr.Content, Node{Type: kind, Content: []Node{{Type: "paragraph", Content: r.inline(c, nil)}}})
		}
		tbl.Content = append(tbl.Content, tr)
	}
	return tbl
}

// inline makes ADF text of a node's inline children, each with marks and
// what its own inlines add.
func (r reader) inline(parent gast.Node, marks []Mark) []Node {
	var out []Node
	for c := parent.FirstChild(); c != nil; c = c.NextSibling() {
		switch c := c.(type) {
		case *gast.Text:
			v := c.Segment.Value(r.src)
			if !c.IsRaw() { // as goldmark writes it: escapes and entities read
				v = util.ResolveEntityNames(util.ResolveNumericReferences(util.UnescapePunctuations(v)))
			}
			out = append(out, textNode(string(v), marks)...)
			if c.HardLineBreak() || c.SoftLineBreak() {
				out = append(out, Node{Type: "hardBreak"})
			}
		case *gast.String:
			out = append(out, textNode(string(c.Value), marks)...)
		case *gast.CodeSpan:
			out = append(out, textNode(r.codeText(c), codeMarks(marks))...)
		case *gast.Emphasis:
			m := Mark{Type: "em"}
			if c.Level >= 2 {
				m.Type = "strong"
			}
			out = append(out, r.inline(c, append(marks, m))...)
		case *east.Strikethrough:
			out = append(out, r.inline(c, append(marks, Mark{Type: "strike"}))...)
		case *gast.Link:
			out = append(out, r.inline(c, append(marks, linkMark(string(c.Destination))))...)
		case *gast.AutoLink:
			out = append(out, textNode(string(c.Label(r.src)), append(marks, linkMark(r.autoURL(c))))...)
		case *gast.Image: // ADF's media must be Atlassian's: the alt text, linked
			out = append(out, r.inline(c, append(marks, linkMark(string(c.Destination))))...)
		case *gast.RawHTML:
			out = append(out, textNode(r.segments(c.Segments), marks)...)
		case *east.TaskCheckBox: // in a list that isn't all tasks
			box := "[ ] "
			if c.IsChecked {
				box = "[x] "
			}
			out = append(out, textNode(box, marks)...)
		default:
			out = append(out, r.inline(c, marks)...)
		}
	}
	if n := len(out); n > 0 && out[n-1].Type == "hardBreak" {
		out = out[:n-1] // a block's last line ends it
	}
	return merge(out)
}

// merge joins texts side by side with the same marks: goldmark splits a
// line at what might have been syntax.
func merge(nodes []Node) []Node {
	var out []Node
	for _, n := range nodes {
		if k := len(out) - 1; k >= 0 && n.Type == "text" && out[k].Type == "text" && reflect.DeepEqual(n.Marks, out[k].Marks) {
			out[k].Text += n.Text
			continue
		}
		out = append(out, n)
	}
	return out
}

func (r reader) codeText(c *gast.CodeSpan) string {
	var b strings.Builder
	for t := c.FirstChild(); t != nil; t = t.NextSibling() {
		if t, ok := t.(*gast.Text); ok {
			b.Write(t.Segment.Value(r.src))
		}
	}
	return b.String()
}

func (r reader) autoURL(c *gast.AutoLink) string {
	url := string(c.URL(r.src))
	if c.AutoLinkType == gast.AutoLinkEmail && !strings.HasPrefix(url, "mailto:") {
		url = "mailto:" + url
	}
	return url
}

func (r reader) lines(n gast.Node) string { return r.segments(n.Lines()) }

func (r reader) segments(segs *text.Segments) string {
	var b strings.Builder
	for i := range segs.Len() {
		seg := segs.At(i)
		b.Write(seg.Value(r.src))
	}
	return b.String()
}

func linkMark(href string) Mark {
	return Mark{Type: "link", Attrs: map[string]any{"href": href}}
}

// codeMarks keeps what ADF lets go with code: a link.
func codeMarks(marks []Mark) []Mark {
	out := []Mark{{Type: "code"}}
	for _, m := range marks {
		if m.Type == "link" {
			out = append(out, m)
		}
	}
	return out
}

func textNode(s string, marks []Mark) []Node {
	if s == "" {
		return nil
	}
	return []Node{{Type: "text", Text: s, Marks: dedupe(marks)}}
}

func textNodes(s string) []Node { return textNode(s, nil) }

func withMark(nodes []Node, m Mark) []Node {
	out := make([]Node, len(nodes))
	for i, n := range nodes {
		if n.Type == "text" && !hasMark(n.Marks, "code") {
			n.Marks = dedupe(append(append([]Mark(nil), n.Marks...), m))
		}
		out[i] = n
	}
	return out
}

// dedupe drops a mark given twice (**a *b* c** is strong once); ADF
// refuses that. Nil for none.
func dedupe(marks []Mark) []Mark {
	var out []Mark
	for _, m := range marks {
		if !hasMark(out, m.Type) {
			out = append(out, m)
		}
	}
	return out
}

func hasMark(marks []Mark, t string) bool {
	for _, m := range marks {
		if m.Type == t {
			return true
		}
	}
	return false
}

func trimStart(nodes []Node) []Node {
	if len(nodes) > 0 && nodes[0].Type == "text" {
		nodes[0].Text = strings.TrimLeft(nodes[0].Text, " ")
		if nodes[0].Text == "" {
			nodes = nodes[1:]
		}
	}
	return nodes
}

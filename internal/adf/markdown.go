package adf

import (
	"cmp"
	"strconv"
	"strings"
	"time"
	"unicode"
)

// Media says what a media node (an image or file in the text, named by
// Atlassian's media id, not the attachment's) shows as: its file's name,
// and the link its image or file opens. "" for the link: the name as text.
type Media func(id string) (name, link string)

// ToMarkdown renders an ADF document as Markdown (CommonMark with GitHub's
// tables, task lists and strikethrough). media may be nil.
func ToMarkdown(doc Node, media Media) string {
	w := writer{media: media}
	return w.blocks(doc.Content, "\n\n")
}

type writer struct {
	media Media
	// alt marks a list with "*" or "1)": it follows a list of its kind,
	// which a list marked the same way would join.
	alt bool
}

func listKind(n Node) string {
	switch n.Type {
	case "bulletList", "taskList", "decisionList":
		return "-"
	case "orderedList":
		return "1."
	}
	return ""
}

// blocks renders a run of blocks; inline nodes among them (a taskItem's
// content, a malformed doc) make a paragraph of their own.
func (w writer) blocks(nodes []Node, sep string) string {
	var out []string
	prev, alt := "", false
	for i := 0; i < len(nodes); i++ {
		kind := listKind(nodes[i])
		alt = kind != "" && kind == prev && !alt
		prev = kind
		if !isBlock(nodes[i]) {
			j := i
			for j < len(nodes) && !isBlock(nodes[j]) {
				j++
			}
			out = append(out, w.inline(nodes[i:j]))
			i = j - 1
			continue
		}
		bw := w
		bw.alt = alt
		if s := bw.block(nodes[i]); s != "" {
			out = append(out, s)
		}
	}
	return strings.Join(out, sep)
}

var panels = map[string]string{"info": "Info", "note": "Note", "warning": "Warning", "success": "Success", "error": "Error", "tip": "Tip"}

func (w writer) block(n Node) string {
	switch n.Type {
	case "paragraph":
		return strings.TrimRight(w.inline(n.Content), " ")
	case "heading":
		level, _ := strconv.Atoi(n.attr("level"))
		return strings.Repeat("#", min(max(level, 1), 6)) + " " + w.inline(n.Content)
	case "bulletList", "taskList", "decisionList":
		if w.alt {
			return w.list(n, func(int) string { return "* " })
		}
		return w.list(n, func(int) string { return "- " })
	case "orderedList":
		start, err := strconv.Atoi(n.attr("order"))
		if err != nil {
			start = 1
		}
		delim := ". "
		if w.alt {
			delim = ") "
		}
		return w.list(n, func(i int) string { return strconv.Itoa(start+i) + delim })
	case "codeBlock":
		return fence(textOf(n), n.attr("language"))
	case "blockquote":
		return quote(w.blocks(n.Content, "\n\n"))
	case "panel":
		body := w.blocks(n.Content, "\n\n")
		if label := panels[n.attr("panelType")]; label != "" {
			body = "**" + label + ":** " + body
		}
		return quote(body)
	case "rule":
		return "---"
	case "table":
		return w.table(n)
	case "mediaSingle", "mediaGroup":
		var out []string
		for _, m := range n.Content {
			out = append(out, w.mediaRef(m))
		}
		return strings.Join(out, " ")
	case "expand", "nestedExpand":
		return "**" + escape(cmp.Or(n.attr("title"), "Details")) + "**\n\n" + w.blocks(n.Content, "\n\n")
	case "blockCard", "embedCard":
		return link(n.attr("url"), n.attr("url"))
	}
	return w.unknown(n, true)
}

// unknown degrades a node Nushi doesn't know: its content, its text, or
// its type in brackets.
func (w writer) unknown(n Node, block bool) string {
	switch {
	case len(n.Content) > 0 && block:
		return w.blocks(n.Content, "\n\n")
	case len(n.Content) > 0:
		return w.inline(n.Content)
	case n.Text != "":
		return escape(n.Text)
	case n.attr("text") != "":
		return escape(n.attr("text"))
	}
	return "\\[" + escape(cmp.Or(n.attr("extensionKey"), n.Type)) + "\\]"
}

// list renders a list's items, each after its marker, what follows the
// first line indented under it.
func (w writer) list(n Node, marker func(int) string) string {
	inner := w
	inner.alt = false // for the lists in it
	var items []string
	for i, it := range n.Content {
		m := marker(i)
		var body string
		switch it.Type {
		case "taskItem":
			box := "[ ] "
			if it.attr("state") == "DONE" {
				box = "[x] "
			}
			m += box
			body = inner.blocks(it.Content, "\n")
		case "decisionItem":
			m += "✔ "
			body = inner.blocks(it.Content, "\n")
		case "taskList", "bulletList", "orderedList", "decisionList": // nested without an item
			items = append(items, indent(inner.block(it), "  "))
			continue
		default:
			body = inner.itemBody(it.Content)
		}
		items = append(items, m+indent(body, strings.Repeat(" ", len(m))))
	}
	return strings.Join(items, "\n")
}

// itemBody keeps a list item tight: a nested list right under its line.
func (w writer) itemBody(nodes []Node) string {
	var b strings.Builder
	for i, c := range nodes {
		if i > 0 {
			if strings.HasSuffix(c.Type, "List") {
				b.WriteString("\n")
			} else {
				b.WriteString("\n\n")
			}
		}
		b.WriteString(w.block(c))
	}
	return b.String()
}

func (w writer) table(n Node) string {
	var rows [][]string
	width := 0
	for _, r := range n.Content {
		var cells []string
		for _, c := range r.Content {
			cells = append(cells, w.cell(c))
		}
		width = max(width, len(cells))
		rows = append(rows, cells)
	}
	if width == 0 {
		return ""
	}
	var b strings.Builder
	for i, r := range rows {
		for len(r) < width {
			r = append(r, "")
		}
		b.WriteString("| " + strings.Join(r, " | ") + " |\n")
		if i == 0 { // GitHub's tables need a header: the first row is it
			b.WriteString("|" + strings.Repeat(" --- |", width) + "\n")
		}
	}
	return strings.TrimSuffix(b.String(), "\n")
}

// cell flattens a table cell's blocks onto one line.
func (w writer) cell(c Node) string {
	var parts []string
	for _, b := range c.Content {
		if strings.HasSuffix(b.Type, "List") {
			for _, it := range b.Content {
				parts = append(parts, "• "+w.blocks(it.Content, " "))
			}
			continue
		}
		parts = append(parts, w.blocks([]Node{b}, " "))
	}
	s := strings.Join(parts, " ")
	s = strings.ReplaceAll(s, "\\\n", " ")
	s = strings.ReplaceAll(s, "\n", " ")
	return strings.ReplaceAll(s, "|", "\\|")
}

func (w writer) mediaRef(m Node) string {
	name, ref := "", ""
	if w.media != nil {
		name, ref = w.media(m.attr("id"))
	}
	name = cmp.Or(name, m.attr("alt"), "attachment")
	if !strings.HasPrefix(ref, AttachmentScheme) {
		return "\\[" + escape(name) + "\\]"
	}
	return "![" + escape(name) + "](" + dest(ref) + ")"
}

func (w writer) inline(nodes []Node) string {
	var b strings.Builder
	for _, n := range nodes {
		switch n.Type {
		case "text":
			b.WriteString(marked(n))
		case "hardBreak":
			b.WriteString("\\\n")
		case "mention":
			b.WriteString("@" + escape(strings.TrimPrefix(cmp.Or(n.attr("text"), n.attr("id")), "@")))
		case "emoji":
			b.WriteString(emoji(n))
		case "status":
			b.WriteString(code(n.attr("text")))
		case "date":
			b.WriteString(date(n.attr("timestamp")))
		case "inlineCard":
			b.WriteString(link(n.attr("url"), n.attr("url")))
		case "media", "mediaInline":
			b.WriteString(w.mediaRef(n))
		default:
			b.WriteString(w.unknown(n, false))
		}
	}
	return b.String()
}

// atlassianEmoji are Atlassian's own emoji (wiki markup's (/), (x), (!)…),
// which carry their short name as their text.
var atlassianEmoji = map[string]string{"check_mark": "✅", "cross_mark": "❌", "warning": "⚠️", "info": "ℹ️",
	"question": "❓", "light_bulb_on": "💡", "light_bulb_off": "💡", "plus": "➕", "minus": "➖", "flag_on": "🚩", "flag_off": "🏳️",
	"star_yellow": "⭐", "thumbs_up": "👍", "thumbs_down": "👎"}

func emoji(n Node) string {
	if t := n.attr("text"); isEmoji(t) {
		return t
	}
	short := n.attr("shortName")
	if e, ok := atlassianEmoji[strings.Trim(short, ":")]; ok {
		return e
	}
	return escape(short)
}

// isEmoji says text is a few emoji or symbols, nothing Markdown reads.
func isEmoji(text string) bool {
	r := []rune(text)
	if len(r) == 0 || len(r) > 12 {
		return false
	}
	for _, c := range r {
		if !symbol(c) {
			return false
		}
	}
	return true
}

// symbol is a rune emoji are made of: symbols, modifiers, joiners,
// variation selectors, skin tones, tags.
func symbol(c rune) bool {
	return c >= 0x80 && (unicode.Is(unicode.So, c) || unicode.Is(unicode.Sk, c) || unicode.Is(unicode.Mn, c) ||
		c == 0x200d || c >= 0xfe00 && c <= 0xfe0f || c >= 0x1f3fb && c <= 0x1f3ff || c >= 0xe0020 && c <= 0xe007f)
}

// marked is a text with its marks: a link outside, code inside. Spaces at
// its ends stay outside the delimiters, where Markdown needs them.
func marked(n Node) string {
	text := n.Text
	lead := len(text) - len(strings.TrimLeftFunc(text, unicode.IsSpace))
	trail := len(text) - len(strings.TrimRightFunc(text, unicode.IsSpace))
	if lead == len(text) || len(n.Marks) == 0 {
		return escape(text)
	}
	core := text[lead : len(text)-trail]
	var s string
	var href string
	isCode := false
	for _, m := range n.Marks {
		isCode = isCode || m.Type == "code"
	}
	if isCode {
		s = code(core)
	} else {
		s = escape(core)
	}
	for _, m := range n.Marks {
		switch m.Type {
		case "strong":
			s = "**" + s + "**"
		case "em":
			s = "*" + s + "*"
		case "strike":
			s = "~~" + s + "~~"
		case "link":
			href = m.attr("href")
		}
	}
	if safe(href) {
		s = "[" + s + "](" + dest(href) + ")"
	}
	return text[:lead] + s + text[len(text)-trail:]
}

func code(s string) string {
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

func fence(s, lang string) string {
	if strings.TrimLeft(lang, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+#.-") != "" {
		lang = "" // only a language's name may follow the fence
	}
	f := "```"
	for strings.Contains(s, f) {
		f += "`"
	}
	return f + lang + "\n" + strings.TrimSuffix(s, "\n") + "\n" + f
}

func link(text, href string) string {
	if !safe(href) {
		return escape(text)
	}
	return "[" + escape(text) + "](" + dest(href) + ")"
}

// AttachmentScheme is the scheme of the links a Media lookup may give.
const AttachmentScheme = "jira-attachment:"

// safe says a link may go into the Markdown: http, https and mailto only
// (an issue's text is anyone's who can edit it; a file: or an app's own
// scheme could open something on the Mac).
func safe(href string) bool {
	h := strings.ToLower(strings.TrimSpace(href))
	return strings.HasPrefix(h, "https://") || strings.HasPrefix(h, "http://") || strings.HasPrefix(h, "mailto:")
}

// dest makes a URL safe as a link's destination: nothing in it can end
// the destination or the link.
func dest(href string) string {
	return strings.NewReplacer(" ", "%20", "(", "%28", ")", "%29", "<", "%3C", ">", "%3E", "\n", "%0A", "\r", "%0D", "\\", "%5C").Replace(href)
}

func date(ms string) string {
	n, err := strconv.ParseInt(ms, 10, 64)
	if err != nil {
		return escape(ms)
	}
	return time.UnixMilli(n).UTC().Format("2006-01-02")
}

func quote(s string) string {
	lines := strings.Split(s, "\n")
	for i, l := range lines {
		lines[i] = strings.TrimRight("> "+l, " ")
	}
	return strings.Join(lines, "\n")
}

func indent(s, pad string) string {
	return strings.ReplaceAll(s, "\n", "\n"+pad)
}

// escape keeps a text's characters from reading as Markdown: an
// underscore only where it could start or end emphasis (snake_case
// stays), what starts a block only at a line's start.
func escape(s string) string {
	var b strings.Builder
	r := []rune(s)
	lineStart := true
	for i := 0; i < len(r); i++ {
		c := r[i]
		switch {
		case strings.ContainsRune("\\`*[]<", c),
			c == '~' && (i > 0 && r[i-1] == '~' || i+1 < len(r) && r[i+1] == '~'):
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
		b.WriteRune(c)
		lineStart = c == '\n' || c == '\r' || lineStart && c == ' '
	}
	return b.String()
}

func isWord(r rune) bool { return unicode.IsLetter(r) || unicode.IsDigit(r) }

// textOf joins a node's text, as a code block holds it.
func textOf(n Node) string {
	var b strings.Builder
	for _, c := range n.Content {
		b.WriteString(c.Text)
	}
	return b.String()
}

// isBlock says a node sits among blocks rather than in a line of text.
func isBlock(n Node) bool {
	switch n.Type {
	case "text", "hardBreak", "mention", "emoji", "status", "date", "inlineCard", "mediaInline", "placeholder", "inlineExtension":
		return false
	}
	return true
}

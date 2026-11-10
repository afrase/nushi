package opencodeskills

import (
	"bytes"
	"slices"

	"github.com/tailscale/hujson"
)

// A config file is changed in its text, by the places hujson gives its
// values: an item is written in (with a comma), or its own bytes, one
// comma and the blanks around it are cut. No other byte is written again,
// and a comment is never cut.

// items are an object's members or a list's entries, by their places in
// the text.
type items struct {
	// starts and ends are each item's first byte and the one after its
	// last; commas where its comma is, when one follows it.
	starts, ends, commas []int
	// trailing says a comma follows the last item.
	trailing bool
	// tail is where what precedes the closing bracket begins (blanks and
	// comments, after the last item or its comma); shut is that bracket.
	tail, shut int
}

func arrayItems(v *hujson.Value) items {
	arr, _ := v.Value.(*hujson.Array)
	l := items{shut: v.EndOffset - 1}
	for _, e := range arr.Elements {
		l.starts, l.ends, l.commas = append(l.starts, e.StartOffset), append(l.ends, e.EndOffset), append(l.commas, e.EndOffset+len(e.AfterExtra))
		l.trailing = e.AfterExtra != nil
	}
	l.tail = l.shut - len(arr.AfterExtra)
	return l
}

// objectItems are the members of top, which ends at end.
func objectItems(top *hujson.Object, end int) items {
	l := items{shut: end - 1}
	for _, m := range top.Members {
		l.starts, l.ends, l.commas = append(l.starts, m.Name.StartOffset), append(l.ends, m.Value.EndOffset), append(l.commas, m.Value.EndOffset+len(m.Value.AfterExtra))
		l.trailing = m.Value.AfterExtra != nil
	}
	l.tail = l.shut - len(top.AfterExtra)
	return l
}

// cut is a change to a text: the del bytes from at give way to ins.
type cut struct {
	at, del int
	ins     string
}

// apply makes the cuts in b, those at one place in the order given.
func apply(b []byte, cuts ...cut) []byte {
	slices.SortStableFunc(cuts, func(a, c cut) int { return a.at - c.at })
	var out []byte
	done := 0
	for _, c := range cuts {
		at := max(c.at, done)
		out = append(append(out, b[done:at]...), c.ins...)
		done = max(c.at+c.del, at)
	}
	return append(out, b[done:]...)
}

func blank(b []byte) bool { return len(bytes.Trim(b, " \t\r")) == 0 }

// lineStart is where the line holding b[at] starts.
func lineStart(b []byte, at int) int { return bytes.LastIndexByte(b[:at], '\n') + 1 }

// eol is the line break b's lines end with.
func eol(b []byte) string {
	if bytes.Contains(b, []byte("\r\n")) {
		return "\r\n"
	}
	return "\n"
}

// unit is a level of b's indentation: a tab where it has lines starting
// with one, else two spaces.
func unit(b []byte) string {
	if bytes.Contains(b, []byte("\n\t")) {
		return "\t"
	}
	return "  "
}

// ownLine is where the line break before the closing bracket starts when
// that bracket has a line to itself, else -1.
func (l items) ownLine(b []byte) int {
	i := bytes.LastIndexByte(b[l.tail:l.shut], '\n')
	if i < 0 || !blank(b[l.tail+i+1:l.shut]) {
		return -1
	}
	if i > 0 && b[l.tail+i-1] == '\r' {
		i--
	}
	return l.tail + i
}

// indent is what a new item's line starts with: what the last item's
// does when it starts its line, else a level more than the bracket's.
func (l items) indent(b []byte) string {
	if n := len(l.starts); n > 0 {
		if lead := b[lineStart(b, l.starts[n-1]):l.starts[n-1]]; blank(lead) {
			return string(lead)
		}
	}
	return string(b[lineStart(b, l.shut):l.shut]) + unit(b)
}

// add is b with a last item: on a line of its own before the closing
// bracket when that has one (item is given the line's indentation), else
// after the last item on its line. A trailing comma stays trailing.
func (l items) add(b []byte, item func(indent string, lines bool) string) []byte {
	n := len(l.starts)
	var cuts []cut
	if n > 0 && !l.trailing {
		cuts = append(cuts, cut{at: l.ends[n-1], ins: ","})
	}
	comma := ""
	if l.trailing {
		comma = ","
	}
	if at := l.ownLine(b); at >= 0 {
		indent := l.indent(b)
		return apply(b, append(cuts, cut{at: at, ins: eol(b) + indent + item(indent, true) + comma})...)
	}
	text := item("", false)
	switch {
	case n == 0:
		cuts = append(cuts, cut{at: l.tail, ins: text})
	case l.trailing:
		cuts = append(cuts, cut{at: l.tail, ins: " " + text + ","})
	default:
		cuts[0].ins = ", " + text
	}
	return apply(b, cuts...)
}

// drop is b without item i and its comma (the one before it, for a last
// item with none after), and without its lines when nothing else is on
// them; else without the blanks beside it.
func (l items) drop(b []byte, i int) []byte {
	n := len(l.starts)
	start, end := l.starts[i], l.ends[i]
	var cuts []cut
	switch {
	case i < n-1 || l.trailing:
		if blank(b[end:l.commas[i]]) {
			end = l.commas[i] + 1
		} else {
			cuts = append(cuts, cut{at: l.commas[i], del: 1}) // a comment is before the comma: it stays
		}
	case i > 0:
		cuts = append(cuts, cut{at: l.commas[i-1], del: 1})
	}
	from := lineStart(b, start)
	if rest := bytes.IndexByte(b[end:], '\n'); rest >= 0 && blank(b[from:start]) && blank(b[end:end+rest]) {
		return apply(b, append(cuts, cut{at: from, del: end + rest + 1 - from})...)
	}
	leads := blank(b[from:start])
	for !leads && (b[start-1] == ' ' || b[start-1] == '\t') {
		start--
	}
	for start == l.starts[i] && (leads || end > l.ends[i]) && (b[end] == ' ' || b[end] == '\t') {
		end++
	}
	return apply(b, append(cuts, cut{at: start, del: end - start})...)
}

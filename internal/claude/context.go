package claude

import (
	"errors"
	"slices"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// Parse reads what fills Claude's context from the output of its /context
// command, in its order: the "Estimated usage by category" table of the
// markdown the agent returns. This is Claude's private format (Claude
// Code 2.1.308, claude-agent-acp 0.94.0): see ADR 0017.
func Parse(markdown string) ([]model.ContextCategory, error) {
	_, table, ok := strings.Cut(markdown, "### Estimated usage by category")
	if !ok {
		return nil, errors.New("no usage by category in the output")
	}
	var out []model.ContextCategory
	for _, line := range strings.Split(table, "\n")[1:] {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "###") {
			break
		}
		cells := strings.Split(strings.Trim(line, "|"), "|")
		if len(cells) != 3 {
			continue
		}
		name := strings.TrimSpace(cells[0])
		tokens, err1 := count(strings.TrimSpace(cells[1]))
		pct, err2 := strconv.ParseFloat(strings.TrimSuffix(strings.TrimSpace(cells[2]), "%"), 64)
		if err1 != nil || err2 != nil {
			continue // the header and the line under it
		}
		c := model.ContextCategory{Name: name, Tokens: tokens, Percent: pct}
		switch {
		case name == "Free space":
			c.Kind = "free"
		case name == "Messages":
			c.Part = model.PartMessages
		case name == "Autocompact buffer":
			c.Part = model.PartBuffer
		case strings.HasSuffix(name, " (deferred)"): // listed, loaded on demand
			c.Name, c.Kind = strings.TrimSuffix(name, " (deferred)"), "deferred"
		}
		out = append(out, c)
	}
	if len(out) == 0 {
		return nil, errors.New("no categories in the output")
	}
	return out, nil
}

// Lists reads the lists /context gives after its categories: each "###"
// heading over a table, in its order, named as Claude's rail words it
// ("MCP Tools" is "MCP tools"), each row its first cell and the count in
// its last. A list without rows is left out; nothing when the categories'
// table isn't there. Claude's private format, as Parse's (ADR 0017).
func Lists(markdown string) []model.ContextList {
	_, rest, ok := strings.Cut(markdown, "### Estimated usage by category")
	if !ok {
		return nil
	}
	var out []model.ContextList
	var cur *model.ContextList
	for _, line := range strings.Split(rest, "\n")[1:] {
		line = strings.TrimSpace(line)
		if heading, ok := strings.CutPrefix(line, "###"); ok {
			out = append(out, model.ContextList{Name: sentence(strings.TrimSpace(heading))})
			cur = &out[len(out)-1]
			continue
		}
		if cur == nil || !strings.HasPrefix(line, "|") {
			continue
		}
		cells := strings.Split(strings.TrimSuffix(line[1:], "|"), "|")
		if len(cells) < 2 {
			continue
		}
		n, err := count(strings.TrimSpace(cells[len(cells)-1]))
		if err != nil {
			continue // the header and the line under it
		}
		cur.Rows = append(cur.Rows, model.ContextRow{Name: strings.TrimSpace(cells[0]), Tokens: n})
	}
	return slices.DeleteFunc(out, func(l model.ContextList) bool { return len(l.Rows) == 0 })
}

// sentence is a heading as the rail words it: each word after the first
// in lower case, but for one in capitals ("MCP").
func sentence(heading string) string {
	words := strings.Split(heading, " ")
	for i, w := range words {
		if i > 0 && w != strings.ToUpper(w) {
			words[i] = strings.ToLower(w)
		}
	}
	return strings.Join(words, " ")
}

// count reads a token count as Claude writes it: 622, 2.5k, 1.2m, and in
// its lists ~480 and 1,024.
func count(s string) (int64, error) {
	s = strings.ToLower(strings.NewReplacer("~", "", ",", "").Replace(s))
	mult := 1.0
	switch {
	case strings.HasSuffix(s, "k"):
		mult, s = 1e3, strings.TrimSuffix(s, "k")
	case strings.HasSuffix(s, "m"):
		mult, s = 1e6, strings.TrimSuffix(s, "m")
	}
	n, err := strconv.ParseFloat(s, 64)
	return int64(n*mult + 0.5), err
}

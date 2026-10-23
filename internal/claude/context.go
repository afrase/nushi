package claude

import (
	"errors"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// Parse reads what fills Claude's context from the output of its /context
// command, in its order: the "Estimated usage by category" table of the
// markdown the adapter returns. This is Claude's private format (Claude
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

// count reads a token count as Claude writes it: 622, 2.5k, 1.2m.
func count(s string) (int64, error) {
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

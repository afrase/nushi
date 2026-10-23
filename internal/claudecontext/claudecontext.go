// Package claudecontext reads what fills Claude's context from the output
// of its /context command: the "Estimated usage by category" table of the
// markdown claude-agent-acp returns. This is Claude's private format (Claude
// Code 2.1.308, claude-agent-acp 0.94.0): see ADR 0017.
package claudecontext

import (
	"errors"
	"strconv"
	"strings"
)

// Category is one row of the table: "Messages", 15,900 tokens, 1.6%.
type Category struct {
	Name    string
	Tokens  int64
	Percent float64
}

// Parse reads the categories from /context's output, in its order.
func Parse(markdown string) ([]Category, error) {
	_, table, ok := strings.Cut(markdown, "### Estimated usage by category")
	if !ok {
		return nil, errors.New("no usage by category in the output")
	}
	var out []Category
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
		out = append(out, Category{name, tokens, pct})
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

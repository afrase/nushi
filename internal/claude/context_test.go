package claude

import (
	"os"
	"reflect"
	"testing"

	"github.com/afrase/nushi/internal/model"
)

func TestParse(t *testing.T) {
	out := `## Context Usage

**Model:** claude-opus-5-5  
**Tokens:** 32.4k / 1m (3%)

### Estimated usage by category

| Category | Tokens | Percentage |
|----------|--------|------------|
| System prompt | 2.5k | 0.3% |
| MCP tools | 622 | 0.1% |
| MCP tools (deferred) | 12k | 1.2% |
| Messages | 3.1k | 0.3% |
| Free space | 934.6k | 93.5% |
| Autocompact buffer | 33k | 3.3% |

### MCP Tools

| Tool | Server | Tokens |
|------|--------|--------|
| mcp__x__y | x | 153 |
`
	got, err := Parse(out)
	want := []model.ContextCategory{{Name: "System prompt", Tokens: 2500, Percent: 0.3}, {Name: "MCP tools", Tokens: 622, Percent: 0.1},
		{Name: "MCP tools", Tokens: 12000, Percent: 1.2, Kind: "deferred"}, {Name: "Messages", Tokens: 3100, Percent: 0.3, Part: model.PartMessages},
		{Name: "Free space", Tokens: 934600, Percent: 93.5, Kind: "free"}, {Name: "Autocompact buffer", Tokens: 33000, Percent: 3.3, Part: model.PartBuffer}}
	if err != nil || !reflect.DeepEqual(got, want) {
		t.Errorf("Parse = %v, %v; want %v", got, err, want)
	}
	if _, err := Parse("## Something else"); err == nil {
		t.Error("parsed output without the table")
	}
}

// The lists after the categories, as a long chat's /context gives them
// (Claude Code's rail, 2026-11-05), named as the rail's rows.
func TestLists(t *testing.T) {
	md, err := os.ReadFile("testdata/context.md")
	if err != nil {
		t.Fatal(err)
	}
	want := []model.ContextList{
		{Name: "MCP tools", Rows: []model.ContextRow{{Name: "mcp__github__get_me", Tokens: 120}, {Name: "mcp__github__list_issues", Tokens: 410}, {Name: "mcp__docs__read", Tokens: 250}}},
		{Name: "Custom agents", Rows: []model.ContextRow{{Name: "reviewer", Tokens: 180}, {Name: "explorer", Tokens: 134}}},
	}
	if got := Lists(string(md)); !reflect.DeepEqual(got, want) {
		t.Errorf("Lists = %v; want %v", got, want)
	}
	cats, err := Parse(string(md))
	if err != nil || len(cats) != 11 {
		t.Errorf("Parse = %d categories, %v", len(cats), err)
	}
	for _, md := range []string{"## Context Usage", "### Estimated usage by category\n\n### Skills\n\n| Skill | Source | Tokens |\n|---|---|---|\n"} {
		if got := Lists(md); len(got) != 0 {
			t.Errorf("Lists(%q) = %v; want none", md, got)
		}
	}
}

// ReadContext gives the categories and the lists of the last message.
func TestReadContextLists(t *testing.T) {
	md, err := os.ReadFile("testdata/context.md")
	if err != nil {
		t.Fatal(err)
	}
	u := Harness{}.ReadContext([]string{"an earlier copy", string(md)})
	if u.Markdown != string(md) || len(u.Categories) != 11 || len(u.Lists) != 2 || u.Lists[1].Rows[0] != (model.ContextRow{Name: "reviewer", Tokens: 180}) {
		t.Errorf("ReadContext = %+v", u)
	}
}

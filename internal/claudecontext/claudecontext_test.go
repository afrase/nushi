package claudecontext

import (
	"reflect"
	"testing"
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
| Free space | 934.6k | 93.5% |

### MCP Tools

| Tool | Server | Tokens |
|------|--------|--------|
| mcp__x__y | x | 153 |
`
	got, err := Parse(out)
	want := []Category{{"System prompt", 2500, 0.3}, {"MCP tools", 622, 0.1}, {"Free space", 934600, 93.5}}
	if err != nil || !reflect.DeepEqual(got, want) {
		t.Errorf("Parse = %v, %v; want %v", got, err, want)
	}
	if _, err := Parse("## Something else"); err == nil {
		t.Error("parsed output without the table")
	}
}

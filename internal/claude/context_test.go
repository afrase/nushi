package claude

import (
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
| Free space | 934.6k | 93.5% |

### MCP Tools

| Tool | Server | Tokens |
|------|--------|--------|
| mcp__x__y | x | 153 |
`
	got, err := Parse(out)
	want := []model.ContextCategory{{Name: "System prompt", Tokens: 2500, Percent: 0.3}, {Name: "MCP tools", Tokens: 622, Percent: 0.1},
		{Name: "MCP tools", Tokens: 12000, Percent: 1.2, Kind: "deferred"}, {Name: "Free space", Tokens: 934600, Percent: 93.5, Kind: "free"}}
	if err != nil || !reflect.DeepEqual(got, want) {
		t.Errorf("Parse = %v, %v; want %v", got, err, want)
	}
	if _, err := Parse("## Something else"); err == nil {
		t.Error("parsed output without the table")
	}
}

package adf

import (
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

var update = flag.Bool("update", false, "rewrite the .md goldens")

// The fixtures are what Jira Cloud sent back for text written on the test
// site (an issue's description in wiki markup, which Jira turned into ADF;
// a comment; a comment of the editor's own nodes, posted as ADF), with the
// user's name, id and site replaced.
func TestToMarkdownGoldens(t *testing.T) {
	files, _ := filepath.Glob("testdata/*.json")
	if len(files) == 0 {
		t.Fatal("no fixtures")
	}
	media := func(id string) (string, string) {
		if id == "fa78893e-e7e6-4f5e-885b-d0f99f145599" {
			return "nushi.png", "jira-attachment:10000"
		}
		return "", ""
	}
	for _, f := range files {
		t.Run(filepath.Base(f), func(t *testing.T) {
			b, err := os.ReadFile(f)
			if err != nil {
				t.Fatal(err)
			}
			doc, err := Parse(b)
			if err != nil {
				t.Fatal(err)
			}
			got := ToMarkdown(doc, media) + "\n"
			golden := strings.TrimSuffix(f, ".json") + ".md"
			if *update {
				if err := os.WriteFile(golden, []byte(got), 0o644); err != nil {
					t.Fatal(err)
				}
			}
			want, err := os.ReadFile(golden)
			if err != nil {
				t.Fatal(err)
			}
			if got != string(want) {
				t.Errorf("got\n%s\nwant\n%s", got, want)
			}
		})
	}
}

func TestToMarkdown(t *testing.T) {
	for _, c := range []struct{ name, adf, want string }{
		{"escapes", `[{"type":"paragraph","content":[{"type":"text","text":"a *star*, snake_case, _x_, [b] and <c>"}]}]`,
			`a \*star\*, snake_case, \_x\_, \[b\] and \<c>`},
		{"a line that would start a list", `[{"type":"paragraph","content":[{"type":"text","text":"1. no\n- no\n# no"}]}]`,
			"1\\. no\n\\- no\n\\# no"},
		{"marks keep spaces outside", `[{"type":"paragraph","content":[{"type":"text","text":"a"},{"type":"text","text":" bold ","marks":[{"type":"strong"}]},{"type":"text","text":"b"}]}]`,
			"a **bold** b"},
		{"a link around code", `[{"type":"paragraph","content":[{"type":"text","text":"x()","marks":[{"type":"code"},{"type":"link","attrs":{"href":"https://e.com/a b"}}]}]}]`,
			"[`x()`](https://e.com/a%20b)"},
		{"code with a backtick", "[{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"a`b\",\"marks\":[{\"type\":\"code\"}]}]}]",
			"``a`b``"},
		{"a fence in a code block", "[{\"type\":\"codeBlock\",\"content\":[{\"type\":\"text\",\"text\":\"```\\nx\"}]}]",
			"````\n```\nx\n````"},
		{"an unknown block keeps its text", `[{"type":"bodiedExtension","attrs":{"extensionKey":"x"},"content":[{"type":"paragraph","content":[{"type":"text","text":"inside"}]}]}]`,
			"inside"},
		{"an unknown leaf says what it was", `[{"type":"extension","attrs":{"extensionKey":"jira-chart"}},{"type":"paragraph","content":[{"type":"widget"}]}]`,
			"\\[jira-chart\\]\n\n\\[widget\\]"},
		{"an image not found", `[{"type":"mediaSingle","content":[{"type":"media","attrs":{"id":"nope","alt":"shot.png"}}]}]`,
			"\\[shot.png\\]"},
		{"a table without a header row", `[{"type":"table","content":[{"type":"tableRow","content":[{"type":"tableCell","content":[{"type":"paragraph","content":[{"type":"text","text":"a|b"}]}]}]},{"type":"tableRow","content":[{"type":"tableCell"},{"type":"tableCell","content":[{"type":"paragraph","content":[{"type":"text","text":"c"}]}]}]}]}]`,
			"| a\\|b |  |\n| --- | --- |\n|  | c |"},
	} {
		t.Run(c.name, func(t *testing.T) {
			var blocks []Node
			if err := json.Unmarshal([]byte(c.adf), &blocks); err != nil {
				t.Fatal(err)
			}
			if got := ToMarkdown(Doc(blocks...), nil); got != c.want {
				t.Errorf("got\n%q\nwant\n%q", got, c.want)
			}
		})
	}
}

func FuzzToMarkdown(f *testing.F) {
	files, _ := filepath.Glob("testdata/*.json")
	for _, file := range files {
		b, err := os.ReadFile(file)
		if err != nil {
			f.Fatal(err)
		}
		f.Add(b)
	}
	f.Fuzz(func(_ *testing.T, b []byte) {
		doc, err := Parse(b)
		if err != nil {
			return
		}
		_ = ToMarkdown(doc, func(string) (string, string) { return "f", "x:y" })
	})
}

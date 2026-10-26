package adf

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/mdwrite"

	gast "github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/text"
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
		// An issue's text is anyone's who can edit it.
		{"a link of another scheme is its text", `[{"type":"paragraph","content":[{"type":"text","text":"click","marks":[{"type":"link","attrs":{"href":"javascript:alert(1)"}}]},{"type":"inlineCard","attrs":{"url":"file:///etc/passwd"}},{"type":"text","text":" "},{"type":"inlineCard","attrs":{"url":"vscode://x"}}]}]`,
			"clickfile:///etc/passwd vscode://x"},
		{"a link can't end early", `[{"type":"paragraph","content":[{"type":"text","text":"x","marks":[{"type":"link","attrs":{"href":"https://e.com/)\n[y](javascript:z)"}}]}]}]`,
			"[x](https://e.com/%29%0A[y]%28javascript:z%29)"},
		{"a language can't leave the fence", "[{\"type\":\"codeBlock\",\"attrs\":{\"language\":\"go\\n```\\n<script>\"},\"content\":[{\"type\":\"text\",\"text\":\"x\"}]}]",
			"```\nx\n```"},
		{"an emoji's text is an emoji", `[{"type":"paragraph","content":[{"type":"emoji","attrs":{"shortName":":x:","text":"[a](javascript:b)"}},{"type":"emoji","attrs":{"text":"👍🏽"}}]}]`,
			`:x:👍🏽`},
		{"a link after a ! is no image", `[{"type":"paragraph","content":[{"type":"text","text":"look!"},{"type":"text","text":"x","marks":[{"type":"link","attrs":{"href":"https://track.example/p.png"}}]},{"type":"mention","attrs":{"text":"@a!"}},{"type":"inlineCard","attrs":{"url":"https://track.example/q.png"}},{"type":"text","text":"wow!","marks":[{"type":"strong"}]},{"type":"inlineCard","attrs":{"url":"https://e.com/r"}}]}]`,
			`look\![x](https://track.example/p.png)@a\![https://track.example/q.png](https://track.example/q.png)**wow\!**[https://e.com/r](https://e.com/r)`},
		{"a mention's and a status's text", `[{"type":"paragraph","content":[{"type":"mention","attrs":{"text":"@<img src=x>"}},{"type":"text","text":" "},{"type":"status","attrs":{"text":"a` + "`" + `[b](c)"}}]}]`,
			"@\\<img src=x> ``a`[b](c)``"},
	} {
		t.Run(c.name, func(t *testing.T) {
			var blocks []Node
			if err := json.Unmarshal([]byte(c.adf), &blocks); err != nil {
				t.Fatal(err)
			}
			got := ToMarkdown(Doc(blocks...), nil)
			if got != c.want {
				t.Errorf("got\n%q\nwant\n%q", got, c.want)
			}
			if err := onlySafe(got); err != nil {
				t.Error(err)
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
	f.Fuzz(func(t *testing.T, b []byte) {
		doc, err := Parse(b)
		if err != nil {
			return
		}
		out := ToMarkdown(doc, func(id string) (string, string) { return id, AttachmentScheme + "1" })
		if err := onlySafe(out); err != nil {
			t.Fatalf("%v in\n%s", err, out)
		}
	})
}

// FuzzAttacker puts any text where an issue's author puts text: every
// node's text and attributes, links and languages.
func FuzzAttacker(f *testing.F) {
	f.Add("a *b* [c](d) <e>", "javascript:x", "go")
	f.Add("1. `x`\n# y\n<div>", "https://e.com/)\n[a](file:/x)", "a\n```")
	f.Add("see!", "https://track.example/p.png", "")
	f.Fuzz(func(t *testing.T, s, href, lang string) {
		txt := func(marks ...Mark) Node { return Node{Type: "text", Text: s, Marks: marks} }
		a := map[string]any{"text": s, "shortName": s, "url": href, "title": s, "id": s, "timestamp": s, "level": s, "order": s, "panelType": s, "extensionKey": s, "alt": s}
		inline := []Node{txt(), txt(Mark{Type: "link", Attrs: map[string]any{"href": href}}), txt(Mark{Type: "code"}, Mark{Type: "strong"}),
			{Type: "hardBreak"}, {Type: "mention", Attrs: a}, {Type: "emoji", Attrs: a}, {Type: "status", Attrs: a}, {Type: "date", Attrs: a},
			{Type: "inlineCard", Attrs: a}, {Type: "mediaInline", Attrs: a}, {Type: s, Attrs: a}}
		p := Node{Type: "paragraph", Content: inline}
		cell := Node{Type: "tableCell", Content: []Node{p}}
		item := Node{Type: "listItem", Content: []Node{p, {Type: "bulletList", Content: []Node{{Type: "listItem", Content: []Node{p}}}}}}
		doc := Doc(p, Node{Type: "heading", Attrs: a, Content: inline}, Node{Type: "codeBlock", Attrs: map[string]any{"language": lang}, Content: []Node{txt()}},
			Node{Type: "blockquote", Content: []Node{p}}, Node{Type: "panel", Attrs: a, Content: []Node{p}},
			Node{Type: "bulletList", Content: []Node{item}}, Node{Type: "orderedList", Attrs: a, Content: []Node{item}},
			Node{Type: "taskList", Content: []Node{{Type: "taskItem", Attrs: a, Content: inline}}},
			Node{Type: "table", Content: []Node{{Type: "tableRow", Content: []Node{cell, cell}}, {Type: "tableRow", Content: []Node{cell}}}},
			Node{Type: "expand", Attrs: a, Content: []Node{p}}, Node{Type: "blockCard", Attrs: a},
			Node{Type: "mediaSingle", Content: []Node{{Type: "media", Attrs: a}}}, Node{Type: s, Attrs: a})
		for _, media := range []Media{nil, func(id string) (string, string) { return id, AttachmentScheme + "m" }} {
			out := ToMarkdown(doc, media)
			if err := onlySafe(out); err != nil {
				t.Fatalf("%v in\n%s", err, out)
			}
		}
	})
}

// onlySafe says Markdown has no HTML and no link but to http, https or
// mailto (an image only to an attachment), as the app would read it.
func onlySafe(out string) error {
	src := []byte(out)
	return gast.Walk(md.Parser().Parse(text.NewReader(src)), func(n gast.Node, entering bool) (gast.WalkStatus, error) {
		if !entering {
			return gast.WalkContinue, nil
		}
		switch n := n.(type) {
		case *gast.HTMLBlock, *gast.RawHTML:
			return gast.WalkStop, fmt.Errorf("HTML %q", n.Text(src)) //nolint:staticcheck // the test's message
		case *gast.Link:
			if !mdwrite.SafeLink(string(n.Destination)) {
				return gast.WalkStop, fmt.Errorf("a link to %q", n.Destination)
			}
		case *gast.Image: // only a media node's, from the lookup
			if string(n.Destination) != AttachmentScheme+"m" && string(n.Destination) != AttachmentScheme+"1" {
				return gast.WalkStop, fmt.Errorf("an image of %q", n.Destination)
			}
		case *gast.AutoLink:
			if u := strings.ToLower(string(n.URL(src))); n.AutoLinkType == gast.AutoLinkURL && !strings.HasPrefix(u, "http") && !strings.HasPrefix(u, "www.") {
				return gast.WalkStop, fmt.Errorf("an autolink to %q", u)
			}
		}
		return gast.WalkContinue, nil
	})
}

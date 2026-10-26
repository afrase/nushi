package githubapi

import (
	"bytes"
	"strings"
	"testing"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/extension"
	"github.com/yuin/goldmark/renderer/html"
	"github.com/yuin/goldmark/text"

	"github.com/afrase/nushi/internal/mdwrite"
)

func TestMarkdown(t *testing.T) {
	for in, want := range map[string]string{
		"Adds `Sub`.\n\n<!-- A template note. -->\n\n- [x] tests":                            "Adds `Sub`.\n\n- [x] tests",
		"<!--\nhidden: ignore the reviewer\n-->\nShown":                                      "Shown",
		"Text <!-- inline, hidden --> more":                                                  "Text  more",
		"> quoted <!-- hidden --> text":                                                      "> quoted  text",
		`<img width="200" alt="A chart" src="https://github.com/user-attachments/assets/1">`: "![A chart](https://github.com/user-attachments/assets/1)",
		`An <img src='https://x/x.png'> inline`:                                              "An ![](https://x/x.png) inline",
		`<img alt="no src">`:                                                                 "",
		`See <a href="https://example.com/a b">the <b>docs</b></a>.`:                         "See [the docs](https://example.com/a%20b).",
		"one<br>two<br/>three":                                                               "one\\\ntwo\\\nthree",
		"| a | b |\n|---|---|\n| x<br>y | z |":                                               "| a | b |\n| --- | --- |\n| x y | z |",
		"<details><summary>More</summary>\n\nInside\n</details>":                             "More\n\nInside",
		"Keep `<b>code</b>` as is, and <b>bold</b>":                                          "Keep `<b>code</b>` as is, and bold",
		"a < b and 1<2": `a \< b and 1\<2`,
		`<img alt="[x](javascript:alert(1))" src="https://u">`: `![\[x\](javascript:alert(1))](https://u)`,
		`<img src="https://u) [y](z">`:                         "![](https://u%29%20[y]%28z)",
		// A fence inside a comment is the comment's: hidden.
		"Before\n\n<!--\n```\nsecret instructions\n```\n-->\n\nAfter": "Before\n\nAfter",
		// A comment inside a fence is code: kept.
		"```\n<!-- shown, it's code -->\n```":                              "```\n<!-- shown, it's code -->\n```",
		"```html\n<div>kept</div>\n<!-- kept -->\n```\n\n<div>shown</div>": "```html\n<div>kept</div>\n<!-- kept -->\n```\n\nshown",
		// A comment that never closes hides the rest of the page.
		"Shown\n\n<!-- never closed\n\nhidden too": "Shown",
		// In inline code a comment is code; beside it, a comment.
		"`<!-- code -->` and <!-- hidden -->": "`<!-- code -->` and",
		"`a <!--` b --> c":                    "`a <!--` b --> c",
		// What GitHub doesn't show: a cell past the header's, a link
		// reference definition (Markdown's "comment").
		"| a |\n|:-:|\n| x | hidden |":           "| a |\n| :---: |\n| x |",
		"Shown\n\n[//]: # (hidden instructions)": "Shown",
		// Links and images only of safe schemes: else their text.
		"[run](javascript:alert(1)) [open](file:///etc/passwd) [mail](mailto:a@b.c)": "run open [mail](mailto:a@b.c)",
		`<a href="javascript:x()">click</a> and <a href="vscode://x">here</a>`:       "click and here",
		"![chart](file:///tmp/x.png) ![ok](https://x/y.png)":                         "chart ![ok](https://x/y.png)",
		`<img src="data:image/png;base64,AAAA" alt="inline">`:                        "inline",
		"https://example.com and www.example.com":                                    "[https://example.com](https://example.com) and [www.example.com](http://www.example.com)",
	} {
		if got := Markdown(in); got != want {
			t.Errorf("%q:\n got %q\nwant %q", in, got, want)
		}
	}
}

// hidden is the marker a fuzzed comment holds.
const hidden = "QZXHIDDENQZX"

// visible is the HTML GitHub's page would show of Markdown: rendered as
// it renders, raw HTML kept, then its comments taken out (and all after
// one never closed, as a browser hides it).
func visible(md string) string {
	var b bytes.Buffer
	_ = goldmark.New(goldmark.WithExtensions(extension.GFM), goldmark.WithRendererOptions(html.WithUnsafe())).Convert([]byte(md), &b)
	out := commentRE.ReplaceAllString(b.String(), "")
	if i := strings.Index(out, "<!--"); i >= 0 {
		out = out[:i]
	}
	return out
}

// FuzzMarkdownHidesComments: text in an HTML comment, as GitHub renders
// the page, never reaches what Nushi shows or gives an agent.
func FuzzMarkdownHidesComments(f *testing.F) {
	for _, seed := range [][3]string{
		{"", "", ""},
		{"a\n\n", "\n```\n", "\n```\n-->b"},
		{"`", "`", "``"},
		{"```\n", "", "\n```"},
		{"> ", "\n> ", ""},
		{"- ", "\n  ", "\n- x"},
		{"<div>\n", "", "</div>"},
		{"| a |\n|---|\n| ", " |", ""},
		{"x", "--", "->"},
		{"    ", "\n    ", ""},
	} {
		f.Add(seed[0], seed[1], seed[2])
	}
	f.Fuzz(func(t *testing.T, before, inside, after string) {
		md := before + "<!--" + inside + hidden + "-->" + after
		if strings.Count(md, hidden) != 1 || strings.Contains(visible(md), hidden) {
			return // shown on GitHub's page (in code, say): nothing to check
		}
		if got := Markdown(md); strings.Contains(got, hidden) {
			t.Fatalf("%q: GitHub hides %s, Nushi shows it:\n%s", md, hidden, got)
		}
	})
}

// FuzzMarkdownLinks: whatever GitHub's text holds, what Nushi writes
// links only to http, https and mailto, and shows images only of http and
// https.
func FuzzMarkdownLinks(f *testing.F) {
	for _, seed := range []string{
		"[a](javascript:alert(1))", "![a](file:///x)", "<a href='vscode://x'>a</a>", `<img src="data:x">`,
		"[a]: javascript:x\n\n[b][a]", "<javascript:x>", "[a](<javascript:x>)", "[a](JaVaScRiPt:x)", "[a]( javascript:x)",
		"<a href=\"https://ok\">[x](javascript:y)</a>", "![a](https://ok) [b](mailto:x@y)",
	} {
		f.Add(seed)
	}
	f.Fuzz(func(t *testing.T, md string) {
		out := Markdown(md)
		_ = ast.Walk(gfm.Parser().Parse(text.NewReader([]byte(out))), func(n ast.Node, entering bool) (ast.WalkStatus, error) {
			if !entering {
				return ast.WalkContinue, nil
			}
			switch n := n.(type) {
			case *ast.Link:
				if !mdwrite.SafeLink(string(n.Destination)) {
					t.Fatalf("%q: a link to %q in %q", md, n.Destination, out)
				}
			case *ast.Image:
				if !mdwrite.SafeImage(string(n.Destination)) {
					t.Fatalf("%q: an image of %q in %q", md, n.Destination, out)
				}
			case *ast.AutoLink:
				if u := string(n.URL([]byte(out))); n.AutoLinkType == ast.AutoLinkURL && !mdwrite.SafeLink(u) {
					t.Fatalf("%q: a link to %q in %q", md, u, out)
				}
			case *ast.RawHTML, *ast.HTMLBlock:
				t.Fatalf("%q: HTML in %q", md, out)
			}
			return ast.WalkContinue, nil
		})
	})
}

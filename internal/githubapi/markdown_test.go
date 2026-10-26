package githubapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"os"
	"strings"
	"testing"
	"unicode"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/extension"
	gmhtml "github.com/yuin/goldmark/renderer/html"
	gmtext "github.com/yuin/goldmark/text"
	xhtml "golang.org/x/net/html"
	"golang.org/x/net/html/atom"

	"github.com/afrase/nushi/internal/mdwrite"
)

func TestMarkdown(t *testing.T) {
	for in, want := range map[string]string{
		"Adds `Sub`.\n\n<!-- A template note. -->\n\n- [x] tests\n- [ ] docs":                "Adds `Sub`.\n\n- [x] tests\n- [ ] docs",
		"Text <!-- inline, hidden --> more":                                                  "Text more",
		`<img width="200" alt="A chart" src="https://github.com/user-attachments/assets/1">`: "![A chart](https://github.com/user-attachments/assets/1)",
		`See <a href="https://example.com/a b">the <b>docs</b></a>.`:                         "See [the **docs**](https://example.com/a%20b).",
		"one<br>two": "one\\\ntwo",
		"| a | b |\n|---|:-:|\n| x<br>y | z | extra |":           "| a | b |\n| --- | :---: |\n| x y | z |",
		"Before\n\n<!--\n```\nsecret\n```\n-->\n\nAfter":         "Before\n\nAfter",
		"```\n<!-- shown, it's code -->\n```":                    "```\n<!-- shown, it's code -->\n```",
		"Shown\n\n<!-- never closed\n\nhidden too":               "Shown",
		"`<!-- code -->` and <!-- hidden --> after":              "`<!-- code -->` and after",
		"Shown\n\n[//]: # (hidden instructions)":                 "Shown",
		"<script>alert(1)</script> after":                        `\<script>alert(1)\</script> after`,
		"![alt <!-- hidden --> text](https://example.com/a.png)": "![alt text](https://example.com/a.png)",
		`<img src="https://x/a.png" alt="<b>bold</b> alt">`:      "![bold alt](https://x/a.png)",
		"[run](javascript:alert(1)) [mail](mailto:a@b.c)":        "run [mail](mailto:a@b.c)",
		`<a href="vscode://x">here</a> ![chart](file:///x.png)`:  "here chart",
		"```go\nfunc main() {}\n```":                             "```go\nfunc main() {}\n```",
		"1. one\n2. two\n   - sub\n\n3) three":                   "1. one\n2. two\n   - sub\n\n3) three",
		"> quoted\n> > nested":                                   "> quoted\n>\n> > nested",
	} {
		if got := Markdown(in); got != want {
			t.Errorf("%q:\n got %q\nwant %q", in, got, want)
		}
	}
}

// githubCase is one of GitHub's own renderings (testdata), made by
// anonymous calls to its POST /markdown (mode gfm).
type githubCase struct {
	Markdown string `json:"markdown"`
	HTML     string `json:"html"`
}

// TestMarkdownAsGitHubShowsIt: for each tricky text, what Nushi shows of
// it is what GitHub's own page shows: the same visible text.
func TestMarkdownAsGitHubShowsIt(t *testing.T) {
	var cases []githubCase
	if err := json.Unmarshal(read(t, "markdown_github.json"), &cases); err != nil {
		t.Fatal(err)
	}
	for _, c := range cases {
		want, got := squeeze(visible(c.HTML)), squeeze(visible(rendered(Markdown(c.Markdown))))
		if got != want {
			t.Errorf("%q:\nGitHub shows %q\n Nushi shows %q\n(Markdown %q)", c.Markdown, want, got, Markdown(c.Markdown))
		}
	}
}

// TestRecordGitHubMarkdown asks GitHub, without a token, how it renders
// the corpus again: NUSHI_GITHUB_RECORD_MARKDOWN=1 (60 anonymous
// requests an hour).
func TestRecordGitHubMarkdown(t *testing.T) {
	if os.Getenv("NUSHI_GITHUB_RECORD_MARKDOWN") != "1" {
		t.Skip("NUSHI_GITHUB_RECORD_MARKDOWN=1 records GitHub's renderings")
	}
	var cases []githubCase
	if err := json.Unmarshal(read(t, "markdown_github.json"), &cases); err != nil {
		t.Fatal(err)
	}
	for i, c := range cases {
		body, _ := json.Marshal(map[string]string{"text": c.Markdown, "mode": "gfm"})
		req, _ := http.NewRequestWithContext(t.Context(), http.MethodPost, "https://api.github.com/markdown", bytes.NewReader(body))
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		var b bytes.Buffer
		_, _ = b.ReadFrom(resp.Body)
		_ = resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("%s: %s", resp.Status, b.String())
		}
		cases[i].HTML = b.String()
	}
	out, _ := json.MarshalIndent(cases, "", "  ")
	if err := os.WriteFile("testdata/markdown_github.json", append(out, '\n'), 0o600); err != nil {
		t.Fatal(err)
	}
}

func read(t *testing.T, name string) []byte {
	t.Helper()
	b, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

// The oracle, written apart from Markdown: a page's visible text, and
// Markdown rendered as GitHub would render it.

// rendered is Markdown as GitHub renders it: GFM with raw HTML kept, then
// GFM's tag filter (the nine elements written as text).
func rendered(md string) string {
	var b bytes.Buffer
	_ = goldmark.New(goldmark.WithExtensions(extension.GFM), goldmark.WithRendererOptions(gmhtml.WithUnsafe())).Convert([]byte(md), &b)
	out := b.String()
	for _, name := range []string{"title", "textarea", "style", "xmp", "iframe", "noembed", "noframes", "script", "plaintext"} {
		for _, open := range []string{"<", "</"} {
			low := asciiLower(out) // byte for byte, so its indexes are out's
			var r strings.Builder
			at := 0
			for i := strings.Index(low, open+name); i >= 0; i = strings.Index(low[at:], open+name) {
				i += at
				end := i + len(open+name)
				if end == len(low) || strings.ContainsRune(" \t\n\r\f/>", rune(low[end])) {
					r.WriteString(out[at:i] + "&lt;" + out[i+1:end])
				} else {
					r.WriteString(out[at:end])
				}
				at = end
			}
			out = r.String() + out[at:]
		}
	}
	return out
}

func asciiLower(s string) string {
	b := []byte(s)
	for i, c := range b {
		if 'A' <= c && c <= 'Z' {
			b[i] = c + 'a' - 'A'
		}
	}
	return string(b)
}

// visible is the text a browser shows of a page, as GitHub's sanitizer
// leaves it: no comments (nothing after one that never closes: the
// parser makes it a comment to the end), no script; images' alt text
// isn't text (GitHub shows the image).
func visible(page string) string { return visibleAlt(page, false) }

// visibleAlt is visible with images' alt text in their place, if alt.
func visibleAlt(page string, alt bool) string {
	nodes, _ := xhtml.ParseFragment(strings.NewReader(page), &xhtml.Node{Type: xhtml.ElementNode, DataAtom: atom.Body, Data: "body"})
	var b strings.Builder
	var walk func(*xhtml.Node)
	walk = func(n *xhtml.Node) {
		if n.Type == xhtml.TextNode {
			b.WriteString(n.Data)
			return
		}
		if n.Type != xhtml.ElementNode || n.DataAtom == atom.Script {
			return
		}
		if alt && n.DataAtom == atom.Img {
			for _, a := range n.Attr {
				if a.Key == "alt" {
					b.WriteString(a.Val)
				}
			}
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
		b.WriteByte(' ')
	}
	for _, n := range nodes {
		walk(n)
	}
	return b.String()
}

func squeeze(s string) string {
	return strings.Map(func(r rune) rune {
		if unicode.IsSpace(r) {
			return -1
		}
		return r
	}, s)
}

func words(s string) []string {
	return strings.FieldsFunc(s, func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) })
}

// hidden is the marker a fuzzed comment holds.
const hidden = "QZXHIDDENQZX"

// FuzzMarkdownHidesComments: text in an HTML comment, as GitHub's page
// hides it, never reaches what Nushi shows or gives an agent.
func FuzzMarkdownHidesComments(f *testing.F) {
	for _, seed := range [][3]string{
		{"", "", ""}, {"a\n\n", "\n```\n", "\n```\n-->b"}, {"`", "`", "``"}, {"```\n", "", "\n```"}, {"> ", "\n> ", ""},
		{"- ", "\n  ", "\n- x"}, {"<div>\n", "", "</div>"}, {"| a |\n|---|\n| ", " |", ""}, {"x", "--", "->"},
		{"    ", "\n    ", ""}, {"![", "", "](https://x)"}, {`<img alt="`, "", `" src="https://x">`},
	} {
		f.Add(seed[0], seed[1], seed[2])
	}
	f.Fuzz(func(t *testing.T, before, inside, after string) {
		md := before + "<!--" + inside + hidden + "-->" + after
		if strings.Count(md, hidden) != 1 || strings.Contains(visible(rendered(md)), hidden) {
			return // shown on GitHub's page (in code, say): nothing to check
		}
		if got := Markdown(md); strings.Contains(got, hidden) {
			t.Fatalf("%q: GitHub hides %s, Nushi shows it:\n%s", md, hidden, got)
		}
	})
}

// FuzzMarkdownVisible: every word Nushi writes is in what GitHub's page
// shows of the same text, or in an image's alt text (which Nushi shows as
// the image's link): nothing hidden comes out as text.
func FuzzMarkdownVisible(f *testing.F) {
	var cases []githubCase
	_ = json.Unmarshal(must(os.ReadFile("testdata/markdown_github.json")), &cases)
	for _, c := range cases {
		f.Add(c.Markdown)
	}
	f.Fuzz(func(t *testing.T, md string) {
		shown := squeeze(visibleAlt(rendered(md), true))
		for _, w := range words(visible(rendered(Markdown(md)))) {
			if !strings.Contains(shown, w) {
				t.Fatalf("%q: %q isn't shown on GitHub's page, Nushi shows it:\n%s", md, w, Markdown(md))
			}
		}
	})
}

func must(b []byte, _ error) []byte { return b }

// FuzzMarkdownLinks: whatever GitHub's text holds, what Nushi writes
// links only to http, https and mailto, shows images only of http and
// https, and holds no HTML.
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
		_ = ast.Walk(goldmark.New(goldmark.WithExtensions(extension.GFM)).Parser().Parse(gmtext.NewReader([]byte(out))), func(n ast.Node, entering bool) (ast.WalkStatus, error) {
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

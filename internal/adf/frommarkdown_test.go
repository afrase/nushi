package adf

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

func TestFromMarkdownGolden(t *testing.T) {
	src, err := os.ReadFile("testdata/md/comment.md")
	if err != nil {
		t.Fatal(err)
	}
	doc := FromMarkdown(string(src))
	if err := valid(doc); err != nil {
		t.Fatal(err)
	}
	got, err := json.MarshalIndent(doc, "", " ")
	if err != nil {
		t.Fatal(err)
	}
	got = append(got, '\n')
	golden := "testdata/md/comment.adf.json"
	if *update {
		if err := os.WriteFile(golden, got, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	want, err := os.ReadFile(golden)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, want) {
		t.Errorf("got\n%s", got)
	}
}

// Jira's own ADF, to Markdown and back, comes out as the same Markdown.
func TestRoundTrip(t *testing.T) {
	files, _ := filepath.Glob("testdata/*.json")
	for _, f := range files {
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		doc, err := Parse(b)
		if err != nil {
			t.Fatal(err)
		}
		md1 := ToMarkdown(doc, nil)
		back := FromMarkdown(md1)
		if err := valid(back); err != nil {
			t.Errorf("%s: %v", f, err)
		}
		if md2 := ToMarkdown(back, nil); md2 != md1 {
			t.Errorf("%s: after a round trip\n%s\nwas\n%s", f, md2, md1)
		}
	}
}

func FuzzFromMarkdown(f *testing.F) {
	files, _ := filepath.Glob("testdata/md/*.md")
	for _, file := range files {
		b, err := os.ReadFile(file)
		if err != nil {
			f.Fatal(err)
		}
		f.Add(string(b))
	}
	f.Add("- [x] a\n  - b\n> > c\n| a |\n|---|\n| `x` |")
	f.Fuzz(func(t *testing.T, s string) {
		doc := FromMarkdown(s)
		if err := valid(doc); err != nil {
			t.Fatalf("%v from %q", err, s)
		}
		if _, err := json.Marshal(doc); err != nil {
			t.Fatal(err)
		}
		if out := ToMarkdown(doc, nil); onlySafe(out) != nil {
			t.Fatalf("%v in %q from %q", onlySafe(out), out, s)
		}
	})
}

// valid checks the rules of Jira's ADF schema FromMarkdown keeps to.
func valid(n Node) error {
	switch n.Type {
	case "text":
		if n.Text == "" {
			return errors.New("an empty text")
		}
		seen := map[string]bool{}
		for _, m := range n.Marks {
			if seen[m.Type] {
				return fmt.Errorf("%s twice on %q", m.Type, n.Text)
			}
			seen[m.Type] = true
			if seen["code"] && m.Type != "code" && m.Type != "link" {
				return fmt.Errorf("code with %s", m.Type)
			}
		}
	case "listItem":
		if len(n.Content) == 0 || n.Content[0].Type != "paragraph" {
			return errors.New("a list item that doesn't start with a paragraph")
		}
	case "blockquote":
		for _, c := range n.Content {
			if c.Type == "blockquote" || c.Type == "heading" || c.Type == "table" || c.Type == "rule" {
				return fmt.Errorf("a %s in a quote", c.Type)
			}
		}
	case "taskItem", "paragraph", "heading":
		for _, c := range n.Content {
			if isBlock(c) {
				return fmt.Errorf("a %s in a %s", c.Type, n.Type)
			}
		}
	}
	for _, c := range n.Content {
		if err := valid(c); err != nil {
			return err
		}
	}
	return nil
}

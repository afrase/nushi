package textfind

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"unicode/utf8"
)

// A raw line may hold the query when its anchor is there, case aside;
// what JSON escapes (quotes, newlines) never stops a line that holds it.
func TestMayHold(t *testing.T) {
	for _, c := range []struct {
		query, said string
		want        bool
	}{
		{"worktree", "Fix the WorkTree bug", true},
		{"worktree", "a work tree", false},
		{"work tree", "a work\ntree", true},       // whitespace matches any
		{`say "hi"`, `then SAY "Hi" twice`, true}, // quotes escaped in the line
		{`a\b`, `path a\b`, true},
		{"école", "Une ÉCOLE", true}, // no ASCII anchor: every line may
		{"zzz", "nothing here", false},
		{"q", "", false},
	} {
		line, err := json.Marshal(map[string]string{"text": c.said})
		if err != nil {
			t.Fatal(err)
		}
		q := New(c.query)
		if got := q.MayHold(line); got != c.want {
			t.Errorf("%q in %s: MayHold %v, want %v", c.query, line, got, c.want)
		}
		if n, _ := q.Find(c.said); c.want != (n > 0) && c.query != "école" {
			t.Errorf("%q in %q: found %d", c.query, c.said, n)
		}
	}
	if !New("").Empty() || !New(" \n ").Empty() || New("a").Empty() {
		t.Error("Empty")
	}
}

// The pivot is the anchor's rarest byte: a common first letter doesn't
// slow the test of a line.
func TestPivot(t *testing.T) {
	q := New("treeview")
	if got := q.anchor[q.pivot]; got != 'v' {
		t.Errorf("pivot %q, want v", got)
	}
	// Candidates before the pivot's place in the anchor are passed over.
	if !q.MayHold([]byte("vv TreeView")) || q.MayHold([]byte("v tree")) {
		t.Error("pivot's offset")
	}
}

// Hits are counted case aside (Unicode's folding too), and the excerpt
// holds the first, as written.
func TestFind(t *testing.T) {
	n, ex := New("Flaky test").Find("The FLAKY  TEST again;\nthe flaky\ttest, and a flaky test.")
	if n != 3 || ex != (Excerpt{Before: "The ", Match: "FLAKY TEST", After: " again; the flaky test, and a flaky test."}) {
		t.Errorf("found %d: %+v", n, ex)
	}
	if n, ex := New("ÉCOLE").Find("à l'école"); n != 1 || ex.Match != "école" || ex.Before != "à l'" {
		t.Errorf("école: %d %+v", n, ex)
	}
	if n, _ := New("nope").Find("not here"); n != 0 {
		t.Errorf("found %d", n)
	}
}

// A long text is cut around the hit at words, "…" where cut, and never
// inside a character.
func TestExcerptCuts(t *testing.T) {
	before := strings.Repeat("一二三 ", 40) //nolint:gosmopolitan // 160 characters, 3 bytes each but the spaces
	after := strings.Repeat("😀 ok ", 60)
	_, ex := New("needle").Find(before + "NEEDLE" + after)
	if ex.Match != "NEEDLE" {
		t.Fatalf("match %q", ex.Match)
	}
	for _, s := range []string{ex.Before, ex.After} {
		if !utf8.ValidString(s) {
			t.Errorf("cut inside a character: %q", s)
		}
	}
	if !strings.HasPrefix(ex.Before, "…一") || //nolint:gosmopolitan // multibyte text, on purpose
		utf8.RuneCountInString(ex.Before) > beforeChars+1 {
		t.Errorf("before %q", ex.Before)
	}
	if !strings.HasSuffix(ex.After, "…") || strings.HasSuffix(ex.After, " …") || utf8.RuneCountInString(ex.After) > afterChars+1 {
		t.Errorf("after %q", ex.After)
	}
	// Short sides stay whole.
	if _, ex := New("b").Find("a b c"); ex != (Excerpt{"a ", "b", " c"}) {
		t.Errorf("short: %+v", ex)
	}
}

// Lines hands on every line, skips one longer than MaxLine without
// keeping it, and stops when told or when ctx ends.
func TestLines(t *testing.T) {
	huge := bytes.Repeat([]byte("x"), MaxLine+10)
	in := "one\n" + string(huge) + "\n\ntwo\nthree"
	var got []string
	if err := Lines(t.Context(), strings.NewReader(in), func(l []byte) bool { got = append(got, string(l)); return true }); err != nil {
		t.Fatal(err)
	}
	if strings.Join(got, ",") != "one,two,three" {
		t.Errorf("lines %q", got)
	}
	got = nil
	_ = Lines(t.Context(), strings.NewReader(in), func(l []byte) bool { got = append(got, string(l)); return false })
	if len(got) != 1 {
		t.Errorf("didn't stop: %q", got)
	}
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	if err := Lines(ctx, strings.NewReader(in), func([]byte) bool { return true }); !errors.Is(err, context.Canceled) {
		t.Errorf("cancelled: %v", err)
	}
	// A line of exactly MaxLine, longer than the reader's buffer, comes whole.
	whole := bytes.Repeat([]byte("y"), MaxLine)
	n := 0
	_ = Lines(t.Context(), bytes.NewReader(whole), func(l []byte) bool { n = len(l); return true })
	if n != MaxLine {
		t.Errorf("long line %d bytes", n)
	}
}

// Each keeps the items' order, stops at max with more left, and ends
// with ctx, returning what it found before.
func TestEach(t *testing.T) {
	even := func(_ context.Context, i int) (int, bool) { return i, i%2 == 0 }
	found, more, err := Each(t.Context(), 100, 1000, even)
	if err != nil || more || len(found) != 50 || found[0] != 0 || found[49] != 98 {
		t.Errorf("all: %v %v %v", found, more, err)
	}
	found, more, _ = Each(t.Context(), 100, 3, even)
	if !more || len(found) != 3 || found[2] != 4 {
		t.Errorf("max: %v %v", found, more)
	}
	if found, more, _ := Each(t.Context(), 5, 3, even); more || len(found) != 3 {
		t.Errorf("max on the last: %v %v", found, more)
	}
	ctx, cancel := context.WithCancel(t.Context())
	found, more, err = Each(ctx, 100, 1000, func(ctx context.Context, i int) (int, bool) {
		if i == 10 {
			cancel()
		}
		if i >= 10 {
			<-ctx.Done()
			return 0, false
		}
		return i, true
	})
	if !errors.Is(err, context.Canceled) || !more || len(found) > 10 {
		t.Errorf("cancelled: %d found, %v %v", len(found), more, err)
	}
	if found, more, err := Each(t.Context(), 0, 5, even); found != nil || more || err != nil {
		t.Error("none")
	}
}

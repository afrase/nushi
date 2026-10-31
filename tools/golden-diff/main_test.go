package main

import (
	"bytes"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

var (
	white = color.NRGBA{R: 255, G: 255, B: 255, A: 255}
	red   = color.NRGBA{R: 255, A: 255}
)

// picture is a white image with paint's changes on it.
func picture(w, h int, paint func(*image.NRGBA)) *image.NRGBA {
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := range h {
		for x := range w {
			img.SetNRGBA(x, y, white)
		}
	}
	if paint != nil {
		paint(img)
	}
	return img
}

func encode(t *testing.T, img image.Image) []byte {
	t.Helper()
	var b bytes.Buffer
	testcheck.NoErr(t, png.Encode(&b, img))
	return b.Bytes()
}

func decoded(t *testing.T, data []byte) *image.RGBA {
	t.Helper()
	img, err := decode(data, nil)
	testcheck.NoErr(t, err)
	return img
}

// A golden saved as RGB and one saved as RGBA compare pixel by pixel: Go's
// encoder writes an alpha channel only when a pixel needs it, so the one
// transparent pixel is all that differs.
func TestRGBAndRGBACompare(t *testing.T) {
	opaque := encode(t, picture(4, 4, nil))
	alpha := encode(t, picture(4, 4, func(m *image.NRGBA) {
		m.SetNRGBA(3, 3, color.NRGBA{}) // not opaque, so png writes RGBA
	}))
	const colorType = 25 // the byte in a PNG's IHDR chunk
	if opaque[colorType] != 2 || alpha[colorType] != 6 {
		t.Fatalf("fixtures' color types: %d, %d, want RGB and RGBA", opaque[colorType], alpha[colorType])
	}
	c := compare("x.png", decoded(t, opaque), decoded(t, alpha))
	want := image.Rect(3, 3, 4, 4)
	if c.box != want || c.pixels != 1 {
		t.Errorf("box %v, %d px, want %v, 1 px: only the transparent pixel differs", c.box, c.pixels, want)
	}
}

func TestChangedArea(t *testing.T) {
	after := picture(10, 8, func(m *image.NRGBA) {
		m.SetNRGBA(2, 1, red)
		m.SetNRGBA(5, 6, red)
	})
	c := compare("x.png", decoded(t, encode(t, picture(10, 8, nil))), decoded(t, encode(t, after)))
	if want := image.Rect(2, 1, 6, 7); c.box != want || c.pixels != 2 {
		t.Errorf("box %v, %d px, want %v, 2 px", c.box, c.pixels, want)
	}
	if got := boxText(c.box); got != "x 2-5 y 1-6" {
		t.Errorf("box text %q", got)
	}
}

func TestParseRows(t *testing.T) {
	r, err := parseRows("0-44")
	if err != nil || r.first != 0 || r.last != 44 || !r.set {
		t.Fatalf("%+v, %v", r, err)
	}
	if !r.holds(image.Rect(0, 0, 9, 45)) || r.holds(image.Rect(0, 0, 9, 46)) {
		t.Error("row 44 is the last one inside, 45 the first outside")
	}
	for _, bad := range []string{"44", "9-3", "a-b", "-4"} {
		if _, err := parseRows(bad); err == nil {
			t.Errorf("%q was taken", bad)
		}
	}
}

// In a real repository: a group, an outlier, a new untracked golden, a
// removed one and one resized, against the working tree and between refs.
func TestRun(t *testing.T) {
	dir := t.TempDir()
	folder := filepath.Join(dir, goldens)
	testcheck.NoErr(t, os.MkdirAll(folder, 0o700))
	write := func(name string, img image.Image) {
		t.Helper()
		testcheck.NoErr(t, os.WriteFile(filepath.Join(folder, name), encode(t, img), 0o600))
	}
	for _, name := range []string{"a.png", "b.png", "odd.png", "gone.png", "resized.png"} {
		write(name, picture(20, 20, nil))
	}
	testcheck.Git(t, dir, "init", "-q")
	testcheck.Git(t, dir, "add", ".")
	testcheck.Git(t, dir, "commit", "-qm", "before")
	t.Chdir(dir)

	header := func(m *image.NRGBA) { m.SetNRGBA(3, 2, red); m.SetNRGBA(9, 4, red) }
	write("a.png", picture(20, 20, header))
	write("b.png", picture(20, 20, header))
	write("odd.png", picture(20, 20, func(m *image.NRGBA) { m.SetNRGBA(1, 15, red) }))
	testcheck.NoErr(t, os.Remove(filepath.Join(folder, "gone.png")))
	write("new.png", picture(6, 6, nil))

	var out strings.Builder
	failed, err := run(&out, "HEAD", "", rowRange{first: 0, last: 5, set: true})
	testcheck.NoErr(t, err)
	got := out.String()
	for _, want := range []string{
		"5 goldens changed: 2 in 1 groups, 3 outliers",
		"group of 2, x 3-9 y 2-4:\n  a.png 20x20 2 px\n  b.png 20x20 2 px\n",
		"gone.png 20x20, x 0-19 y 0-19, 400 px removed OUTSIDE ROWS 0-5",
		"new.png 6x6, x 0-5 y 0-5, 36 px new\n",
		"odd.png 20x20, x 1-1 y 15-15, 1 px OUTSIDE ROWS 0-5",
		"golden-diff: FAILED: 2 outside rows, 0 changed size\n",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("no %q in:\n%s", want, got)
		}
	}
	if !failed {
		t.Error("changes outside the rows passed")
	}
	if !strings.HasSuffix(got, "changed size\n") {
		t.Errorf("the verdict isn't the last line:\n%s", got)
	}

	// Without rows, new, removed and outlying changes are only listed.
	if failed, err := run(&strings.Builder{}, "HEAD", "", rowRange{}); err != nil || failed {
		t.Errorf("no expectation, but failed %v, %v", failed, err)
	}

	// A size change fails with or without rows, and refs compare without
	// the working tree: only what the commit holds counts.
	write("resized.png", picture(20, 30, nil))
	testcheck.Git(t, dir, "add", filepath.Join(goldens, "resized.png"))
	testcheck.Git(t, dir, "commit", "-qm", "after")
	out.Reset()
	failed, err = run(&out, "HEAD~1", "HEAD", rowRange{})
	testcheck.NoErr(t, err)
	if !failed || !strings.Contains(out.String(), "resized.png 20x20 -> 20x30 SIZE CHANGED") {
		t.Errorf("failed %v:\n%s", failed, out.String())
	}
	if strings.Contains(out.String(), "a.png") {
		t.Errorf("the working tree leaked into a comparison of refs:\n%s", out.String())
	}

	// A ref that doesn't exist says so, rather than reading as no changes.
	if _, err := run(&out, "no-such-ref", "", rowRange{}); err == nil {
		t.Error("a bad ref was taken")
	}
}

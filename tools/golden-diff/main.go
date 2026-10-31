// Command golden-diff says what changed in the app's goldens against a base:
// each file's size, the box around its changed pixels and how many changed,
// with identical boxes grouped so a change that reaches 57 files reads as
// one, and the rest listed as outliers. It compares pixels, not bytes, so a
// golden saved as RGB and one saved as RGBA match when they look the same.
// Run it from the repository root: make golden-diff.
//
// It exits 1 when a golden changed size, or, given -rows, when a change
// reaches outside them (a new or removed golden is a change to all of it),
// and 2 when it can't tell (a bad ref, an unreadable image).
package main

import (
	"bytes"
	"context"
	"flag"
	"fmt"
	"image"
	"image/draw"
	"image/png"
	"log"
	"os"
	"os/exec"
	"path"
	"slices"
	"strconv"
	"strings"
)

const goldens = "app/test/goldens"

func main() {
	log.SetFlags(0)
	base := flag.String("base", "HEAD", "the ref to compare against")
	to := flag.String("to", "", "the ref to compare, instead of the working tree")
	rowsFlag := flag.String("rows", "", "the pixel rows changes must stay in, first-last")
	flag.Parse()
	rows, err := parseRows(*rowsFlag)
	if err != nil {
		log.Println(err)
		os.Exit(2)
	}
	var out strings.Builder
	failed, err := run(&out, *base, *to, rows)
	if _, werr := os.Stdout.WriteString(out.String()); werr != nil {
		log.Println(werr)
		os.Exit(2)
	}
	if err != nil {
		log.Println(err)
		os.Exit(2)
	}
	if failed {
		os.Exit(1)
	}
}

// rowRange is the pixel rows changes are expected in, both ends included.
// The zero value, with set false, expects nothing.
type rowRange struct {
	first, last int
	set         bool
}

func parseRows(s string) (rowRange, error) {
	if s == "" {
		return rowRange{}, nil
	}
	first, last, ok := strings.Cut(s, "-")
	a, errA := strconv.Atoi(first)
	b, errB := strconv.Atoi(last)
	if !ok || errA != nil || errB != nil || a < 0 || b < a {
		return rowRange{}, fmt.Errorf("rows %q: want first-last, such as 0-44", s)
	}
	return rowRange{first: a, last: b, set: true}, nil
}

// holds says whether box, whose Max is exclusive, lies within the rows.
func (r rowRange) holds(box image.Rectangle) bool {
	return !r.set || box.Empty() || box.Min.Y >= r.first && box.Max.Y-1 <= r.last
}

func (r rowRange) String() string { return fmt.Sprintf("%d-%d", r.first, r.last) }

// change is what happened to one golden.
type change struct {
	file    string
	kind    string          // "", "new", "removed" or "resized"
	size    image.Point     // the new image's, or for a removed one the old
	oldSize image.Point     // a resized one's before
	box     image.Rectangle // around the changed pixels, empty when none
	pixels  int
}

// run reports the goldens that changed from base to the ref to (the working
// tree when to is empty), and says whether an expectation failed.
func run(out *strings.Builder, base, to string, rows rowRange) (bool, error) {
	from, err := commit(base)
	if err != nil {
		return false, err
	}
	var target string
	if to != "" {
		if target, err = commit(to); err != nil {
			return false, err
		}
	}
	files, err := changedFiles(from, target)
	if err != nil {
		return false, err
	}
	changes := make([]change, 0, len(files))
	for _, f := range files {
		c, err := compareFile(f.path, f.status, from, target)
		if err != nil {
			return false, fmt.Errorf("%s: %w", f.path, err)
		}
		changes = append(changes, c)
	}
	return report(out, changes, rows), nil
}

// commit is ref's commit, so a mistyped ref stops here rather than reading
// as no changes.
func commit(ref string) (string, error) {
	got, err := git("rev-parse", "--verify", "--end-of-options", ref+"^{commit}")
	if err != nil {
		return "", fmt.Errorf("ref %q: %w", ref, err)
	}
	return strings.TrimSpace(string(got)), nil
}

func git(args ...string) ([]byte, error) {
	cmd := exec.CommandContext(context.Background(), "git", args...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	got, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("git %s: %w: %s", args[0], err, bytes.TrimSpace(stderr.Bytes()))
	}
	return got, nil
}

// changedFile is a line of git's status: a path and a letter (A, D, M...).
type changedFile struct{ path, status string }

// changedFiles lists the goldens that differ. A rename is a removal and a
// new file, and against the working tree a new file counts before it's
// added: --update-goldens leaves new ones untracked, which git diff omits.
func changedFiles(from, to string) ([]changedFile, error) {
	args := []string{"diff", "--name-status", "--no-renames", "-z", from}
	if to != "" {
		args = append(args, to)
	}
	got, err := git(append(args, "--", goldens)...)
	if err != nil {
		return nil, err
	}
	var files []changedFile
	fields := strings.Split(string(got), "\x00")
	for i := 0; i+1 < len(fields); i += 2 {
		files = append(files, changedFile{path: fields[i+1], status: fields[i]})
	}
	if to == "" {
		got, err := git("ls-files", "-z", "--others", "--exclude-standard", "--", goldens)
		if err != nil {
			return nil, err
		}
		for p := range strings.SplitSeq(string(got), "\x00") {
			if p != "" {
				files = append(files, changedFile{path: p, status: "A"})
			}
		}
	}
	return slices.DeleteFunc(files, func(f changedFile) bool {
		return path.Ext(f.path) != ".png"
	}), nil
}

func compareFile(file, status, from, to string) (change, error) {
	name := strings.TrimPrefix(file, goldens+"/")
	var before, after *image.RGBA
	var err error
	if status != "A" {
		if before, err = decode(readAt(from, file)); err != nil {
			return change{}, err
		}
	}
	if status != "D" {
		if after, err = decode(readAt(to, file)); err != nil {
			return change{}, err
		}
	}
	return compare(name, before, after), nil
}

// readAt is file at ref, or in the working tree when ref is empty. It takes
// the blob as stored, without the filters git show could apply.
func readAt(ref, file string) ([]byte, error) {
	if ref == "" {
		return os.ReadFile(file)
	}
	return git("cat-file", "blob", ref+":"+file)
}

// decode gives every PNG the same pixel layout: Go decodes RGB and RGBA ones
// to different image types, and a golden can be either. Pixels are
// premultiplied, so what's fully transparent matches whatever its color.
func decode(data []byte, readErr error) (*image.RGBA, error) {
	if readErr != nil {
		return nil, readErr
	}
	img, err := png.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	b := img.Bounds()
	out := image.NewRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	draw.Draw(out, out.Rect, img, b.Min, draw.Src)
	return out, nil
}

// compare says how after differs from before, either being nil for a golden
// that isn't there.
func compare(name string, before, after *image.RGBA) change {
	switch {
	case before == nil && after == nil:
		return change{file: name}
	case before == nil:
		return whole(name, "new", after)
	case after == nil:
		return whole(name, "removed", before)
	}
	c := change{file: name, size: after.Rect.Size()}
	if before.Rect != after.Rect {
		c.kind, c.oldSize = "resized", before.Rect.Size()
		return c
	}
	c.box, c.pixels = changedArea(before, after)
	return c
}

func whole(name, kind string, img *image.RGBA) change {
	size := img.Rect.Size()
	return change{file: name, kind: kind, size: size, box: img.Rect, pixels: size.X * size.Y}
}

// changedArea is the box around the pixels that differ between two images of
// one size, and how many there are.
func changedArea(a, b *image.RGBA) (image.Rectangle, int) {
	var box image.Rectangle
	count := 0
	size := a.Rect.Size()
	for y := range size.Y {
		rowA := a.Pix[y*a.Stride:][:size.X*4]
		rowB := b.Pix[y*b.Stride:][:size.X*4]
		if bytes.Equal(rowA, rowB) {
			continue
		}
		for x := range size.X {
			if bytes.Equal(rowA[x*4:x*4+4], rowB[x*4:x*4+4]) {
				continue
			}
			count++
			box = box.Union(image.Rect(x, y, x+1, y+1))
		}
	}
	return box, count
}

// report prints the changes and says whether one broke an expectation. Its
// last line is the verdict when something did, so tail still shows it.
func report(out *strings.Builder, changes []change, rows rowRange) bool {
	if len(changes) == 0 {
		fmt.Fprintln(out, "no goldens changed")
		return false
	}
	groups, outliers, same := sortChanges(changes)
	fmt.Fprintf(out, "%d goldens changed: %d in %d groups, %d outliers, %d with the same pixels\n",
		len(changes), len(changes)-len(outliers)-len(same), len(groups), len(outliers), len(same))
	outside, resized := 0, 0
	for _, g := range groups {
		mark := ""
		if !rows.holds(g[0].box) {
			mark = " OUTSIDE ROWS " + rows.String()
			outside += len(g)
		}
		fmt.Fprintf(out, "group of %d, %s%s:\n", len(g), boxText(g[0].box), mark)
		for _, c := range g {
			fmt.Fprintf(out, "  %s %s %d px\n", c.file, sizeText(c.size), c.pixels)
		}
	}
	if len(outliers) > 0 {
		fmt.Fprintln(out, "outliers:")
	}
	for _, c := range outliers {
		switch {
		case c.kind == "resized":
			resized++
			fmt.Fprintf(out, "  %s %s -> %s SIZE CHANGED\n", c.file, sizeText(c.oldSize), sizeText(c.size))
			continue
		case !rows.holds(c.box):
			outside++
			c.kind = strings.TrimSpace(c.kind + " OUTSIDE ROWS " + rows.String())
		}
		line := fmt.Sprintf("  %s %s, %s, %d px %s", c.file, sizeText(c.size), boxText(c.box), c.pixels, c.kind)
		fmt.Fprintln(out, strings.TrimRight(line, " "))
	}
	if len(same) > 0 {
		fmt.Fprintln(out, "same pixels, saved anew:")
	}
	for _, c := range same {
		fmt.Fprintf(out, "  %s %s\n", c.file, sizeText(c.size))
	}
	if outside == 0 && resized == 0 {
		return false
	}
	fmt.Fprintf(out, "golden-diff: FAILED: %d outside rows, %d changed size\n", outside, resized)
	return true
}

// sortChanges splits the changes into groups of two or more with one box,
// the largest first; outliers (a box of its own, or a golden new, removed or
// resized); and those whose pixels didn't change.
func sortChanges(changes []change) (groups [][]change, outliers, same []change) {
	byBox := map[image.Rectangle][]change{}
	for _, c := range changes {
		switch {
		case c.kind != "":
			outliers = append(outliers, c)
		case c.pixels == 0:
			same = append(same, c)
		default:
			byBox[c.box] = append(byBox[c.box], c)
		}
	}
	for _, g := range byBox {
		if len(g) == 1 {
			outliers = append(outliers, g[0])
			continue
		}
		groups = append(groups, g)
	}
	byFile := func(a, b change) int { return strings.Compare(a.file, b.file) }
	slices.SortFunc(outliers, byFile)
	slices.SortFunc(same, byFile)
	for _, g := range groups {
		slices.SortFunc(g, byFile)
	}
	slices.SortFunc(groups, func(a, b []change) int {
		if len(a) != len(b) {
			return len(b) - len(a)
		}
		return strings.Compare(a[0].file, b[0].file)
	})
	return groups, outliers, same
}

func sizeText(p image.Point) string { return fmt.Sprintf("%dx%d", p.X, p.Y) }

// boxText prints a box's columns and rows, both ends included, as -rows
// takes them.
func boxText(b image.Rectangle) string {
	return fmt.Sprintf("x %d-%d y %d-%d", b.Min.X, b.Max.X-1, b.Min.Y, b.Max.Y-1)
}

package git

import (
	"errors"
	"fmt"
	"maps"
	"slices"
)

// A file's change blocks, as the Changes view shows them (diff_view's
// TextDiff): runs of lines that differ between the HEAD text and the work
// tree's, with runs of equal lines (gaps) between them. Lines are split at
// "\n", a "\r" before it is the line's ending and not its text, and a last
// line without one is a line; lines compare by text alone, as the view's
// do. The index a file stages in blocks (ADR 0079's hunk amendment) is the
// HEAD text with the staged blocks' lines taken from the work tree's.

// Block is one change block: lines [OldStart, OldEnd) of the HEAD text
// become lines [NewStart, NewEnd) of the work tree's, from 0.
type Block struct{ OldStart, OldEnd, NewStart, NewEnd int }

// ErrBlocksDontFit is a request whose blocks aren't the file's changes:
// the app's view and the daemon's read don't line up.
var ErrBlocksDontFit = errors.New("the changes don't line up with the file; look again")

// maxPaths caps the ways an index is matched to blocks at each block, past
// which it is taken not to be made of them: each gap pins the match, so a
// real file keeps one or two.
const maxPaths = 256

// line is one line: its text and its ending ("\n", "\r\n" or "" for a last
// line without one).
type line struct{ text, end string }

// splitLines splits b as the view does.
func splitLines(b []byte) []line {
	var out []line
	s := string(b)
	for s != "" {
		i := 0
		for i < len(s) && s[i] != '\n' {
			i++
		}
		if i == len(s) {
			out = append(out, line{text: s})
			break
		}
		l := line{text: s[:i], end: "\n"}
		if i > 0 && s[i-1] == '\r' {
			l = line{text: s[:i-1], end: "\r\n"}
		}
		out = append(out, l)
		s = s[i+1:]
	}
	return out
}

// sameText says two runs of lines have the same texts.
func sameText(a, b []line) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i].text != b[i].text {
			return false
		}
	}
	return true
}

// checkBlocks says blocks are every change from old to cur, in order: each
// in range and after the last, at least one line on a side, and the gaps
// between them equal on both sides.
func checkBlocks(old, cur []line, blocks []Block) error {
	o, n := 0, 0
	gap := func(oEnd, nEnd int) bool {
		return oEnd-o == nEnd-n && sameText(old[o:oEnd], cur[n:nEnd])
	}
	for i, b := range blocks {
		switch {
		case b.OldStart < o || b.NewStart < n || b.OldEnd < b.OldStart || b.NewEnd < b.NewStart ||
			b.OldEnd > len(old) || b.NewEnd > len(cur):
			return fmt.Errorf("change %d is out of place: %w", i+1, ErrBlocksDontFit)
		case b.OldEnd == b.OldStart && b.NewEnd == b.NewStart:
			return fmt.Errorf("change %d is empty: %w", i+1, ErrBlocksDontFit)
		case !gap(b.OldStart, b.NewStart):
			return fmt.Errorf("the lines before change %d differ: %w", i+1, ErrBlocksDontFit)
		}
		o, n = b.OldEnd, b.NewEnd
	}
	if !gap(len(old), len(cur)) {
		return fmt.Errorf("the lines after the last change differ: %w", ErrBlocksDontFit)
	}
	return nil
}

// matchBlocks says which blocks the index text holds: the staged ones'
// lines are the work tree's, the rest HEAD's, and the gaps are as they are
// on both sides. ok is false when the index isn't made of them that way (a
// file staged and changed again since, or edited in the index). Where two
// choices make the same index, the unstaged one wins, the earliest block
// first.
func matchBlocks(old, cur, index []line, blocks []Block) (staged []bool, ok bool) {
	type step struct {
		from   int // the position in index the block's choice started from
		staged bool
	}
	// at[k] maps each position in index reachable after block k's choice
	// (and the gap after it) to how it was reached.
	at := make([]map[int]step, len(blocks))
	reach := map[int]bool{}
	if g := old[:firstStart(blocks, len(old))]; len(g) <= len(index) && sameText(index[:len(g)], g) {
		reach[len(g)] = true
	}
	for k, b := range blocks {
		nextOld := len(old)
		if k+1 < len(blocks) {
			nextOld = blocks[k+1].OldStart
		}
		gap := old[b.OldEnd:nextOld]
		at[k] = map[int]step{}
		for _, p := range slices.Sorted(maps.Keys(reach)) { // the same match every run
			for _, choice := range []struct {
				lines  []line
				staged bool
			}{{old[b.OldStart:b.OldEnd], false}, {cur[b.NewStart:b.NewEnd], true}} {
				end := p + len(choice.lines) + len(gap)
				if end > len(index) || !sameText(index[p:p+len(choice.lines)], choice.lines) ||
					!sameText(index[p+len(choice.lines):end], gap) {
					continue
				}
				if _, seen := at[k][end]; !seen {
					at[k][end] = step{from: p, staged: choice.staged}
				}
			}
		}
		if len(at[k]) == 0 || len(at[k]) > maxPaths {
			return nil, false
		}
		reach = map[int]bool{}
		for p := range at[k] {
			reach[p] = true
		}
	}
	if !reach[len(index)] {
		return nil, false
	}
	staged = make([]bool, len(blocks))
	p := len(index)
	for k := len(blocks) - 1; k >= 0; k-- {
		s := at[k][p]
		staged[k], p = s.staged, s.from
	}
	return staged, true
}

// firstStart is where the first block starts on the old side, or end with
// none.
func firstStart(blocks []Block, end int) int {
	if len(blocks) == 0 {
		return end
	}
	return blocks[0].OldStart
}

// assemble is the index text with the staged blocks: their lines as the
// work tree has them, every other line as HEAD has it. A line HEAD ends
// the file with, without a newline, takes the work tree's ending when more
// lines now follow it.
func assemble(old, cur []line, blocks []Block, staged []bool) []byte {
	var out []line
	var gapOf []int // for each line out, its line in cur when it is a gap's, else -1
	add := func(ls []line, from int) {
		for i, l := range ls {
			out = append(out, l)
			at := -1
			if from >= 0 {
				at = from + i
			}
			gapOf = append(gapOf, at)
		}
	}
	o, n := 0, 0
	for k, b := range blocks {
		add(old[o:b.OldStart], n)
		if staged[k] {
			add(cur[b.NewStart:b.NewEnd], -1)
		} else {
			add(old[b.OldStart:b.OldEnd], -1)
		}
		o, n = b.OldEnd, b.NewEnd
	}
	add(old[o:], n)
	var b []byte
	for i, l := range out {
		end := l.end
		if end == "" && i < len(out)-1 {
			end = "\n"
			if g := gapOf[i]; g >= 0 && cur[g].end != "" {
				end = cur[g].end
			}
		}
		b = append(append(b, l.text...), end...)
	}
	return b
}

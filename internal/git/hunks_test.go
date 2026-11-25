package git

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// blocksOf is the change blocks of old to cur, as the view finds them: a
// longest common run of lines by text, the runs between as blocks.
func blocksOf(old, cur string) []Block {
	a, b := splitLines([]byte(old)), splitLines([]byte(cur))
	lcs := make([][]int, len(a)+1)
	for i := range lcs {
		lcs[i] = make([]int, len(b)+1)
	}
	for i := range slices.Backward(a) {
		for j := range slices.Backward(b) {
			if a[i].text == b[j].text {
				lcs[i][j] = lcs[i+1][j+1] + 1
			} else {
				lcs[i][j] = max(lcs[i+1][j], lcs[i][j+1])
			}
		}
	}
	var blocks []Block
	i, j := 0, 0
	open := false
	for i < len(a) || j < len(b) {
		switch {
		case i < len(a) && j < len(b) && a[i].text == b[j].text:
			if open {
				blocks[len(blocks)-1].OldEnd, blocks[len(blocks)-1].NewEnd = i, j
				open = false
			}
			i, j = i+1, j+1
			continue
		case !open:
			blocks = append(blocks, Block{OldStart: i, NewStart: j})
			open = true
		}
		if j >= len(b) || i < len(a) && lcs[i+1][j] >= lcs[i][j+1] {
			i++
		} else {
			j++
		}
	}
	if open {
		blocks[len(blocks)-1].OldEnd, blocks[len(blocks)-1].NewEnd = i, j
	}
	return blocks
}

func TestBlocksOf(t *testing.T) {
	got := blocksOf("a\nb\nc\nd\n", "a\nB\nc\nd\ne\n")
	want := []Block{{1, 2, 1, 2}, {4, 4, 4, 5}}
	if !slices.Equal(got, want) {
		t.Fatalf("%v", got)
	}
}

// hunkRepo is a repository with path committed as text, then written as
// now in the work tree.
func hunkRepo(t *testing.T, path, text, now string) string {
	t.Helper()
	repo := t.TempDir()
	testcheck.Git(t, repo, "init", "-q")
	testcheck.Git(t, repo, "config", "core.autocrlf", "false")
	testcheck.Write(t, filepath.Join(repo, path), text)
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")
	testcheck.Write(t, filepath.Join(repo, path), now)
	return repo
}

// shown is path's change as Changes shows it in folder, and its blocks.
func shown(t *testing.T, folder, path string) (token string, blocks []Block) {
	t.Helper()
	changes, err := Changes(context.Background(), folder, Span{})
	testcheck.NoErr(t, err)
	for _, c := range changes {
		if c.Path == path {
			return c.Hunks, blocksOf(c.Old, c.New)
		}
	}
	t.Fatalf("%s isn't changed", path)
	return "", nil
}

// press stages (or unstages) path's blocks pressed, as shown now.
func press(t *testing.T, folder, path string, on bool, pressed ...int) []bool {
	t.Helper()
	token, blocks := shown(t, folder, path)
	if token == "" {
		t.Fatalf("%s doesn't stage in blocks", path)
	}
	states, err := StageHunks(context.Background(), folder, path, token, blocks, pressed, on)
	testcheck.NoErr(t, err)
	return states
}

// indexOf is path's text in folder's index, byte for byte.
func indexOf(t *testing.T, folder, path string) string {
	t.Helper()
	out, err := exec.Command("git", "-C", folder, "cat-file", "blob", ":./"+path).Output()
	testcheck.NoErr(t, err)
	return string(out)
}

func TestStageHunks(t *testing.T) {
	const head = "one\ntwo\nthree\nfour\nfive\nsix\nseven\n"
	const now = "ONE\ntwo\nthree\nFOUR\nfive\nsix\nSEVEN\n" // the first, middle and last line changed: three blocks
	cases := []struct {
		name    string
		pressed []int
		index   string
		after   string // with the first pressed unstaged again
	}{
		{"the middle of three", []int{1}, "one\ntwo\nthree\nFOUR\nfive\nsix\nseven\n", head},
		{"the first, at the file's start", []int{0}, "ONE\ntwo\nthree\nfour\nfive\nsix\nseven\n", head},
		{"the last, at the file's end", []int{2}, "one\ntwo\nthree\nfour\nfive\nsix\nSEVEN\n", head},
		{"two at once", []int{0, 2}, "ONE\ntwo\nthree\nfour\nfive\nsix\nSEVEN\n", "one\ntwo\nthree\nfour\nfive\nsix\nSEVEN\n"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			repo := hunkRepo(t, "f.txt", head, now)
			states := press(t, repo, "f.txt", true, c.pressed...)
			if got := indexOf(t, repo, "f.txt"); got != c.index {
				t.Fatalf("index %q, want %q", got, c.index)
			}
			for k, on := range states {
				if on != slices.Contains(c.pressed, k) {
					t.Errorf("states %v", states)
				}
			}
			if b, _ := os.ReadFile(filepath.Join(repo, "f.txt")); string(b) != now {
				t.Errorf("the work tree was written: %q", b)
			}
			if st := stagedOf(t, repo)["f.txt"]; st != "part" {
				t.Errorf("staged %q", st)
			}
			// Unstaging it takes exactly its lines back out.
			press(t, repo, "f.txt", false, c.pressed[0])
			if got := indexOf(t, repo, "f.txt"); got != c.after {
				t.Fatalf("unstaged: index %q", got)
			}
		})
	}
}

func TestStageHunksAllThenNone(t *testing.T) {
	const head = "a\nb\nc\nd\ne\n"
	const now = "a\nB\nc\nd\nE\nf\n"
	repo := hunkRepo(t, "f.txt", head, now)
	press(t, repo, "f.txt", true, 0, 1)
	if got := indexOf(t, repo, "f.txt"); got != now {
		t.Fatalf("all staged: %q", got)
	}
	if st := stagedOf(t, repo)["f.txt"]; st != "all" {
		t.Errorf("staged %q", st)
	}
	press(t, repo, "f.txt", false, 0, 1)
	if got := indexOf(t, repo, "f.txt"); got != head {
		t.Fatalf("none staged: %q", got)
	}
	if st := stagedOf(t, repo)["f.txt"]; st != "" {
		t.Errorf("staged %q", st)
	}
}

func TestStageHunksNoNewlineAtEnd(t *testing.T) {
	ctx := context.Background()
	// HEAD's last line has no newline; the work tree adds a line after it,
	// and changes the first.
	repo := hunkRepo(t, "f.txt", "a\nb\nc", "A\nb\nc\nd")
	press(t, repo, "f.txt", true, 1)
	if got := indexOf(t, repo, "f.txt"); got != "a\nb\nc\nd" {
		t.Fatalf("the line after: %q", got)
	}
	press(t, repo, "f.txt", true, 0)
	if got := indexOf(t, repo, "f.txt"); got != "A\nb\nc\nd" {
		t.Fatalf("both: %q", got)
	}
	// The last line changed, the newline gone with it.
	repo = hunkRepo(t, "f.txt", "a\nb\nc\n", "A\nb\nC")
	press(t, repo, "f.txt", true, 1)
	if got := indexOf(t, repo, "f.txt"); got != "a\nb\nC" {
		t.Fatalf("the last line: %q", got)
	}
	token, blocks := shown(t, repo, "f.txt")
	states, ok, err := HunkStates(ctx, repo, "f.txt", token, blocks)
	if err != nil || !ok || !slices.Equal(states, []bool{false, true}) {
		t.Fatalf("states %v, %v, %v", states, ok, err)
	}
}

func TestStageHunksCRLF(t *testing.T) {
	repo := hunkRepo(t, "f.txt", "a\r\nb\r\nc\r\nd\r\n", "A\r\nb\r\nc\r\nD\r\n")
	press(t, repo, "f.txt", true, 1)
	if got := indexOf(t, repo, "f.txt"); got != "a\r\nb\r\nc\r\nD\r\n" {
		t.Fatalf("index %q", got)
	}
	// With autocrlf, the repository holds \n and the work tree \r\n: the
	// staged lines go in as git add would put them.
	repo = t.TempDir()
	testcheck.Git(t, repo, "init", "-q")
	testcheck.Git(t, repo, "config", "core.autocrlf", "true")
	testcheck.Write(t, filepath.Join(repo, "f.txt"), "a\r\nb\r\nc\r\nd\r\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")
	testcheck.Write(t, filepath.Join(repo, "f.txt"), "A\r\nb\r\nc\r\nD\r\n")
	press(t, repo, "f.txt", true, 0)
	if got := indexOf(t, repo, "f.txt"); got != "A\nb\nc\nd\n" {
		t.Fatalf("autocrlf: index %q", got)
	}
	press(t, repo, "f.txt", true, 1)
	if st := stagedOf(t, repo)["f.txt"]; st != "all" {
		t.Errorf("autocrlf, both staged: %q", st)
	}
}

// A file with a staged block and an unstaged one shows each as it is, and
// staging the other leaves the first.
func TestHunkStatesMixed(t *testing.T) {
	ctx := context.Background()
	repo := hunkRepo(t, "f.txt", "a\nb\nc\nd\ne\n", "A\nb\nc\nd\nE\n")
	press(t, repo, "f.txt", true, 1)
	token, blocks := shown(t, repo, "f.txt")
	states, ok, err := HunkStates(ctx, repo, "f.txt", token, blocks)
	if err != nil || !ok || !slices.Equal(states, []bool{false, true}) {
		t.Fatalf("states %v, %v, %v", states, ok, err)
	}
	if got := press(t, repo, "f.txt", true, 0); !slices.Equal(got, []bool{true, true}) {
		t.Fatalf("after %v", got)
	}
}

func TestStageHunksTwiceAndGuard(t *testing.T) {
	ctx := context.Background()
	repo := hunkRepo(t, "f.txt", "a\nb\nc\nd\ne\n", "A\nb\nc\nd\nE\n")
	token, blocks := shown(t, repo, "f.txt")
	_, err := StageHunks(ctx, repo, "f.txt", token, blocks, []int{0}, true)
	testcheck.NoErr(t, err)
	// The same press again on the same look: the index moved, so refused.
	if _, err := StageHunks(ctx, repo, "f.txt", token, blocks, []int{0}, true); !errors.Is(err, ErrFileMoved) {
		t.Fatalf("pressed twice on one look: %v", err)
	}
	// On a fresh look, staging it again changes nothing.
	before := indexOf(t, repo, "f.txt")
	if got := press(t, repo, "f.txt", true, 0); !slices.Equal(got, []bool{true, false}) || indexOf(t, repo, "f.txt") != before {
		t.Fatalf("staged twice: %v %q", got, indexOf(t, repo, "f.txt"))
	}
	// The work tree changed underneath.
	token, blocks = shown(t, repo, "f.txt")
	testcheck.Write(t, filepath.Join(repo, "f.txt"), "A\nb\nc\nd\nE\nmore\n")
	if _, err := StageHunks(ctx, repo, "f.txt", token, blocks, []int{1}, true); !errors.Is(err, ErrFileMoved) {
		t.Fatalf("the file changed: %v", err)
	}
	// Staged by someone else underneath.
	token, blocks = shown(t, repo, "f.txt")
	testcheck.Git(t, repo, "add", "f.txt")
	if _, _, err := HunkStates(ctx, repo, "f.txt", token, blocks); !errors.Is(err, ErrFileMoved) {
		t.Fatalf("staged since: %v", err)
	}
	if got := indexOf(t, repo, "f.txt"); got != "A\nb\nc\nd\nE\nmore\n" {
		t.Fatalf("a refused press wrote the index: %q", got)
	}
}

// Blocks that aren't the file's changes are refused, never written.
func TestStageHunksBlocksDontFit(t *testing.T) {
	ctx := context.Background()
	repo := hunkRepo(t, "f.txt", "a\nb\nc\n", "a\nB\nc\n")
	token, _ := shown(t, repo, "f.txt")
	for _, blocks := range [][]Block{
		{{0, 1, 0, 1}},               // a gap that isn't one
		{{1, 2, 1, 2}, {1, 2, 1, 2}}, // overlapping
		{{1, 2, 1, 9}},               // past the end
		{{1, 1, 1, 1}},               // empty
	} {
		if _, err := StageHunks(ctx, repo, "f.txt", token, blocks, []int{0}, true); !errors.Is(err, ErrBlocksDontFit) {
			t.Errorf("%v: %v", blocks, err)
		}
	}
	if _, err := StageHunks(ctx, repo, "f.txt", token, []Block{{1, 2, 1, 2}}, []int{1}, true); !errors.Is(err, ErrBlocksDontFit) {
		t.Errorf("a press past the blocks: %v", err)
	}
	if got := indexOf(t, repo, "f.txt"); got != "a\nb\nc\n" {
		t.Fatalf("written: %q", got)
	}
}

// A file staged, then changed again, has an index its blocks don't make:
// it stages whole.
func TestStageHunksWholeFileOnly(t *testing.T) {
	ctx := context.Background()
	repo := hunkRepo(t, "f.txt", "a\nb\nc\n", "a\nX\nc\n")
	testcheck.Git(t, repo, "add", "f.txt")
	testcheck.Write(t, filepath.Join(repo, "f.txt"), "a\nY\nc\n")
	token, blocks := shown(t, repo, "f.txt")
	if _, ok, err := HunkStates(ctx, repo, "f.txt", token, blocks); err != nil || ok {
		t.Fatalf("fits %v, %v", ok, err)
	}
	if _, err := StageHunks(ctx, repo, "f.txt", token, blocks, []int{0}, true); !errors.Is(err, ErrWholeFileOnly) {
		t.Fatalf("%v", err)
	}
}

// Paths with spaces and non-ASCII letters, in a folder below the
// repository's top, and an executable's mode kept.
func TestStageHunksPaths(t *testing.T) {
	const path = "dir é/naïve file.txt"
	repo := hunkRepo(t, path, "a\nb\nc\nd\n", "a\nb\nc\nd\n")
	testcheck.NoErr(t, os.Chmod(filepath.Join(repo, path), 0o755))
	testcheck.Git(t, repo, "commit", "-q", "-am", "executable")
	testcheck.Write(t, filepath.Join(repo, path), "A\nb\nc\nD\n")
	sub := filepath.Join(repo, "dir é")
	press(t, sub, "naïve file.txt", true, 1)
	if got := indexOf(t, sub, "naïve file.txt"); got != "a\nb\nc\nD\n" {
		t.Fatalf("index %q", got)
	}
	if mode := testcheck.Git(t, repo, "ls-files", "-s", "--", path); !strings.HasPrefix(mode, "100755 ") {
		t.Fatalf("mode %q", mode)
	}
}

// What makes no sense a block at a time stages whole: no token.
func TestHunksWholeFiles(t *testing.T) {
	repo := t.TempDir()
	testcheck.Git(t, repo, "init", "-q")
	for name, text := range map[string]string{"gone.txt": "x\n", "old.txt": "1\n2\n3\n4\n5\n6\n", "bin": "a\x00b", "lfs.dat": "a\n", "link": ""} {
		if name != "link" {
			testcheck.Write(t, filepath.Join(repo, name), text)
		}
	}
	testcheck.NoErr(t, os.Symlink("old.txt", filepath.Join(repo, "link")))
	testcheck.Write(t, filepath.Join(repo, ".gitattributes"), "lfs.dat filter=made-up\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")
	testcheck.NoErr(t, os.Remove(filepath.Join(repo, "gone.txt")))
	testcheck.Git(t, repo, "mv", "old.txt", "new.txt")
	testcheck.Write(t, filepath.Join(repo, "new.txt"), "1\n2\n3\n4\n5\n6\n7\n")
	testcheck.Write(t, filepath.Join(repo, "bin"), "c\x00d")
	testcheck.Write(t, filepath.Join(repo, "lfs.dat"), "b\n")
	testcheck.Write(t, filepath.Join(repo, "added.txt"), "new\n")
	testcheck.NoErr(t, os.Remove(filepath.Join(repo, "link")))
	testcheck.NoErr(t, os.Symlink("new.txt", filepath.Join(repo, "link")))
	changes, err := Changes(context.Background(), repo, Span{})
	testcheck.NoErr(t, err)
	if len(changes) < 6 {
		t.Fatalf("%+v", changes)
	}
	for _, c := range changes {
		if c.Hunks != "" {
			t.Errorf("%s (%s) stages in blocks", c.Path, c.Status)
		}
	}
}

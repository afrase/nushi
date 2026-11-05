package folderlist

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

// names are a listing's entries' names, a folder's ending in "/", an
// ignored one's in "!", a link not followed's in "@".
func names(l Listing) []string {
	var out []string
	for _, e := range l.Entries {
		n := e.Name
		switch e.Kind {
		case Folder:
			n += "/"
		case Link:
			n += "@"
		case File, Other:
		}
		if e.Ignored {
			n += "!"
		}
		out = append(out, n)
	}
	return out
}

func listOf(t *testing.T, root, rel string, o Options) []Listing {
	t.Helper()
	ls, err := List(context.Background(), root, rel, o)
	testcheck.NoErr(t, err)
	return ls
}

func TestCleanRefusesWhatLeadsOut(t *testing.T) {
	for _, p := range []string{"..", "../x", "a/../../x", "/etc", "a//b", "a/", "./a", "a/./b",
		".git", "a/.git/objects", ".GIT", ".Git/config", "a/.gIt", "a\x00b", strings.Repeat("a/", 3000), "\xff"} {
		if got, err := Clean(p); !errors.Is(err, ErrPath) {
			t.Errorf("Clean(%q) = %q, %v; want ErrPath", p, got, err)
		}
	}
	for p, want := range map[string]string{"": ".", ".": ".", "app/lib": "app/lib", ".github": ".github", "a b": "a b"} {
		if got, err := Clean(p); err != nil || got != want {
			t.Errorf("Clean(%q) = %q, %v; want %q", p, got, err, want)
		}
	}
}

func TestListsFoldersFirstWithoutGit(t *testing.T) {
	root := t.TempDir()
	testcheck.Git(t, root, "init", "-q")
	testcheck.Write(t, filepath.Join(root, "b.md"), "hello")
	testcheck.Write(t, filepath.Join(root, "A.txt"), "")
	testcheck.Write(t, filepath.Join(root, "zeta", "x.go"), "")
	testcheck.Write(t, filepath.Join(root, "Alpha", "y.go"), "")
	ls := listOf(t, root, ".", Options{})
	if len(ls) != 1 || ls[0].Path != "" || ls[0].More != 0 {
		t.Fatalf("listing: %+v", ls)
	}
	if got, want := names(ls[0]), []string{"Alpha/", "zeta/", "A.txt", "b.md"}; !slices.Equal(got, want) {
		t.Errorf("names = %q, want %q", got, want)
	}
	b := ls[0].Entries[3]
	if b.Size != 5 || b.Modified.IsZero() || b.Kind != File {
		t.Errorf("b.md: %+v", b)
	}
	if _, err := List(context.Background(), root, "b.md", Options{}); !errors.Is(err, ErrFolder) {
		t.Errorf("a file listed: %v", err)
	}
	if ls := listOf(t, root, "gone", Options{}); !ls[0].Missing {
		t.Errorf("a folder that isn't there: %+v", ls)
	}
}

func TestIgnoredHiddenOrMarked(t *testing.T) {
	root := t.TempDir()
	testcheck.Git(t, root, "init", "-q")
	testcheck.Write(t, filepath.Join(root, ".gitignore"), "node_modules/\n*.log\nbuild\n")
	testcheck.Write(t, filepath.Join(root, "node_modules", "x", "a.js"), "")
	testcheck.Write(t, filepath.Join(root, "build", "out.bin"), "")
	testcheck.Write(t, filepath.Join(root, "a.log"), "")
	testcheck.Write(t, filepath.Join(root, "kept.log"), "")
	testcheck.Write(t, filepath.Join(root, "src", "b.log"), "")
	testcheck.Write(t, filepath.Join(root, "src", "c.go"), "")
	testcheck.Git(t, root, "add", "-f", "kept.log") // tracked: git doesn't ignore it
	if got, want := names(listOf(t, root, ".", Options{})[0]), []string{"src/", ".gitignore", "kept.log"}; !slices.Equal(got, want) {
		t.Errorf("hidden: %q, want %q", got, want)
	}
	if got, want := names(listOf(t, root, ".", Options{Ignored: true})[0]), []string{"build/!", "node_modules/!", "src/", ".gitignore", "a.log!", "kept.log"}; !slices.Equal(got, want) {
		t.Errorf("shown: %q, want %q", got, want)
	}
	if got, want := names(listOf(t, root, "src", Options{})[0]), []string{"c.go"}; !slices.Equal(got, want) {
		t.Errorf("src: %q, want %q", got, want)
	}
	// Inside an ignored folder, everything is.
	if got, want := names(listOf(t, root, "node_modules", Options{Ignored: true})[0]), []string{"x/!"}; !slices.Equal(got, want) {
		t.Errorf("node_modules: %q, want %q", got, want)
	}
}

func TestOutsideGitNothingIsIgnored(t *testing.T) {
	root := t.TempDir()
	testcheck.Write(t, filepath.Join(root, ".gitignore"), "*.log\n")
	testcheck.Write(t, filepath.Join(root, "a.log"), "")
	if got, want := names(listOf(t, root, ".", Options{})[0]), []string{".gitignore", "a.log"}; !slices.Equal(got, want) {
		t.Errorf("names = %q, want %q", got, want)
	}
}

func TestLinksAreFollowedOnlyInside(t *testing.T) {
	dir := t.TempDir()
	root, outside := filepath.Join(dir, "chat"), filepath.Join(dir, "secret")
	testcheck.Write(t, filepath.Join(outside, "key.txt"), "s")
	testcheck.Write(t, filepath.Join(root, "docs", "a.md"), "a")
	link := func(target, name string) { testcheck.NoErr(t, os.Symlink(target, filepath.Join(root, name))) }
	link(outside, "out")
	link(filepath.Join(outside, "key.txt"), "key")
	link("docs", "docs2")
	link("docs/a.md", "a.md")
	link("loop", "loop")
	link("nowhere", "dangling")
	link(".git", "g")
	link(".git/refs", "refs")
	testcheck.Git(t, root, "init", "-q")
	want := []string{"docs/", "docs2/", "refs/", "a.md", "dangling@", "key@", "loop@", "out@"}
	refused := []string{"out", "loop", "g", "refs", "key"}
	if _, err := os.Stat(filepath.Join(root, ".GIT")); err == nil {
		// A case-insensitive disk (APFS): .GIT is .git, and a path's text
		// can't tell them apart.
		link(".GIT/objects", "objects")
		want = slices.Insert(want, 2, "objects/")
		refused = append(refused, "objects")
	}
	ls := listOf(t, root, ".", Options{})
	// g is .git by another name: left out, and refused below; refs (and
	// objects, through .GIT), folders in it, are shown but refused too.
	if got := names(ls[0]); !slices.Equal(got, want) {
		t.Errorf("names = %q, want %q", got, want)
	}
	for _, e := range ls[0].Entries {
		if e.Name == "docs2" && !e.Linked || e.Name == "a.md" && (!e.Linked || e.Size != 1) {
			t.Errorf("%s: %+v", e.Name, e)
		}
	}
	if got := names(listOf(t, root, "docs2", Options{})[0]); !slices.Equal(got, []string{"a.md"}) {
		t.Errorf("a link inside: %q", got)
	}
	for _, p := range refused {
		if ls, err := List(context.Background(), root, p, Options{}); err == nil {
			t.Errorf("List(%q) = %+v; want refused", p, ls)
		}
	}
	if ls := listOf(t, root, "dangling", Options{}); !ls[0].Missing {
		t.Errorf("a dangling link: %+v", ls)
	}
}

func TestCapsCountTheRest(t *testing.T) {
	root := t.TempDir()
	for i := range 30 {
		testcheck.Write(t, filepath.Join(root, fmt.Sprintf("f%02d", i)), "")
	}
	l := listOf(t, root, ".", Options{Limit: 10})[0]
	if len(l.Entries) != 10 || l.More != 20 || l.Entries[0].Name != "f00" {
		t.Errorf("capped: %d sent, %d more", len(l.Entries), l.More)
	}
	if l := listOf(t, root, ".", Options{Limit: 1 << 20})[0]; len(l.Entries) != 30 {
		t.Errorf("a limit past MaxLimit: %d sent", len(l.Entries))
	}
	if o := (Options{Limit: 1 << 20, Depth: 99}).bounded(); o.Limit != MaxLimit || o.Depth != MaxDepth {
		t.Errorf("bounded: %+v", o)
	}
}

func TestDepthListsTheFoldersSent(t *testing.T) {
	root := t.TempDir()
	testcheck.Write(t, filepath.Join(root, "a", "b", "c", "d.txt"), "")
	testcheck.Write(t, filepath.Join(root, "e", "f.txt"), "")
	testcheck.NoErr(t, os.Symlink("a", filepath.Join(root, "up")))
	var paths []string
	for _, l := range listOf(t, root, ".", Options{Depth: 2}) {
		paths = append(paths, l.Path)
	}
	if want := []string{"", "a", "e"}; !slices.Equal(paths, want) {
		t.Errorf("depth 2: %q, want %q", paths, want)
	}
	if ls := listOf(t, root, "a", Options{Depth: 9}); len(ls) != 3 || ls[2].Path != "a/b/c" {
		t.Errorf("depth past the most: %+v", ls)
	}
}

func TestWatchSendsAChange(t *testing.T) {
	root := t.TempDir()
	testcheck.Write(t, filepath.Join(root, "a.md"), "a")
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	got := make(chan []string, 8)
	done := make(chan error, 1)
	go func() {
		done <- Watch(ctx, root, ".", Options{}, 10*time.Millisecond, func(ls []Listing) error {
			got <- names(ls[0])
			return nil
		})
	}()
	next := func() []string {
		select {
		case n := <-got:
			return n
		case <-time.After(5 * time.Second):
			t.Fatal("no listing")
			return nil
		}
	}
	if n := next(); !slices.Equal(n, []string{"a.md"}) {
		t.Fatalf("first: %q", n)
	}
	testcheck.Write(t, filepath.Join(root, "b.md"), "b")
	if n := next(); !slices.Equal(n, []string{"a.md", "b.md"}) {
		t.Errorf("after an add: %q", n)
	}
	// A sent file's size changes, its folder's time not.
	testcheck.NoErr(t, os.WriteFile(filepath.Join(root, "a.md"), []byte("longer"), 0o600))
	if n := next(); !slices.Equal(n, []string{"a.md", "b.md"}) {
		t.Errorf("after an edit: %q", n)
	}
	select {
	case n := <-got:
		t.Errorf("sent again with no change: %q", n)
	case <-time.After(100 * time.Millisecond):
	}
	cancel()
	testcheck.NoErr(t, <-done)
}

// A dot-folder keeps its dot: the app looks its listing up by the path it
// asked for, and Watch stats that path to tell a change.
func TestDotFolderKeepsItsPath(t *testing.T) {
	root := t.TempDir()
	testcheck.Write(t, filepath.Join(root, ".github", "workflows", "ci.yml"), "")
	testcheck.Write(t, filepath.Join(root, "github", "other.md"), "")
	ls := listOf(t, root, ".github", Options{Depth: 2})
	if len(ls) != 2 || ls[0].Path != ".github" || ls[1].Path != ".github/workflows" {
		t.Fatalf("paths: %+v", ls)
	}
	if got := names(ls[1]); !slices.Equal(got, []string{"ci.yml"}) {
		t.Errorf("workflows: %q", got)
	}
	if ls := listOf(t, root, ".", Options{}); ls[0].Path != "" {
		t.Errorf("the folder itself: %q", ls[0].Path)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	sends := make(chan struct{}, 64)
	done := make(chan error, 1)
	go func() {
		done <- Watch(ctx, root, ".github", Options{}, 5*time.Millisecond, func([]Listing) error {
			sends <- struct{}{}
			return nil
		})
	}()
	<-sends
	select {
	case <-sends:
		t.Error("sent again with no change")
	case <-time.After(100 * time.Millisecond):
	}
	cancel()
	testcheck.NoErr(t, <-done)
}

// A name git would read as pathspec magic (":!x") doesn't stop git saying
// what the rest of its folder ignores.
func TestPathspecMagicNamesDontHideIgnores(t *testing.T) {
	root := t.TempDir()
	testcheck.Git(t, root, "init", "-q")
	testcheck.Write(t, filepath.Join(root, ".gitignore"), "*.log\n:(exclude)*\n")
	testcheck.Write(t, filepath.Join(root, "a.log"), "")
	testcheck.Write(t, filepath.Join(root, ":!notes"), "")
	testcheck.Write(t, filepath.Join(root, ":(exclude)x", "b.md"), "")
	want := []string{":(exclude)x/!", ".gitignore", ":!notes", "a.log!"}
	if got := names(listOf(t, root, ".", Options{Ignored: true})[0]); !slices.Equal(got, want) {
		t.Errorf("names = %q, want %q", got, want)
	}
}

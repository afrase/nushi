package git

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/model"
)

func git(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"}, args...)...)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
}

func write(t *testing.T, path, text string) {
	t.Helper()
	noErr(t, os.MkdirAll(filepath.Dir(path), 0o755))
	if err := os.WriteFile(path, []byte(text), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestChanges(t *testing.T) {
	ctx := context.Background()
	repo := t.TempDir()
	if _, err := Changes(ctx, repo, Span{}); err == nil {
		t.Error("a folder outside git had changes")
	}
	git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "sub", "kept.txt"), "one\n")
	if got, err := Changes(ctx, repo, Span{}); err != nil || len(got) != 1 || got[0].Status != "added" {
		t.Errorf("before the first commit: %+v, %v", got, err) // no HEAD yet
	}
	write(t, filepath.Join(repo, "sub", "gone.txt"), "bye\n")
	write(t, filepath.Join(repo, "sub", "bin"), "a\x00b")
	write(t, filepath.Join(repo, "top.txt"), "top\n")
	git(t, repo, "add", ".")
	git(t, repo, "commit", "-q", "-m", "init")

	write(t, filepath.Join(repo, "sub", "kept.txt"), "one\ntwo\n")
	noErr(t, os.Remove(filepath.Join(repo, "sub", "gone.txt")))
	write(t, filepath.Join(repo, "sub", "new.txt"), "new\n")
	write(t, filepath.Join(repo, "sub", "bin"), "c\x00d")
	noErr(t, os.Symlink("/etc/hosts", filepath.Join(repo, "sub", "link")))
	write(t, filepath.Join(repo, "top.txt"), "changed\n") // outside the folder asked for

	got, err := Changes(ctx, filepath.Join(repo, "sub"), Span{})
	if err != nil {
		t.Fatal(err)
	}
	want := []model.FileChange{
		{Path: "bin", Status: "modified", Skipped: "binary"},
		{Path: "gone.txt", Status: "deleted", Old: "bye\n", Removed: 1},
		{Path: "kept.txt", Status: "modified", Old: "one\n", New: "one\ntwo\n", Added: 1},
		{Path: "link", Status: "untracked", New: "/etc/hosts", Added: 1},
		{Path: "new.txt", Status: "untracked", New: "new\n", Added: 1},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("changes =\n%+v\nwant\n%+v", got, want)
	}
	st, err := Status(ctx, filepath.Join(repo, "sub"), "")
	if want := (model.FolderStatus{Branch: "main", Files: 5, Added: 3, Removed: 1}); err != nil || st != want {
		t.Errorf("status = %+v, %v; want %+v", st, err, want)
	}

	// A rename, counted under its new path.
	git(t, repo, "add", ".")
	git(t, repo, "commit", "-q", "-m", "more")
	git(t, repo, "mv", "sub/kept.txt", "sub/moved.txt")
	write(t, filepath.Join(repo, "sub", "moved.txt"), "one\ntwo\nthree\n")
	got, err = Changes(ctx, filepath.Join(repo, "sub"), Span{})
	want = []model.FileChange{{Path: "moved.txt", OldPath: "kept.txt", Status: "renamed", Old: "one\ntwo\n", New: "one\ntwo\nthree\n", Added: 1}}
	if err != nil || !reflect.DeepEqual(got, want) {
		t.Errorf("renamed: %+v, %v", got, err)
	}
}

func TestBranchChanges(t *testing.T) {
	ctx := context.Background()
	repo := t.TempDir()
	git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "a.txt"), "a\n")
	write(t, filepath.Join(repo, "b.txt"), "b\n")
	git(t, repo, "add", ".")
	git(t, repo, "commit", "-q", "-m", "init")
	git(t, repo, "switch", "-q", "-c", "feature")
	write(t, filepath.Join(repo, "a.txt"), "a\nmore\n")
	git(t, repo, "commit", "-q", "-am", "feature")
	// main moves on: its new commit isn't the branch's change.
	git(t, repo, "switch", "-q", "main")
	write(t, filepath.Join(repo, "c.txt"), "c\n")
	git(t, repo, "add", ".")
	git(t, repo, "commit", "-q", "-m", "main")
	git(t, repo, "switch", "-q", "feature")
	write(t, filepath.Join(repo, "b.txt"), "b2\n")

	paths := func(span Span) string {
		changes, err := Changes(ctx, repo, span)
		if err != nil {
			t.Fatal(err)
		}
		var out []string
		for _, c := range changes {
			out = append(out, c.Path+":"+c.Old+">"+c.New)
		}
		return strings.Join(out, " ")
	}
	if got, want := paths(Span{Base: "main"}), "a.txt:a\n>a\nmore\n b.txt:b\n>b2\n"; got != want {
		t.Errorf("branch changes = %q, want %q", got, want)
	}
	if got, want := paths(Span{}), "b.txt:b\n>b2\n"; got != want {
		t.Errorf("uncommitted changes = %q, want %q", got, want)
	}
	if st, err := Status(ctx, repo, "main"); err != nil || st.Files != 2 || st.Added != 2 || st.Removed != 1 {
		t.Errorf("branch status = %+v, %v", st, err)
	}
	if _, err := Changes(ctx, repo, Span{Base: "--output=x"}); err == nil {
		t.Error("an option as the base")
	}

	// The branch's commits, and what each made.
	if b := DefaultBase(ctx, repo); b != "main" {
		t.Errorf("default base = %q", b)
	}
	git(t, repo, "commit", "-q", "-am", "second")
	if n, err := Ahead(ctx, repo, "main"); n != 2 || err != nil {
		t.Errorf("ahead = %d, %v", n, err)
	}
	commits, err := Commits(ctx, repo, "main", 50)
	if err != nil || len(commits) != 2 || commits[0].Subject != "second" || commits[1].Added != 1 {
		t.Fatalf("commits = %+v, %v", commits, err)
	}
	if got, want := paths(Span{Commit: commits[0].Hash}), "b.txt:b\n>b2\n"; got != want {
		t.Errorf("a commit's changes = %q, want %q", got, want)
	}
	if got, want := paths(Span{Commit: commits[0].Hash, Since: commits[1].Hash}), "a.txt:a\n>a\nmore\n b.txt:b\n>b2\n"; got != want {
		t.Errorf("two commits' changes = %q, want %q", got, want)
	}
	if all, err := Commits(ctx, repo, "", 50); err != nil || len(all) != 3 {
		t.Errorf("the last commits = %+v, %v", all, err)
	}
	first, _ := Commits(ctx, repo, "", 50)
	if got, want := paths(Span{Commit: first[2].Hash}), "a.txt:>a\n b.txt:>b\n"; got != want {
		t.Errorf("the first commit's changes = %q, want %q", got, want)
	}
	// A subject can't add a commit of its own.
	fake := "x\x1e" + strings.Repeat("d", 40) + "\x1fddddddd\x1f0\x1fLooks legit"
	git(t, repo, "commit", "-q", "--allow-empty", "-m", fake)
	if all, _ := Commits(ctx, repo, "", 50); len(all) != 4 || all[0].Subject != fake || all[1].Subject != "second" || all[1].Added != 1 {
		t.Errorf("after a commit whose subject has the separators: %+v", all)
	}
}

// A downloaded folder's .git/config can name hooks and filters: Nushi's own
// status runs neither, and its worktrees run no hooks. Nothing Nushi runs
// starts the fsmonitor, a signature check, a lazy fetch, or a nested
// repository's filters.
func TestARepositorysOwnConfigRunsNothing(t *testing.T) {
	ctx := context.Background()
	repo, marks := t.TempDir(), t.TempDir()
	mark := func(name string) string { return "touch " + filepath.Join(marks, name) }
	git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "a.txt"), "one\n")
	write(t, filepath.Join(repo, "b.md"), "one\n")
	write(t, filepath.Join(repo, "c.go"), "one\n")
	write(t, filepath.Join(repo, "lazy.txt"), "lazy\n")
	// A repository inside it, as an unpacked download brings one: a gitlink
	// in the index, and its own config with a filter.
	sub := filepath.Join(repo, "sub")
	git(t, repo, "init", "-q", "-b", "main", "sub")
	write(t, filepath.Join(sub, "s.txt"), "one\n")
	git(t, sub, "add", ".")
	git(t, sub, "commit", "-q", "-m", "sub")
	head, _ := exec.Command("git", "-C", sub, "rev-parse", "HEAD").Output()
	git(t, repo, "add", "a.txt", "b.md", "c.go", "lazy.txt")
	git(t, repo, "update-index", "--add", "--cacheinfo", "160000,"+strings.TrimSpace(string(head))+",sub")
	git(t, repo, "commit", "-q", "-m", "first")
	git(t, sub, "config", "filter.evil.clean", mark("subfilter")+"; cat")
	write(t, filepath.Join(sub, ".git", "info", "attributes"), "*.txt filter=evil\n")
	noErr(t, os.Chtimes(filepath.Join(sub, "s.txt"), time.Now(), time.Now().Add(time.Hour))) // its index is stale

	git(t, repo, "config", "filter.evil.clean", mark("filter")+"; cat")
	// A driver whose name has a dot in it.
	write(t, filepath.Join(repo, ".git", "info", "attributes"), "*.txt filter=evil\n*.md filter=a.b\n")
	git(t, repo, "config", "filter.a.b.clean", mark("dotted")+"; cat")
	// And one with "=" in it, which -c would split at.
	write(t, filepath.Join(repo, ".git", "info", "attributes"), "a.txt filter=evil\n*.md filter=a.b\n*.go filter=x=y\n")
	git(t, repo, "config", "filter.x=y.clean", mark("equals")+"; cat")
	write(t, filepath.Join(repo, "c.go"), "one\ntwo\n")
	write(t, filepath.Join(repo, "b.md"), "one\ntwo\n")
	write(t, filepath.Join(repo, ".git", "hooks", "post-checkout"), "#!/bin/sh\n"+mark("hook")+"\n")
	noErr(t, os.Chmod(filepath.Join(repo, ".git", "hooks", "post-checkout"), 0o755))
	write(t, filepath.Join(repo, "a.txt"), "one\ntwo\n")

	// A signed commit, and a gpg that marks any check of it.
	gpg := filepath.Join(marks, "gpg.sh")
	write(t, gpg, "#!/bin/sh\ncase \"$*\" in *--verify*) "+mark("gpg")+"; exit 0;; esac\n"+
		"echo '[GNUPG:] SIG_CREATED ' >&2\nprintf -- '-----BEGIN PGP SIGNATURE-----\\n\\nx\\n-----END PGP SIGNATURE-----\\n'\n")
	noErr(t, os.Chmod(gpg, 0o755))
	git(t, repo, "-c", "gpg.program="+gpg, "commit", "-q", "-S", "--allow-empty", "-m", "signed")
	git(t, repo, "config", "gpg.program", gpg)
	git(t, repo, "config", "log.showSignature", "true")
	git(t, repo, "config", "core.fsmonitor", mark("fsmonitor")+"; true")
	if _, _, err := (Worktrees{}).Add(ctx, repo, "wt", "", ""); err != nil {
		t.Fatal(err)
	}
	// A partial clone missing a blob: fetching it would run the transport
	// the config names.
	blob, _ := exec.Command("git", "-C", repo, "rev-parse", "HEAD:lazy.txt").Output()
	b := strings.TrimSpace(string(blob))
	noErr(t, os.Remove(filepath.Join(repo, ".git", "objects", b[:2], b[2:])))
	for _, kv := range [][2]string{{"core.repositoryformatversion", "1"}, {"extensions.partialClone", "origin"},
		{"remote.origin.url", "ssh://example.invalid/x"}, {"remote.origin.promisor", "true"}, {"core.sshCommand", mark("lazy") + "; false"}} {
		git(t, repo, "config", kv[0], kv[1])
	}
	write(t, filepath.Join(repo, "lazy.txt"), "lazy\ntwo\n")

	_, _ = Status(ctx, repo, "")                                          // it may fail on the missing blob; it runs nothing
	if ran, _ := filepath.Glob(filepath.Join(marks, "*")); len(ran) > 1 { // gpg.sh
		t.Errorf("ran %v", ran)
	}
	// Changes runs the repository's own filters, as the user's git diff
	// would (ADR 0023), and nothing else.
	_, _ = Changes(ctx, repo, Span{}) // only what they run is tested
	_, _ = Commits(ctx, repo, "", 10)
	for _, name := range []string{"fsmonitor", "gpg", "lazy", "subfilter", "hook"} {
		if _, err := os.Stat(filepath.Join(marks, name)); err == nil {
			t.Errorf("ran the repository's %s", name)
		}
	}
}

// What Changes can't read is left out, never the whole diff: a repository
// inside the folder, a submodule that moved, a huge file.
func TestChangesLeavesOutWhatItCantShow(t *testing.T) {
	ctx := context.Background()
	repo := t.TempDir()
	git(t, repo, "init", "-q", "-b", "main")
	sub := filepath.Join(repo, "sm")
	git(t, repo, "init", "-q", "-b", "main", "sm")
	git(t, sub, "commit", "-q", "--allow-empty", "-m", "one")
	head, _ := exec.Command("git", "-C", sub, "rev-parse", "HEAD").Output()
	git(t, repo, "update-index", "--add", "--cacheinfo", "160000,"+strings.TrimSpace(string(head))+",sm")
	write(t, filepath.Join(repo, "a.txt"), "a\n")
	git(t, repo, "add", "a.txt")
	git(t, repo, "commit", "-q", "-m", "first")
	git(t, sub, "commit", "-q", "--allow-empty", "-m", "two") // the pointer moves
	clone := filepath.Join(repo, "clone")
	git(t, repo, "init", "-q", "clone") // a repository the agent made, untracked
	write(t, filepath.Join(clone, "x"), "x\n")
	write(t, filepath.Join(repo, "big.txt"), strings.Repeat("x", maxText+1))
	write(t, filepath.Join(repo, "a.txt"), "a\nb\n")

	got, err := Changes(ctx, repo, Span{})
	if err != nil {
		t.Fatal(err)
	}
	skipped := map[string]string{}
	for _, c := range got {
		skipped[c.Path] = c.Skipped
	}
	want := map[string]string{"a.txt": "", "big.txt": "too large", "clone": "a repository of its own", "sm": "a submodule"}
	if !reflect.DeepEqual(skipped, want) {
		t.Errorf("skipped = %v, want %v", skipped, want)
	}
	if st, err := Status(ctx, repo, ""); err != nil || st.Files != 4 || st.Added != 2 || st.Removed != 1 { // the submodule's pointer counts as a line
		t.Errorf("status = %+v, %v", st, err)
	}
}

// One cat-file reads a commit's files in turn: past one too large to keep
// whole, one that isn't there, and one with a newline in its name (through
// git show).
func TestBlobs(t *testing.T) {
	ctx := context.Background()
	repo := t.TempDir()
	git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "big.txt"), strings.Repeat("x", maxText+5))
	write(t, filepath.Join(repo, "sub", "a.txt"), "a\n")
	write(t, filepath.Join(repo, "sub")+"/two\nlines", "b")
	git(t, repo, "add", ".")
	git(t, repo, "commit", "-q", "-m", "one")

	files := openBlobs(repo)
	defer files.close()
	if b, err := files.read(ctx, "HEAD", "big.txt"); err != nil || len(b) != maxText+1 {
		t.Errorf("big.txt: %d bytes, %v", len(b), err)
	}
	if _, err := files.read(ctx, "HEAD", "nope.txt"); err == nil {
		t.Error("a file that isn't there was read")
	}
	for path, want := range map[string]string{"sub/a.txt": "a\n", "sub/two\nlines": "b"} {
		if b, err := files.read(ctx, "HEAD", path); err != nil || string(b) != want {
			t.Errorf("%q: %q, %v", path, b, err)
		}
	}
}

func TestFileReadsOnlyInsideTheFolder(t *testing.T) {
	dir, outside := t.TempDir(), t.TempDir()
	write(t, filepath.Join(dir, "sub", "a.go"), "package a\n")
	write(t, filepath.Join(dir, "bin"), "a\x00b")
	write(t, filepath.Join(outside, "secret"), "no\n")
	noErr(t, os.Symlink(filepath.Join(outside, "secret"), filepath.Join(dir, "link")))
	noErr(t, os.Symlink(outside, filepath.Join(dir, "out")))
	noErr(t, os.Symlink("sub/a.go", filepath.Join(dir, "near")))
	if c, err := File(dir, "sub/../sub/a.go"); err != nil || c.Path != "sub/a.go" || c.Status != "unchanged" || c.Old != "package a\n" || c.New != c.Old {
		t.Errorf("File = %+v, %v", c, err)
	}
	if c, err := File(dir, "bin"); err != nil || c.Skipped != "binary" || c.New != "" {
		t.Errorf("a binary file: %+v, %v", c, err)
	}
	for _, p := range []string{"../" + filepath.Base(outside) + "/secret", filepath.Join(outside, "secret"), "", "link", "out/secret", "near", "sub", "missing"} {
		if c, err := File(dir, p); err == nil {
			t.Errorf("File(%q) read %+v", p, c)
		}
	}
}

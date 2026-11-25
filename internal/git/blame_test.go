package git

import (
	"context"
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

// TestBlameOfAFile: runs of lines by commit, as the file is on disk now
// (its lines not committed yet in runs of their own, with no author),
// plain names and subjects, never an address.
func TestBlameOfAFile(t *testing.T) {
	ctx := t.Context()
	repo := t.TempDir()
	sub := filepath.Join(repo, "sub")
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Write(t, filepath.Join(sub, "a.txt"), "one\ntwo\nthree\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "First words\n\nA body never sent.", "--author", "Ada Example <ada@example.com>",
		"--date", "1700000000 +0000")
	first := testcheck.Git(t, repo, "rev-parse", "HEAD")
	testcheck.Write(t, filepath.Join(sub, "a.txt"), "one\ntwo\nthree\nfour\nfive\n")
	testcheck.Git(t, repo, "commit", "-q", "-am", "More \u202ewords\x1b", "--author", "Bo \u200bQuill <bo@example.com>",
		"--date", "1700000100 +0000")
	second := testcheck.Git(t, repo, "rev-parse", "HEAD")
	testcheck.Write(t, filepath.Join(sub, "a.txt"), "one\nTWO\nthree\nfour\nfive\nsix")

	got, err := Blame(ctx, sub, "a.txt")
	testcheck.NoErr(t, err)
	want := FileBlame{Runs: []BlameRun{
		{Start: 1, Count: 1, Commit: first, Author: "Ada Example", Time: 1700000000, Subject: "First words"},
		{Start: 2, Count: 1},
		{Start: 3, Count: 1, Commit: first, Author: "Ada Example", Time: 1700000000, Subject: "First words"},
		{Start: 4, Count: 2, Commit: second, Author: "Bo Quill", Time: 1700000100, Subject: "More words"},
		{Start: 6, Count: 1},
	}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("blame =\n%+v\nwant\n%+v", got, want)
	}
	if top, err := Blame(ctx, repo, "sub/a.txt"); err != nil || !reflect.DeepEqual(top, want) {
		t.Errorf("from the top: %+v, %v", top, err)
	}

	testcheck.Write(t, filepath.Join(sub, "empty.txt"), "")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "empty")
	if e, err := Blame(ctx, sub, "empty.txt"); err != nil || len(e.Runs) != 0 || e.None != "" {
		t.Errorf("an empty file: %+v, %v", e, err)
	}
}

// TestBlameSaysWhyNot: a file git can't blame as it is now has no runs,
// and a reason the app words; a path out of the folder, or anything but
// a file, is refused.
func TestBlameSaysWhyNot(t *testing.T) {
	ctx := t.Context()
	outside := t.TempDir()
	testcheck.Write(t, filepath.Join(outside, "a.txt"), "a\n")
	if got, err := Blame(ctx, outside, "a.txt"); err != nil || got.None != NoBlameRepository {
		t.Errorf("outside a repository: %+v, %v", got, err)
	}

	repo := t.TempDir()
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Write(t, filepath.Join(repo, "a.txt"), "a\n")
	testcheck.Git(t, repo, "add", "a.txt")
	if got, err := Blame(ctx, repo, "a.txt"); err != nil || got.None != NoBlameNew {
		t.Errorf("before the first commit: %+v, %v", got, err)
	}
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")

	testcheck.Write(t, filepath.Join(repo, ".gitignore"), "*.log\n")
	testcheck.Write(t, filepath.Join(repo, "x.log"), "x\n")
	testcheck.Write(t, filepath.Join(repo, "u.txt"), "u\n")
	testcheck.Write(t, filepath.Join(repo, "n.txt"), "n\n")
	testcheck.Write(t, filepath.Join(repo, "bin"), "a\x00b")
	testcheck.Write(t, filepath.Join(repo, "big.txt"), strings.Repeat("x", maxText+1))
	testcheck.Write(t, filepath.Join(repo, "long.txt"), strings.Repeat("x\n", maxBlameLines+1))
	testcheck.Write(t, filepath.Join(repo, "edge.txt"), strings.Repeat("x\n", maxBlameLines))
	testcheck.NoErr(t, os.Symlink("a.txt", filepath.Join(repo, "link")))
	testcheck.NoErr(t, os.Mkdir(filepath.Join(repo, "dir"), 0o700))
	testcheck.Git(t, repo, "add", "bin", "big.txt", "long.txt", "edge.txt", "link")
	testcheck.Git(t, repo, "commit", "-q", "-m", "more")
	testcheck.Git(t, repo, "add", "n.txt")

	for path, want := range map[string]string{
		"x.log": NoBlameIgnored, "u.txt": NoBlameUntracked, "n.txt": NoBlameNew, "bin": NoBlameBinary,
		"big.txt": NoBlameTooLarge, "long.txt": NoBlameTooManyLines, "link": NoBlameLink,
	} {
		if got, err := Blame(ctx, repo, path); err != nil || got.None != want || len(got.Runs) != 0 {
			t.Errorf("%s: %+v, %v; want %q", path, got, err, want)
		}
	}
	if got, err := Blame(ctx, repo, "edge.txt"); err != nil || len(got.Runs) != 1 || got.Runs[0].Count != maxBlameLines {
		t.Errorf("at the line limit: %d runs, %v", len(got.Runs), err)
	}
	for _, path := range []string{"../a.txt", "/etc/hosts", "dir", "missing.txt"} {
		if got, err := Blame(ctx, repo, path); err == nil {
			t.Errorf("%s answered: %+v", path, got)
		}
	}
	// Where check-ignore can't look (a file in a submodule, past a link to
	// a tracked folder, a name git reads as pathspec magic), ls-files has
	// already listed nothing: not tracked, as the change marks say.
	sm := filepath.Join(repo, "sm")
	testcheck.Git(t, repo, "init", "-q", "-b", "main", "sm")
	testcheck.Write(t, filepath.Join(sm, "a.txt"), "a\n")
	testcheck.Git(t, sm, "add", ".")
	testcheck.Git(t, sm, "commit", "-q", "-m", "init")
	testcheck.Write(t, filepath.Join(repo, "real", "f.txt"), "f\n")
	testcheck.NoErr(t, os.Symlink("real", filepath.Join(repo, "ld")))
	testcheck.Write(t, filepath.Join(repo, ":(icase)A.txt"), "m\n")
	testcheck.Git(t, repo, "add", "sm", "real", "ld")
	testcheck.Git(t, repo, "commit", "-q", "-m", "nested")
	for _, path := range []string{"sm/a.txt", "ld/f.txt", ":(icase)A.txt"} {
		if got, err := Blame(ctx, repo, path); err != nil || got.None != NoBlameUntracked {
			t.Errorf("%s: %+v, %v; want %q", path, got, err, NoBlameUntracked)
		}
	}
	out := t.TempDir()
	testcheck.Write(t, filepath.Join(out, "secret.txt"), "s\n")
	testcheck.NoErr(t, os.Symlink(out, filepath.Join(repo, "away")))
	if got, err := Blame(ctx, repo, "away/secret.txt"); err == nil {
		t.Errorf("through a link out: %+v", got)
	}
}

// TestBlameRunsNoFilter: blame runs when the user turns it on, but on a
// repository anyone may have made, so its own clean, process and textconv
// drivers never run, nor its list of commits to skip.
func TestBlameRunsNoFilter(t *testing.T) {
	ctx := t.Context()
	repo := t.TempDir()
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Write(t, filepath.Join(repo, "a.txt"), "one\n")
	testcheck.Write(t, filepath.Join(repo, "b.md"), "one\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")
	testcheck.Write(t, filepath.Join(repo, "a.txt"), "ONE\n")
	testcheck.Write(t, filepath.Join(repo, "b.md"), "ONE\n")
	testcheck.Git(t, repo, "commit", "-q", "-am", "loud")
	loud := testcheck.Git(t, repo, "rev-parse", "HEAD") // a skipped commit's lines would be init's
	marks := t.TempDir()
	clean, process, textconv := filepath.Join(marks, "clean-ran"), filepath.Join(marks, "process-ran"), filepath.Join(marks, "textconv-ran")
	testcheck.Write(t, filepath.Join(repo, ".git", "info", "attributes"), "*.txt filter=evil diff=evil\n*.md filter=talker\n")
	testcheck.Git(t, repo, "config", "filter.evil.clean", "touch "+clean+"; cat")
	testcheck.Git(t, repo, "config", "filter.talker.process", "touch "+process+"; cat")
	testcheck.Git(t, repo, "config", "diff.evil.textconv", "touch "+textconv+"; cat")
	testcheck.Write(t, filepath.Join(repo, "skip"), loud+"\n")
	testcheck.Git(t, repo, "config", "blame.ignoreRevsFile", "skip")
	testcheck.Write(t, filepath.Join(repo, "a.txt"), "ONE\ntwo\n")
	testcheck.Write(t, filepath.Join(repo, "b.md"), "ONE\ntwo\n")

	for _, path := range []string{"a.txt", "b.md"} {
		got, err := Blame(ctx, repo, path)
		if err != nil || len(got.Runs) != 2 || got.Runs[0].Commit != loud {
			t.Errorf("%s: %+v, %v", path, got, err)
		}
	}
	for _, f := range []string{clean, process, textconv} {
		if _, err := os.Stat(f); err == nil {
			t.Errorf("a driver ran: %s", filepath.Base(f))
		}
	}

	// The list is cleared before git reads it: a file the config names
	// is never opened, so a pipe there can't hold the call nor a missing
	// one fail it.
	testcheck.Fifo(t, filepath.Join(repo, "pipe"))
	for _, list := range []string{"pipe", filepath.Join(marks, "missing")} {
		testcheck.Git(t, repo, "config", "blame.ignoreRevsFile", list)
		short, cancel := context.WithTimeout(ctx, 5*time.Second)
		got, err := Blame(short, repo, "a.txt")
		cancel()
		if err != nil || len(got.Runs) != 2 || got.Runs[0].Commit != loud {
			t.Errorf("blame.ignoreRevsFile %s: %+v, %v", filepath.Base(list), got, err)
		}
	}
}

// TestReadBlame: git's incremental output read into runs, and what isn't
// that refused rather than shown wrong.
func TestReadBlame(t *testing.T) {
	a, b := strings.Repeat("a", 40), strings.Repeat("b", 40)
	entry := func(sha string, final, n int, headers ...string) string {
		return sha + " 1 " + strconv.Itoa(final) + " " + strconv.Itoa(n) + "\n" + strings.Join(append(headers, "filename f"), "\n") + "\n"
	}
	ok := entry(b, 3, 1, "author B", "author-mail <b@example.com>", "author-time 20", "summary two") +
		entry(a, 1, 2, "author A", "author-time 10", "summary one", "boundary") + entry(b, 4, 1)
	got, err := readBlame([]byte(ok), 4)
	testcheck.NoErr(t, err)
	want := []BlameRun{
		{Start: 1, Count: 2, Commit: a, Author: "A", Time: 10, Subject: "one"},
		{Start: 3, Count: 2, Commit: b, Author: "B", Time: 20, Subject: "two"},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("runs =\n%+v\nwant\n%+v", got, want)
	}
	long := strings.Repeat("é", 1000)
	if got, err := readBlame([]byte(entry(a, 1, 1, "author "+long, "summary "+long)), 1); err != nil ||
		len(got[0].Author) > maxAuthor || len(got[0].Subject) > maxSubject || !strings.HasPrefix(long, got[0].Subject) {
		t.Errorf("capped: %d, %d, %v", len(got[0].Author), len(got[0].Subject), err)
	}
	for name, bad := range map[string]string{
		"a gap":        entry(a, 1, 1) + entry(a, 3, 1),
		"an overlap":   entry(a, 1, 2) + entry(b, 2, 2),
		"past the end": entry(a, 1, 5),
		"too short":    entry(a, 1, 2),
		"not an id":    entry("nope", 1, 4),
		"no count":     a + " 1 1\nfilename f\n",
		"cut off":      a + " 1 1 4\nauthor A\n",
	} {
		if got, err := readBlame([]byte(bad), 4); err == nil {
			t.Errorf("%s answered: %+v", name, got)
		}
	}
}

package git

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// A chat's worktree made from a main that hadn't been pulled, then
// rebased onto origin/main, which a teammate had moved on by five files.
func rebasedOntoUpstream(t *testing.T) (repo, wt string) {
	t.Helper()
	dir := t.TempDir()
	origin, repo, mate := filepath.Join(dir, "origin.git"), filepath.Join(dir, "repo"), filepath.Join(dir, "mate")
	testcheck.Git(t, dir, "init", "-q", "--bare", "-b", "main", origin)
	testcheck.Git(t, dir, "clone", "-q", origin, repo)
	write(t, filepath.Join(repo, "a.txt"), "a\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "a")
	testcheck.Git(t, repo, "push", "-q", "-u", "origin", "main")
	testcheck.Git(t, dir, "clone", "-q", origin, mate)
	for _, f := range []string{"u1", "u2", "u3", "u4", "u5"} {
		write(t, filepath.Join(mate, f), f+"\n")
	}
	testcheck.Git(t, mate, "add", ".")
	testcheck.Git(t, mate, "commit", "-q", "-m", "the teammate's")
	testcheck.Git(t, mate, "push", "-q")
	wt = filepath.Join(dir, "wt")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "chat", wt, "main")
	write(t, filepath.Join(wt, "mine.txt"), "mine\n")
	testcheck.Git(t, wt, "add", ".")
	testcheck.Git(t, wt, "commit", "-q", "-m", "mine")
	testcheck.Git(t, wt, "fetch", "-q")
	testcheck.Git(t, wt, "rebase", "-q", "origin/main")
	return repo, wt
}

// A branch is counted from where it left main or origin/main, the later:
// not every upstream commit since the local main.
func TestABranchCountsFromTheNewerCopyOfItsBase(t *testing.T) {
	ctx := context.Background()
	_, wt := rebasedOntoUpstream(t)
	for _, base := range []string{"main", "origin/main"} {
		if st, err := Status(ctx, wt, base); err != nil || st.Files != 1 || st.Added != 1 {
			t.Errorf("%s: status = %+v, %v", base, st, err)
		}
		if got, err := Changes(ctx, wt, Span{Base: base}); err != nil || len(got) != 1 || got[0].Path != "mine.txt" {
			t.Errorf("%s: changes = %+v, %v", base, got, err)
		}
		if n, err := Ahead(ctx, wt, base, ""); err != nil || n != 1 {
			t.Errorf("%s: ahead = %d, %v", base, n, err)
		}
		if c, err := Commits(ctx, wt, base, "", 50); err != nil || len(c) != 1 || c[0].Subject != "mine" {
			t.Errorf("%s: commits = %+v, %v", base, c, err)
		}
	}
}

// From origin/main, a branch made from a local main with a commit not yet
// pushed doesn't count that commit as its own.
func TestABranchOffAnUnpushedMain(t *testing.T) {
	ctx := context.Background()
	repo, _ := rebasedOntoUpstream(t)
	testcheck.Git(t, repo, "pull", "-q", "--ff-only")
	write(t, filepath.Join(repo, "local.txt"), "not pushed\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "local")
	wt := filepath.Join(repo, "..", "wt2")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "chat2", wt, "main")
	write(t, filepath.Join(wt, "mine2.txt"), "mine\n")
	if st, err := Status(ctx, wt, "origin/main"); err != nil || st.Files != 1 {
		t.Errorf("status = %+v, %v", st, err)
	}
	if n, err := Ahead(ctx, wt, "origin/main", ""); err != nil || n != 0 {
		t.Errorf("ahead = %d, %v", n, err)
	}
}

// A base with no other copy, or none any more, is counted from alone.
func TestBasesOfABranchWithoutAnUpstream(t *testing.T) {
	ctx := context.Background()
	repo, wt := rebasedOntoUpstream(t)
	head := testcheck.Git(t, wt, "rev-parse", "HEAD")
	if got := bases(ctx, wt, head); len(got) != 1 || got[0] != head {
		t.Errorf("a commit: %q", got)
	}
	if got := bases(ctx, wt, "chat"); len(got) != 1 {
		t.Errorf("no upstream: %q", got)
	}
	if got := bases(ctx, wt, "main"); len(got) != 2 || got[1] != "refs/remotes/origin/main" {
		t.Errorf("main: %q", got)
	}
	if got := bases(ctx, wt, "origin/main"); len(got) != 2 || got[1] != "refs/heads/main" {
		t.Errorf("origin/main: %q", got)
	}
	testcheck.Git(t, repo, "update-ref", "-d", "refs/remotes/origin/main")
	if got := bases(ctx, wt, "main"); len(got) != 1 {
		t.Errorf("an upstream gone: %q", got)
	}
}

// Only main pairs with origin/main: a branch that tracks origin/main, as
// one made from it does, isn't its other copy, whatever its name.
func TestBasesPairOnlyTheSameName(t *testing.T) {
	ctx := context.Background()
	repo, _ := rebasedOntoUpstream(t)
	testcheck.Git(t, repo, "branch", "-q", "--track", "a-agent", "origin/main")
	if got := bases(ctx, repo, "origin/main"); len(got) != 2 || got[1] != "refs/heads/main" {
		t.Errorf("origin/main: %q", got)
	}
	testcheck.Git(t, repo, "switch", "-q", "--detach")
	testcheck.Git(t, repo, "branch", "-q", "-D", "main")
	if got := bases(ctx, repo, "origin/main"); len(got) != 1 {
		t.Errorf("without main: %q", got)
	}
	if got := bases(ctx, repo, "a-agent"); len(got) != 2 || got[1] != "refs/remotes/origin/main" {
		t.Errorf("a local branch's upstream: %q", got)
	}
}

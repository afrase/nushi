package git

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

func TestRemotes(t *testing.T) {
	repo := t.TempDir()
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	if rs, err := Remotes(t.Context(), repo); err != nil || len(rs) != 0 {
		t.Fatalf("%+v %v", rs, err)
	}
	testcheck.Git(t, repo, "remote", "add", "origin", "git@github.com:afrase/nushi.git")
	testcheck.Git(t, repo, "remote", "add", "up", "https://github.com/someone/nushi")
	testcheck.Git(t, repo, "remote", "set-url", "--push", "up", "no_push")
	rs, err := Remotes(t.Context(), repo)
	if err != nil || len(rs) != 2 || rs[0] != (Remote{"origin", "git@github.com:afrase/nushi.git"}) || rs[1].URL != "https://github.com/someone/nushi" {
		t.Fatalf("%+v %v", rs, err)
	}
	if _, err := Remotes(t.Context(), t.TempDir()); err == nil {
		t.Fatal("a folder outside git")
	}
}

// TestFetchAPullsHead: a pull request's head is fetched from the base
// repository (a fork's too: refs/pull/<n>/head), and a worktree's branch
// starts from it, tracking a remote's branch when it is one.
func TestFetchAPullsHead(t *testing.T) {
	ctx := t.Context()
	base := t.TempDir()
	testcheck.Git(t, base, "init", "-q", "-b", "main")
	write(t, filepath.Join(base, "a.txt"), "a\n")
	testcheck.Git(t, base, "add", ".")
	testcheck.Git(t, base, "commit", "-q", "-m", "a")
	testcheck.Git(t, base, "checkout", "-q", "-b", "feature")
	write(t, filepath.Join(base, "a.txt"), "feature\n")
	testcheck.Git(t, base, "commit", "-q", "-am", "feature")
	testcheck.Git(t, base, "update-ref", "refs/pull/7/head", "HEAD") // as GitHub keeps a fork's
	testcheck.Git(t, base, "checkout", "-q", "main")
	clone := filepath.Join(t.TempDir(), "clone")
	testcheck.Git(t, filepath.Dir(clone), "clone", "-q", base, clone)

	testcheck.NoErr(t, Fetch(ctx, clone, "origin", "+refs/heads/feature:refs/remotes/origin/feature"))
	wt, in, err := Worktrees{}.Add(ctx, clone, "feature", "feature", "refs/remotes/origin/feature")
	if err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(in, "a.txt")); string(b) != "feature\n" || wt.Base != "refs/remotes/origin/feature" {
		t.Fatalf("%q %+v", b, wt)
	}
	if up := upstream(t, in); up != "origin/feature" {
		t.Fatalf("upstream %q", up)
	}
	if st, err := (Worktrees{}).Inspect(ctx, wt); err != nil || st.Commits != 0 {
		t.Fatalf("its fetched commits count as work: %+v %v", st, err)
	}

	testcheck.NoErr(t, Fetch(ctx, clone, "origin", "+refs/pull/7/head:refs/nushi/pull/7"))
	_, in, err = Worktrees{}.Add(ctx, clone, "pr-7", "pr-7-feature", "refs/nushi/pull/7")
	if err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(in, "a.txt")); string(b) != "feature\n" {
		t.Fatalf("%q", b)
	}
	if out, err := run(ctx, in, "rev-parse", "--abbrev-ref", "@{upstream}"); err == nil {
		t.Fatalf("a fork's head tracks %s: a push would go there", out)
	}
	if err := Fetch(ctx, clone, "origin", "+refs/heads/nothing:refs/remotes/origin/nothing"); err == nil {
		t.Fatal("fetched a branch that isn't there")
	}
	if err := Fetch(ctx, clone, "--upload-pack=x", "main"); err == nil {
		t.Fatal("an option for a remote")
	}
}

func upstream(t *testing.T, dir string) string {
	t.Helper()
	out, err := run(t.Context(), dir, "rev-parse", "--abbrev-ref", "@{upstream}")
	testcheck.NoErr(t, err)
	return strings.TrimSpace(string(out))
}

// TestHead: the branch checked out and the remote it's pushed to.
func TestHead(t *testing.T) {
	ctx := t.Context()
	repo := t.TempDir()
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "a.txt"), "a\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "a")
	if b, r := Head(ctx, repo); b != "main" || r != "" {
		t.Fatalf("%q %q", b, r)
	}
	testcheck.Git(t, repo, "remote", "add", "origin", "https://github.com/afrase/nushi")
	testcheck.Git(t, repo, "remote", "add", "fork", "https://github.com/me/nushi")
	testcheck.Git(t, repo, "checkout", "-q", "-b", "feat/x")
	testcheck.Git(t, repo, "config", "branch.feat/x.remote", "origin")
	if b, r := Head(ctx, repo); b != "feat/x" || r != "origin" {
		t.Fatalf("%q %q", b, r)
	}
	testcheck.Git(t, repo, "config", "branch.feat/x.pushRemote", "fork")
	if _, r := Head(ctx, repo); r != "fork" {
		t.Fatalf("the push remote: %q", r)
	}
	testcheck.Git(t, repo, "checkout", "-q", "--detach")
	if b, _ := Head(ctx, repo); b != "" {
		t.Fatalf("detached: %q", b)
	}
	if b, _ := Head(ctx, t.TempDir()); b != "" {
		t.Fatalf("outside git: %q", b)
	}
}

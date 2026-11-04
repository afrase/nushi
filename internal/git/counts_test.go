package git

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// A worktree's commits once it is gone: the chat's own commit, then one on
// a branch of its own, kept only by its hash.
func goneWorktree(t *testing.T) (repo, base, head string) {
	t.Helper()
	repo = t.TempDir()
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "on-main.txt"), "the chat's\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "the chat's own commit")
	base = testcheck.Git(t, repo, "rev-parse", "HEAD")
	wt := filepath.Join(repo, "wt")
	testcheck.Git(t, repo, "worktree", "add", "-q", "-b", "work", wt)
	write(t, filepath.Join(wt, "work.txt"), "the subagent's\none more\n")
	testcheck.Git(t, wt, "add", ".")
	testcheck.Git(t, wt, "commit", "-q", "-m", "work")
	head = testcheck.Git(t, wt, "rev-parse", "HEAD")
	testcheck.Git(t, repo, "worktree", "remove", wt)
	testcheck.Git(t, repo, "branch", "-q", "-D", "work")
	return repo, base, head
}

// After leaves its own commit out: since counts it, which would put the
// chat's commit under a worktree's work.
func TestAfterLeavesItsOwnCommitOut(t *testing.T) {
	ctx := context.Background()
	repo, base, head := goneWorktree(t)
	got, err := Changes(ctx, repo, Span{After: base, Commit: head})
	if err != nil || len(got) != 1 || got[0].Path != "work.txt" || got[0].Added != 2 {
		t.Errorf("after: %+v, %v", got, err)
	}
	if got, err := Changes(ctx, repo, Span{Since: base, Commit: head}); err != nil || len(got) != 2 {
		t.Errorf("since, as ever: %+v, %v", got, err)
	}
	if got, err := Changes(ctx, repo, Span{After: base, Commit: base}); err != nil || len(got) != 0 {
		t.Errorf("no commits of its own: %+v, %v", got, err)
	}
	if _, err := Changes(ctx, repo, Span{After: "--output=x", Commit: head}); err == nil {
		t.Error("took a flag for a commit")
	}
}

func TestCommitsAndAheadOfACommit(t *testing.T) {
	ctx := context.Background()
	repo, base, head := goneWorktree(t)
	commits, err := Commits(ctx, repo, base, head, 50)
	if err != nil || len(commits) != 1 || commits[0].Hash != head || commits[0].Added != 2 {
		t.Errorf("commits: %+v, %v", commits, err)
	}
	if n, err := Ahead(ctx, repo, base, head); err != nil || n != 1 {
		t.Errorf("ahead: %d, %v", n, err)
	}
	if _, err := Commits(ctx, repo, base, "--all", 50); err == nil {
		t.Error("took a flag for a commit")
	}
	if _, err := Ahead(ctx, repo, base, "--all"); err == nil {
		t.Error("took a flag for a commit")
	}
	st, err := Between(ctx, repo, base, head)
	if err != nil || st.Files != 1 || st.Added != 2 {
		t.Errorf("between: %+v, %v", st, err)
	}
	if !HasCommit(ctx, repo, head) || HasCommit(ctx, repo, "1234567890123456789012345678901234567890") || HasCommit(ctx, repo, "HEAD") {
		t.Error("HasCommit")
	}
}

// WorkSince counts what the Changes view's Branch shows: commits,
// uncommitted and untracked work, with the repository's filters off.
func TestWorkSinceRunsNoFilter(t *testing.T) {
	ctx := context.Background()
	repo := t.TempDir()
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "a.txt"), "one\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "init")
	base := testcheck.Git(t, repo, "rev-parse", "HEAD")
	ran := filepath.Join(t.TempDir(), "filter-ran")
	write(t, filepath.Join(repo, ".git", "info", "attributes"), "*.txt filter=evil\n")
	testcheck.Git(t, repo, "config", "filter.evil.clean", "touch "+ran+"; cat")
	write(t, filepath.Join(repo, "a.txt"), "one\ntwo\n")
	write(t, filepath.Join(repo, "new.txt"), "new\n")
	st, err := WorkSince(ctx, repo, base)
	if err != nil || st.Files != 2 || st.Added != 2 {
		t.Errorf("%+v, %v", st, err)
	}
	if _, err := os.Stat(ran); err == nil {
		t.Error("a filter ran")
	}
}

func TestMerged(t *testing.T) {
	ctx := context.Background()
	w := Worktrees{}
	repo, base, head := goneWorktree(t)
	if got, err := w.Merged(ctx, repo, "", nil); err != nil || got != nil {
		t.Errorf("no tips: %v, %v", got, err)
	}
	const missing = "1234567890123456789012345678901234567890"
	if got, err := w.Merged(ctx, repo, "", []string{head, missing}); err != nil || len(got) != 0 {
		t.Errorf("not merged, and one git lost: %v, %v", got, err)
	}
	testcheck.Git(t, repo, "branch", "-q", "other", head)
	if got, err := w.Merged(ctx, repo, "other", []string{head}); err != nil || !slices.Equal(got, []string{head}) {
		t.Errorf("on the base: %v, %v", got, err)
	}
	if got, err := w.Merged(ctx, repo, "gone-branch", []string{head}); err != nil || len(got) != 0 {
		t.Errorf("a base that's gone: %v, %v", got, err)
	}
	testcheck.Git(t, repo, "merge", "-q", "--ff-only", head)
	if got, err := w.Merged(ctx, repo, "", []string{head, base, missing}); err != nil || !slices.Equal(got, []string{head, base}) {
		t.Errorf("on HEAD: %v, %v", got, err)
	}
	if _, err := w.Merged(ctx, repo, "", []string{"--all"}); err == nil {
		t.Error("took a flag for a commit")
	}
}

// WorkSince takes only a commit's id: a related worktree's stored base
// that reads as an option (git diff --output=<file>) never reaches git
// (integrations review 2026-11-04).
func TestWorkSinceTakesOnlyACommitsID(t *testing.T) {
	ctx := context.Background()
	repo := t.TempDir()
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "init")
	out := filepath.Join(t.TempDir(), "written")
	for _, base := range []string{"--output=" + out, "main", "HEAD~0"} {
		if _, err := WorkSince(ctx, repo, base); err == nil {
			t.Errorf("%q: counted", base)
		}
	}
	if _, err := os.Stat(out); err == nil {
		t.Error("git wrote a file an option named")
	}
	if _, err := WorkSince(ctx, repo, ""); err != nil {
		t.Errorf("since HEAD: %v", err)
	}
}

package git

import (
	"context"
	"errors"
	"io/fs"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

func TestRenameBranch(t *testing.T) {
	ctx := context.Background()
	repo, _ := filepath.EvalSymlinks(t.TempDir())
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Git(t, repo, "commit", "-q", "--allow-empty", "-m", "init")
	wt, _, err := Worktrees{}.Add(ctx, repo, "brave-otter", "", "")
	testcheck.NoErr(t, err)
	head := func(dir string) string {
		out, _ := exec.Command("git", "-C", dir, "symbolic-ref", "--short", "HEAD").Output()
		return strings.TrimSpace(string(out))
	}
	use := func(wt model.Worktree) model.BranchUse {
		t.Helper()
		u, err := Worktrees{}.BranchUse(ctx, wt)
		testcheck.NoErr(t, err)
		return u
	}
	if u := use(wt); u != (model.BranchUse{OnIt: true}) {
		t.Errorf("a fresh worktree's branch: %+v", u)
	}

	// Renamed: the worktree follows, in its own folder.
	testcheck.NoErr(t, Worktrees{}.RenameBranch(ctx, wt, "nushi/fix-the-login"))
	if got := head(wt.Path); got != "nushi/fix-the-login" {
		t.Fatalf("the worktree is on %q", got)
	}
	wt.Branch = "nushi/fix-the-login"
	if u := use(wt); u != (model.BranchUse{OnIt: true}) {
		t.Errorf("after the rename: %+v", u)
	}

	// Taken names, a remote's too, and names git doesn't take.
	testcheck.Git(t, repo, "branch", "nushi/taken")
	bare := t.TempDir()
	testcheck.Git(t, bare, "init", "-q", "--bare")
	testcheck.Git(t, repo, "remote", "add", "up/stream", bare) // a remote's name with a slash
	testcheck.Git(t, repo, "push", "-q", "up/stream", "main:nushi/theirs")
	for _, name := range []string{"nushi/taken", "nushi/theirs"} {
		if err := (Worktrees{}).RenameBranch(ctx, wt, name); !errors.Is(err, fs.ErrExist) {
			t.Errorf("%s: %v", name, err)
		}
	}
	for _, name := range []string{"-x", "a b", "a..b", "x.lock", "@{-1}", ""} {
		if err := (Worktrees{}).RenameBranch(ctx, wt, name); err == nil || errors.Is(err, fs.ErrExist) {
			t.Errorf("%q: %v", name, err)
		}
		if (Worktrees{}).CheckBranch(ctx, repo, name) == nil {
			t.Errorf("%q checked", name)
		}
	}
	testcheck.NoErr(t, Worktrees{}.CheckBranch(ctx, repo, "nushi/taken")) // a name git takes, taken or not
	if head(wt.Path) != wt.Branch {
		t.Fatal("a refused rename renamed")
	}

	// Pushed, with its upstream set.
	testcheck.Git(t, wt.Path, "push", "-q", "-u", "up/stream", "HEAD")
	if u := use(wt); u != (model.BranchUse{OnIt: true, Upstream: true, Pushed: true}) {
		t.Errorf("after a push: %+v", u)
	}

	// Checked out elsewhere: the worktree moved to another branch, and the
	// repository's folder took it.
	other, _, err := Worktrees{}.Add(ctx, repo, "calm-heron", "", "")
	testcheck.NoErr(t, err)
	testcheck.Git(t, other.Path, "switch", "-q", "-c", "elsewhere")
	testcheck.Git(t, repo, "switch", "-q", other.Branch)
	if u := use(other); u != (model.BranchUse{Elsewhere: true}) {
		t.Errorf("checked out elsewhere: %+v", u)
	}
}

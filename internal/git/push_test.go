package git

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/testcheck"
)

// pushRepo is a repository with one commit on main and a bare repository
// in a temp folder as its origin, nothing pushed yet.
func pushRepo(t *testing.T) (repo, remote string) {
	t.Helper()
	repo, remote = t.TempDir(), filepath.Join(t.TempDir(), "remote.git")
	testcheck.Git(t, t.TempDir(), "init", "-q", "--bare", remote)
	testcheck.Git(t, repo, "init", "-q", "-b", "main")
	testcheck.Git(t, repo, "config", "user.name", "Test")
	testcheck.Git(t, repo, "config", "user.email", "test@example.com")
	testcheck.Git(t, repo, "config", "commit.gpgsign", "false")
	testcheck.Write(t, filepath.Join(repo, "f.txt"), "one\n")
	testcheck.Git(t, repo, "add", ".")
	testcheck.Git(t, repo, "commit", "-q", "-m", "one")
	testcheck.Git(t, repo, "remote", "add", "origin", remote)
	return repo, remote
}

func commitIn(t *testing.T, repo, text string) {
	t.Helper()
	testcheck.Write(t, filepath.Join(repo, "f.txt"), text)
	testcheck.Git(t, repo, "commit", "-q", "-am", text)
}

func pushState(ctx context.Context, t *testing.T, repo string) PushState {
	t.Helper()
	st, err := PushStatus(ctx, repo)
	testcheck.NoErr(t, err)
	return st
}

func TestPush(t *testing.T) {
	ctx := context.Background()
	repo, remote := pushRepo(t)
	testcheck.Git(t, repo, "switch", "-q", "-c", "feature/x")
	commitIn(t, repo, "two\n")
	testcheck.Git(t, repo, "tag", "v1")
	testcheck.Git(t, repo, "config", "push.followTags", "true")
	testcheck.Git(t, repo, "config", "push.default", "matching")

	if st := pushState(ctx, t, repo); st != (PushState{Unpublished: true}) {
		t.Fatalf("before the first push: %+v", st)
	}
	branch, to, err := Push(ctx, repo, ownConfig())
	if err != nil || branch != "feature/x" || to != "origin" {
		t.Fatalf("push: %q %q %v", branch, to, err)
	}
	if got := testcheck.Git(t, remote, "for-each-ref", "--format=%(refname)"); got != "refs/heads/feature/x" {
		t.Fatalf("the remote has %q: only the branch, no tag, not main", got)
	}
	if up := testcheck.Git(t, repo, "rev-parse", "--abbrev-ref", "@{u}"); up != "origin/feature/x" {
		t.Fatalf("upstream %q", up)
	}
	if st := pushState(ctx, t, repo); st != (PushState{}) {
		t.Fatalf("after: %+v", st)
	}

	commitIn(t, repo, "three\n")
	commitIn(t, repo, "four\n")
	if st := pushState(ctx, t, repo); st != (PushState{Unpushed: 2}) {
		t.Fatalf("two to push: %+v", st)
	}
	if _, _, err := Push(ctx, repo, ownConfig()); err != nil {
		t.Fatal(err)
	}
	if got, want := testcheck.Git(t, remote, "rev-parse", "feature/x"), testcheck.Git(t, repo, "rev-parse", "HEAD"); got != want {
		t.Fatalf("the remote is at %s, not %s", got, want)
	}
}

// A push the remote refuses as not a fast-forward fails with git's words;
// it's never forced.
func TestPushNeverForces(t *testing.T) {
	ctx := context.Background()
	repo, remote := pushRepo(t)
	_, _, err := Push(ctx, repo, ownConfig())
	testcheck.NoErr(t, err)
	other := t.TempDir()
	testcheck.Git(t, other, "clone", "-q", remote, ".")
	testcheck.Write(t, filepath.Join(other, "g.txt"), "theirs\n")
	testcheck.Git(t, other, "add", ".")
	testcheck.Git(t, other, "commit", "-q", "-m", "theirs")
	testcheck.Git(t, other, "push", "-q", "origin", "main")
	theirs := testcheck.Git(t, remote, "rev-parse", "main")

	testcheck.Git(t, repo, "config", "remote.origin.push", "+refs/heads/*:refs/heads/*") // a forcing refspec of the config's
	commitIn(t, repo, "mine\n")
	_, _, err = Push(ctx, repo, ownConfig())
	if pe, ok := errors.AsType[*PushError](err); !ok || !strings.Contains(pe.Said, "rejected") {
		t.Fatalf("a diverged push: %v", err)
	}
	if got := testcheck.Git(t, remote, "rev-parse", "main"); got != theirs {
		t.Fatal("the remote's branch was overwritten")
	}
}

// What Push refuses shows nothing to push.
func TestPushRefuses(t *testing.T) {
	ctx := context.Background()
	cases := map[string]func(t *testing.T, repo string){
		"detached": func(t *testing.T, repo string) {
			t.Helper()
			testcheck.Git(t, repo, "switch", "-q", "--detach")
		},
		"no remote": func(t *testing.T, repo string) {
			t.Helper()
			testcheck.Git(t, repo, "remote", "remove", "origin")
		},
		"several, none origin": func(t *testing.T, repo string) {
			t.Helper()
			testcheck.Git(t, repo, "remote", "rename", "origin", "a")
			testcheck.Git(t, repo, "remote", "add", "b", t.TempDir())
		},
		"an upstream of another name": func(t *testing.T, repo string) {
			t.Helper()
			_, _, err := Push(ctx, repo, ownConfig())
			testcheck.NoErr(t, err)
			testcheck.Git(t, repo, "switch", "-q", "-c", "feat", "--track", "origin/main")
			commitIn(t, repo, "feat\n")
		},
		"a local upstream": func(t *testing.T, repo string) {
			t.Helper()
			testcheck.Git(t, repo, "switch", "-q", "-c", "feat", "--track", "main")
			commitIn(t, repo, "feat\n")
		},
	}
	for name, setup := range cases {
		t.Run(name, func(t *testing.T) {
			repo, remote := pushRepo(t)
			setup(t, repo)
			before := testcheck.Git(t, remote, "for-each-ref")
			if st := pushState(ctx, t, repo); st != (PushState{}) {
				t.Errorf("state %+v", st)
			}
			if _, _, err := Push(ctx, repo, ownConfig()); err == nil {
				t.Error("pushed")
			}
			if after := testcheck.Git(t, remote, "for-each-ref"); after != before {
				t.Errorf("the remote changed: %q", after)
			}
		})
	}
}

// The repository's pre-push hook runs, and its failure is what the app
// shows.
func TestPushRunsHooks(t *testing.T) {
	ctx := context.Background()
	repo, remote := pushRepo(t)
	hook := filepath.Join(repo, ".git", "hooks", "pre-push")
	testcheck.NoErr(t, os.WriteFile(hook, []byte("#!/bin/sh\necho 'lint: bad file' >&2\nexit 1\n"), 0o700))
	_, _, err := Push(ctx, repo, ownConfig())
	if pe, ok := errors.AsType[*PushError](err); !ok || !strings.Contains(pe.Said, "lint: bad file") {
		t.Fatalf("a failing hook: %v", err)
	}
	if got := testcheck.Git(t, remote, "for-each-ref"); got != "" {
		t.Fatalf("pushed past the hook: %q", got)
	}
	testcheck.NoErr(t, os.WriteFile(hook, []byte("#!/bin/sh\ntouch .git/hook-ran\n"), 0o700))
	if _, _, err := Push(ctx, repo, ownConfig()); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(repo, ".git", "hook-ran")); err != nil {
		t.Fatal("the hook didn't run")
	}
}

// Its request ending ends a push, a slow hook and all.
func TestPushEndsWithItsRequest(t *testing.T) {
	repo, remote := pushRepo(t)
	hook := filepath.Join(repo, ".git", "hooks", "pre-push")
	testcheck.NoErr(t, os.WriteFile(hook, []byte("#!/bin/sh\nsleep 30\n"), 0o700))
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
	defer cancel()
	start := time.Now()
	_, _, err := Push(ctx, repo, ownConfig())
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("err %v", err)
	}
	if took := time.Since(start); took > 10*time.Second {
		t.Fatalf("took %s", took)
	}
	if got := testcheck.Git(t, remote, "for-each-ref"); got != "" {
		t.Fatalf("pushed: %q", got)
	}
}

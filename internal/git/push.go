package git

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"os/exec"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/procgroup"
	"github.com/afrase/nushi/internal/secrets"
)

// Pushing from Changes (ADR 0079's push amendment): the folder's branch
// alone, on the user's click, as the user's own git push.

// pushTimeout bounds a push: a pre-push hook may lint and test for
// minutes, but a credential prompt nobody answers mustn't hold it for ever.
// Ending the request ends it sooner.
const pushTimeout = 15 * time.Minute

// PushState says what Push would send from a folder: the commits its
// branch has that the remote's copy lacks, or that the remote has no copy
// of it yet. Both are zero when Push would refuse (HEAD detached, no remote
// to pick, an upstream that is another branch or a local one).
type PushState struct {
	Unpushed    int
	Unpublished bool
}

// pushTarget is where Push sends folder's branch: its upstream's remote
// when it has one (of the same name: tracked is that remote's copy), else
// the only remote or origin, setting the upstream.
type pushTarget struct {
	branch, remote, tracked string
	setUpstream             bool
}

// target finds where Push sends folder's branch, or why it won't.
func target(ctx context.Context, folder string) (pushTarget, error) {
	branch := branchName(ctx, folder)
	if branch == "" {
		return pushTarget{}, errors.New("HEAD is detached: there is no branch to push")
	}
	t := pushTarget{branch: branch}
	out, err := run(ctx, folder, "for-each-ref", "--format=%(upstream:remotename)%00%(upstream:remoteref)%00%(upstream)", "--", "refs/heads/"+branch)
	if err != nil {
		return pushTarget{}, err
	}
	f := strings.Split(strings.TrimSuffix(string(out), "\n"), "\x00")
	if len(f) != 3 {
		return pushTarget{}, fmt.Errorf("git for-each-ref: can't read %q", out)
	}
	remote, ref, upstream := f[0], f[1], f[2]
	remotes, err := Remotes(ctx, folder)
	if err != nil {
		return pushTarget{}, err
	}
	names := make([]string, len(remotes))
	for i, r := range remotes {
		names[i] = r.Name
	}
	switch {
	case remote == "" && ref == "":
		t.setUpstream = true
		switch {
		case len(names) == 1:
			t.remote = names[0]
		case slices.Contains(names, "origin"):
			t.remote = "origin"
		case len(names) == 0:
			return pushTarget{}, errors.New("the repository has no remote to push to")
		default:
			return pushTarget{}, errors.New("the branch has no upstream, and of the repository's remotes none is origin: push it in a terminal to pick one")
		}
	case remote == "." || !slices.Contains(names, remote):
		return pushTarget{}, errors.New("the branch's upstream isn't on one of the repository's remotes: push it in a terminal")
	case ref != "refs/heads/"+branch:
		return pushTarget{}, fmt.Errorf("the branch's upstream is %s's %s, a branch of another name: push it in a terminal", remote, strings.TrimPrefix(ref, "refs/heads/"))
	default:
		t.remote = remote
	}
	// The remote's copy as last fetched, if git has one.
	tracked := cmp.Or(upstream, "refs/remotes/"+t.remote+"/"+branch)
	if _, err := verify(ctx, folder, tracked); err == nil {
		t.tracked = tracked
	}
	return t, nil
}

// PushStatus says what Push would send from folder; nothing when Push
// would refuse. It reads git's own refs (no network): the remote's copy is
// as last fetched.
func PushStatus(ctx context.Context, folder string) (PushState, error) {
	t, err := target(ctx, folder)
	if err != nil {
		return PushState{}, nil //nolint:nilerr // a push that would be refused shows nothing to push
	}
	if t.tracked == "" {
		return PushState{Unpublished: true}, nil
	}
	out, err := run(ctx, folder, "rev-list", "--count", "HEAD", "--not", t.tracked, "--")
	if err != nil {
		return PushState{}, err
	}
	n, err := strconv.Atoi(strings.TrimSpace(string(out)))
	return PushState{Unpushed: n}, err
}

// Push pushes folder's branch, and nothing else, as the user's own git
// push would, with environ, their shell's: their hooks run (pre-push) and
// their credential helper answers. It goes to the branch's upstream (one of
// the same name), or with none to the only remote or origin, setting the
// upstream. Never a force, never tags or another branch or a submodule's,
// never a detached HEAD; a push the remote refuses (not a fast-forward)
// fails with git's words. It returns the branch and the remote.
func Push(ctx context.Context, folder string, environ []string) (branch, remote string, err error) {
	t, err := target(ctx, folder)
	if err != nil {
		return "", "", err
	}
	asked := ctx
	ctx, cancel := context.WithTimeout(ctx, pushTimeout)
	defer cancel()
	ref := "refs/heads/" + t.branch
	args := []string{"-c", "core.fsmonitor=false", "-C", folder, "push", "--no-follow-tags", "--no-recurse-submodules"}
	if t.setUpstream {
		args = append(args, "--set-upstream")
	}
	cmd := exec.CommandContext(ctx, "git", append(args, "--", t.remote, ref+":"+ref)...)
	cmd.Env = append(slices.Clone(environ), "GIT_NO_LAZY_FETCH=1", "GIT_TERMINAL_PROMPT=0")
	var said capped
	cmd.Stdout, cmd.Stderr = &said, &said
	procgroup.Bound(cmd)
	// exec.ErrWaitDelay: git exited 0, and an ssh master it started
	// (ControlPersist) still held its output a second later.
	if err := cmd.Run(); err != nil && !errors.Is(err, exec.ErrWaitDelay) {
		if asked.Err() != nil {
			return "", "", asked.Err()
		}
		if ctx.Err() != nil {
			return "", "", fmt.Errorf("git push gave up after %s: a hook or a credential prompt took too long", pushTimeout)
		}
		return "", "", &PushError{Said: secrets.Mask(cmp.Or(lastSaid(said.b), err.Error()), "[hidden]", nil)}
	}
	return t.branch, t.remote, nil
}

// PushError is a push that failed, with the end of what it printed (a
// hook's output, the remote's refusal): the app's to show, never the
// log's, as CommitError's.
type PushError struct{ Said string }

func (e *PushError) Error() string { return "git push: " + e.Said }

// Logged is the failure as the daemon's log says it.
func (e *PushError) Logged() string { return "git push failed" }

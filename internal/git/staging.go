package git

import (
	"cmp"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/ansi"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/procgroup"
	"github.com/afrase/nushi/internal/secrets"
)

// The git writes a user asks for in Changes (ADR 0079). Nothing here runs on
// its own.

const (
	// A commit's hooks may lint and test, but a signing prompt nobody
	// answers mustn't hold it for ever.
	commitTimeout   = 5 * time.Minute
	maxCommitSays   = 4 << 10 // what's shown of a commit that failed, its end
	maxDiffForAgent = 64 << 10
)

// ErrIndexMoved is a commit refused because what's staged isn't what the
// app showed: the agent, or a terminal, staged or committed since.
var ErrIndexMoved = errors.New("what's staged changed since it was shown; look again")

// Stage adds paths (relative to folder, literal) to the index as they are
// in the work tree, a deleted file's deletion too, or with on false takes
// them out of it. Filters and core.* run as in the user's own git add; hooks
// don't: only a commit has any that matter.
func Stage(ctx context.Context, folder string, paths []string, on bool) error {
	for _, p := range paths {
		if !filepath.IsLocal(p) || strings.ContainsRune(p, 0) {
			return fmt.Errorf("%q isn't inside the folder", p)
		}
	}
	args := []string{"reset", "-q"}
	if on {
		args = []string{"add", "-A"}
	}
	cmd := command(ctx, folder, nil, append(args, "--pathspec-from-file=-", "--pathspec-file-nul")...)
	cmd.Env = append(cmd.Env, "GIT_LITERAL_PATHSPECS=1")
	cmd.Stdin = strings.NewReader(strings.Join(paths, "\x00"))
	return finish(cmd, args[0])
}

// StagedDiff is what's staged in folder as a patch, for an agent to read:
// secrets' shapes masked, and cut short past what a message needs.
func StagedDiff(ctx context.Context, folder string) (string, error) {
	var out capped
	if _, err := runTo(ctx, folder, nil, &out, "diff", "--cached", "--relative", "--no-color", "--no-ext-diff", "--no-textconv", "--ignore-submodules=dirty"); err != nil {
		return "", err
	}
	if len(out.b) == 0 {
		return "", errors.New("nothing is staged")
	}
	s := secrets.Mask(strings.ToValidUTF8(string(out.b), ""), "[hidden]", nil)
	if len(s) > maxDiffForAgent {
		s = strings.ToValidUTF8(s[:maxDiffForAgent], "") + "\n[the rest of the diff is left out]"
	}
	return s, nil
}

// IndexState names what's staged in folder's repository against HEAD, every
// blob's id in it, for CommitStaged to check.
func IndexState(ctx context.Context, folder string) (string, error) {
	out, err := run(ctx, folder, "diff", "--cached", "--raw", "-z", "--no-abbrev", "--no-renames", "--ignore-submodules=dirty")
	if err != nil {
		return "", err
	}
	head, _ := run(ctx, folder, "rev-parse", "-q", "--verify", "HEAD") // none before the first commit
	sum := sha256.Sum256(append(head, out...))
	return hex.EncodeToString(sum[:16]), nil
}

// CommitStaged commits what's staged in folder's repository with message, as the
// user's own git commit would, with environ, their shell's, so hooks find
// their tools: hooks and signing run; only core.fsmonitor stays off, as it
// does for every git Nushi runs. It refuses when index, from IndexState, no
// longer names what's staged, and when something outside folder is staged,
// which the app's view of folder never showed. It returns the commit's
// short hash.
func CommitStaged(ctx context.Context, folder, message, index string, environ []string) (string, error) {
	state, err := IndexState(ctx, folder)
	if err != nil {
		return "", err
	}
	if state != index {
		return "", ErrIndexMoved
	}
	here, err := run(ctx, folder, "diff", "--cached", "--name-only", "-z", "--no-renames", "--relative", "--ignore-submodules=dirty")
	if err != nil {
		return "", err
	}
	all, err := run(ctx, folder, "diff", "--cached", "--name-only", "-z", "--no-renames", "--ignore-submodules=dirty")
	if err != nil {
		return "", err
	}
	switch n := len(split(all)); {
	case n == 0:
		return "", errors.New("nothing is staged")
	case n != len(split(here)):
		return "", errors.New("files outside this folder are staged too; commit them in a terminal")
	}
	ctx, cancel := context.WithTimeout(ctx, commitTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "git", "-c", "core.fsmonitor=false", "-C", folder, "commit", "-q", "-F", "-")
	cmd.Env = append(slices.Clone(environ), "GIT_NO_LAZY_FETCH=1", "GIT_TERMINAL_PROMPT=0")
	cmd.Stdin = strings.NewReader(message)
	var said capped
	cmd.Stdout, cmd.Stderr = &said, &said
	procgroup.Bound(cmd)
	if err := cmd.Run(); err != nil {
		if ctx.Err() != nil {
			return "", fmt.Errorf("git commit gave up after %s: a hook or a signing prompt took too long", commitTimeout)
		}
		return "", &CommitError{Said: cmp.Or(lastSaid(said.b), err.Error())}
	}
	out, err := run(ctx, folder, "rev-parse", "--short", "HEAD")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

// CommitError is a commit that failed, with the end of what it printed:
// a hook's output, which can quote the message (commitlint's "input:"),
// so it is the app's to show and never the log's.
type CommitError struct{ Said string }

func (e *CommitError) Error() string { return "git commit: " + e.Said }

// lastSaid is the end of a commit's output, which is where a hook's failure
// is, as plain text.
func lastSaid(b []byte) string {
	s := strings.ToValidUTF8(ansi.Strip(string(b)), "")
	s = strings.Map(func(r rune) rune {
		if r < 0x20 && r != '\n' && r != '\t' || r == 0x7f {
			return -1
		}
		return r
	}, strings.TrimSpace(s))
	if len(s) > maxCommitSays {
		s = strings.ToValidUTF8("…"+s[len(s)-maxCommitSays:], "")
	}
	return s
}

// markStaged says how much of each change is in the index.
func markStaged(ctx context.Context, folder string, changes []model.FileChange) error {
	list := func(args ...string) (map[string]bool, error) {
		out, err := run(ctx, folder, append(append([]string{"diff"}, args...), "--name-only", "-z", "--no-renames", "--relative", "--ignore-submodules=dirty")...)
		if err != nil {
			return nil, err
		}
		set := map[string]bool{}
		for _, p := range split(out) {
			set[p] = true
		}
		return set, nil
	}
	staged, err := list("--cached")
	if err != nil {
		return err
	}
	unstaged, err := list()
	if err != nil {
		return err
	}
	for i := range changes {
		c := &changes[i]
		paths := []string{c.Path}
		if c.OldPath != "" {
			paths = append(paths, c.OldPath) // a rename is two: a new file, and the old one's deletion
		}
		in := func(p string) bool { return staged[p] }
		whole := func(p string) bool { return staged[p] && !unstaged[p] }
		switch {
		case slices.ContainsFunc(paths, in) && !allOf(paths, whole):
			c.Staged = model.StagedPart
		case allOf(paths, whole):
			c.Staged = model.StagedAll
		}
	}
	return nil
}

func allOf(paths []string, ok func(string) bool) bool {
	return !slices.ContainsFunc(paths, func(p string) bool { return !ok(p) })
}

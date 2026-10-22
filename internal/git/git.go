// Package git reads a folder's changes with the git command.
package git

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// maxText is the largest text shown in a diff, per side.
const maxText = 1 << 20

// Changes returns the folder's uncommitted changes against HEAD, untracked
// files included, with paths relative to the folder. The folder may be
// anywhere inside a repository.
func Changes(ctx context.Context, folder string) ([]model.FileChange, error) {
	if _, err := run(ctx, folder, "rev-parse", "--show-toplevel"); err != nil {
		return nil, fmt.Errorf("%s is not in a git repository", folder)
	}
	_, err := run(ctx, folder, "rev-parse", "--verify", "-q", "HEAD")
	hasHead := err == nil

	var changes []model.FileChange
	if hasHead {
		out, err := run(ctx, folder, "diff", "HEAD", "--name-status", "-z", "--no-renames", "--relative", "--no-ext-diff", "--no-textconv")
		if err != nil {
			return nil, err
		}
		fields := split(out)
		for i := 0; i+1 < len(fields); i += 2 {
			status := map[string]string{"A": "added", "D": "deleted"}[fields[i][:1]]
			if status == "" {
				status = "modified"
			}
			changes = append(changes, model.FileChange{Path: fields[i+1], Status: status})
		}
	}
	untracked := []string{"ls-files", "-z", "--others", "--exclude-standard"}
	if !hasHead {
		untracked = append(untracked, "--cached")
	}
	out, err := run(ctx, folder, untracked...)
	if err != nil {
		return nil, err
	}
	for _, p := range split(out) {
		changes = append(changes, model.FileChange{Path: p, Status: "added"})
	}

	slices.SortFunc(changes, func(a, b model.FileChange) int { return strings.Compare(a.Path, b.Path) })
	for i := range changes {
		c := &changes[i]
		var old, cur []byte
		if c.Status != "added" {
			if old, err = run(ctx, folder, "show", "--no-textconv", "HEAD:./"+c.Path); err != nil {
				return nil, err
			}
		}
		if c.Status != "deleted" {
			if cur, err = worktree(filepath.Join(folder, c.Path)); err != nil {
				return nil, err
			}
		}
		switch {
		case bytes.IndexByte(old, 0) >= 0 || bytes.IndexByte(cur, 0) >= 0:
			c.Skipped = "binary"
		case len(old) > maxText || len(cur) > maxText:
			c.Skipped = "too large"
		default:
			c.Old, c.New = string(old), string(cur)
		}
	}
	return changes, nil
}

// worktree reads a file as git sees it: a symlink is its target's path.
func worktree(path string) ([]byte, error) {
	fi, err := os.Lstat(path)
	if err != nil {
		return nil, err
	}
	if fi.Mode()&os.ModeSymlink != 0 {
		target, err := os.Readlink(path)
		return []byte(target), err
	}
	return os.ReadFile(path)
}

// run runs git in dir. The repository's config can't make it run other
// programs (fsmonitor, external diff and textconv drivers are off).
func run(ctx context.Context, dir string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, "git", append([]string{"-c", "core.fsmonitor=false", "-C", dir}, args...)...)
	cmd.Env = append(os.Environ(), "GIT_OPTIONAL_LOCKS=0")
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		var exit *exec.ExitError
		if errors.As(err, &exit) {
			return nil, fmt.Errorf("git %s: %s", args[0], strings.TrimSpace(stderr.String()))
		}
		return nil, err
	}
	return out, nil
}

// split splits git's NUL-separated output.
func split(out []byte) []string {
	s := strings.TrimSuffix(string(out), "\x00")
	if s == "" {
		return nil
	}
	return strings.Split(s, "\x00")
}

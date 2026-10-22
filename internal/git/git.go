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
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// maxText is the largest text shown in a diff, per side.
const maxText = 1 << 20

// Changes returns the folder's uncommitted changes against HEAD, untracked
// files included, with paths relative to the folder. The folder may be
// anywhere inside a repository.
func Changes(ctx context.Context, folder string) ([]model.FileChange, error) {
	hasHead, err := repo(ctx, folder)
	if err != nil {
		return nil, err
	}
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
	added, err := untracked(ctx, folder, hasHead)
	if err != nil {
		return nil, err
	}
	for _, p := range added {
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

// ErrNotRepository says a folder isn't in a git repository.
var ErrNotRepository = errors.New("not in a git repository")

// repo checks that folder is in a git repository, and says whether it has
// a commit checked out.
func repo(ctx context.Context, folder string) (hasHead bool, err error) {
	if _, err := run(ctx, folder, "rev-parse", "--show-toplevel"); err != nil {
		return false, fmt.Errorf("%s is %w", folder, ErrNotRepository)
	}
	_, err = run(ctx, folder, "rev-parse", "--verify", "-q", "HEAD")
	return err == nil, nil
}

// untracked lists the files that are new to git: untracked ones, and before
// the first commit every file.
func untracked(ctx context.Context, folder string, hasHead bool) ([]string, error) {
	args := []string{"ls-files", "-z", "--others", "--exclude-standard"}
	if !hasHead {
		args = append(args, "--cached")
	}
	out, err := run(ctx, folder, args...)
	return split(out), err
}

// Status sums up the folder's uncommitted changes as Changes lists them
// (the files, and the lines added and removed; binary and over-large files
// count no lines), and names the branch checked out, or the commit when
// none is.
func Status(ctx context.Context, folder string) (model.FolderStatus, error) {
	var st model.FolderStatus
	hasHead, err := repo(ctx, folder)
	if err != nil {
		return st, err
	}
	if out, err := run(ctx, folder, "symbolic-ref", "--short", "-q", "HEAD"); err == nil {
		st.Branch = strings.TrimSpace(string(out))
	} else if out, err := run(ctx, folder, "rev-parse", "--short", "HEAD"); err == nil {
		st.Branch = strings.TrimSpace(string(out))
	}
	if hasHead {
		out, err := run(ctx, folder, "diff", "HEAD", "--numstat", "-z", "--no-renames", "--relative", "--no-ext-diff", "--no-textconv")
		if err != nil {
			return st, err
		}
		for _, f := range split(out) { // added, removed ("-" if binary), path
			added, rest, _ := strings.Cut(f, "\t")
			removed, _, _ := strings.Cut(rest, "\t")
			a, _ := strconv.Atoi(added)
			r, _ := strconv.Atoi(removed)
			st.Files, st.Added, st.Removed = st.Files+1, st.Added+a, st.Removed+r
		}
	}
	added, err := untracked(ctx, folder, hasHead)
	if err != nil {
		return st, err
	}
	for _, p := range added {
		st.Files++
		b, err := worktree(filepath.Join(folder, p))
		if err == nil && len(b) <= maxText && bytes.IndexByte(b, 0) < 0 && len(b) > 0 {
			st.Added += bytes.Count(b, []byte("\n"))
			if b[len(b)-1] != '\n' {
				st.Added++
			}
		}
	}
	return st, nil
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

// Files lists up to limit files under folder, relative to it: in a
// repository, git's tracked and untracked files that aren't ignored;
// elsewhere, every file outside hidden folders.
func Files(ctx context.Context, folder string, limit int) ([]string, error) {
	if out, err := run(ctx, folder, "ls-files", "-z", "--cached", "--others", "--exclude-standard"); err == nil {
		files := split(out)
		return files[:min(len(files), limit)], nil
	}
	var files []string
	err := filepath.WalkDir(folder, func(path string, d os.DirEntry, err error) error {
		switch {
		case err != nil || len(files) >= limit:
			return filepath.SkipAll
		case d.IsDir() && path != folder && strings.HasPrefix(d.Name(), "."):
			return filepath.SkipDir
		case !d.IsDir():
			rel, _ := filepath.Rel(folder, path)
			files = append(files, rel)
		}
		return nil
	})
	return files, err
}

// run runs git in dir, with fsmonitor, external diff and textconv drivers
// off. Clean filters still run when git compares the work tree (git diff
// does): a filter only runs if git config defines it, and a repository
// can't bring config along, so that takes someone who can already write
// the user's config, as with any git command run there.
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

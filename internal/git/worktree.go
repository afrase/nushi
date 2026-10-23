package git

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// Worktrees makes and removes git worktrees.
type Worktrees struct{}

// Add makes a worktree of folder's repository at <repo>/.worktrees/<name>,
// on a new branch nushi/<name> from folder's HEAD, and keeps .worktrees/
// out of git through the repository's info/exclude. It returns the
// worktree and the folder in it that matches folder (the same subfolder).
// A name already taken (folder or branch) fails with fs.ErrExist.
func (Worktrees) Add(ctx context.Context, folder, name string) (model.Worktree, string, error) {
	var wt model.Worktree
	repo, err := mainWorktree(ctx, folder)
	if err != nil {
		return wt, "", err
	}
	prefix, err := run(ctx, folder, "rev-parse", "--show-prefix")
	if err != nil {
		return wt, "", err
	}
	sub := strings.TrimSuffix(strings.TrimSpace(string(prefix)), "/")
	top := strings.TrimSuffix(filepath.Clean(folder), "/"+sub)
	if real, err := filepath.EvalSymlinks(top); err == nil && real == repo {
		repo = top // the folder's spelling: git resolves symlinks
	}
	wt = model.Worktree{Repo: repo, Path: filepath.Join(repo, ".worktrees", name), Branch: "nushi/" + name}
	if _, err := os.Lstat(wt.Path); err == nil {
		return wt, "", fmt.Errorf("%s: %w", wt.Path, fs.ErrExist)
	}
	if _, err := run(ctx, folder, "rev-parse", "--verify", "-q", "refs/heads/"+wt.Branch); err == nil {
		return wt, "", fmt.Errorf("branch %s: %w", wt.Branch, fs.ErrExist)
	}
	if out, err := run(ctx, folder, "symbolic-ref", "--short", "-q", "HEAD"); err == nil {
		wt.Base = strings.TrimSpace(string(out))
	} else if out, err := run(ctx, folder, "rev-parse", "--verify", "HEAD"); err == nil {
		wt.Base = strings.TrimSpace(string(out)) // detached
	} else {
		return wt, "", errors.New("the repository has no commits yet")
	}
	if err := exclude(ctx, folder); err != nil {
		return wt, "", err
	}
	if _, err := run(ctx, folder, "worktree", "add", "-q", "-b", wt.Branch, wt.Path, "HEAD"); err != nil {
		return wt, "", err
	}
	return wt, filepath.Join(wt.Path, sub), nil
}

// Remove removes a worktree that holds no work: git refuses one with
// changes, and the branch goes only if it is merged.
func (Worktrees) Remove(ctx context.Context, wt model.Worktree) error {
	if _, err := run(ctx, wt.Repo, "worktree", "remove", wt.Path); err != nil {
		return err
	}
	_, err := run(ctx, wt.Repo, "branch", "-d", wt.Branch)
	return err
}

// mainWorktree returns the folder of the main worktree of folder's
// repository: the repository's own folder.
func mainWorktree(ctx context.Context, folder string) (string, error) {
	out, err := run(ctx, folder, "worktree", "list", "--porcelain")
	if err != nil {
		return "", fmt.Errorf("%s is %w", folder, ErrNotRepository)
	}
	sc := bufio.NewScanner(bytes.NewReader(out))
	var repo string
	for sc.Scan() && sc.Text() != "" { // the first entry is the main worktree
		if path, ok := strings.CutPrefix(sc.Text(), "worktree "); ok {
			repo = path
		} else if sc.Text() == "bare" {
			return "", errors.New("a bare repository has no main worktree")
		}
	}
	return repo, nil
}

// exclude adds .worktrees/ to the repository's info/exclude, once.
func exclude(ctx context.Context, folder string) error {
	out, err := run(ctx, folder, "rev-parse", "--path-format=absolute", "--git-path", "info/exclude")
	if err != nil {
		return err
	}
	path := strings.TrimSpace(string(out))
	b, err := os.ReadFile(path)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	for line := range strings.Lines(string(b)) {
		if l := strings.TrimSpace(line); l == ".worktrees/" || l == "/.worktrees/" {
			return nil
		}
	}
	if len(b) > 0 && b[len(b)-1] != '\n' {
		b = append(b, '\n')
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, append(b, "/.worktrees/\n"...), 0o644)
}

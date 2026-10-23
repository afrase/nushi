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
	"strconv"
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
	if err := Exclude(ctx, folder, "/.worktrees/"); err != nil {
		return wt, "", err
	}
	if _, err := run(ctx, folder, "worktree", "add", "-q", "-b", wt.Branch, wt.Path, "HEAD"); err != nil {
		return wt, "", err
	}
	return wt, filepath.Join(wt.Path, sub), nil
}

// Inspect says what removing a worktree and deleting its branch would lose.
func (Worktrees) Inspect(ctx context.Context, wt model.Worktree) (model.WorktreeState, error) {
	var st model.WorktreeState
	if _, err := os.Stat(wt.Path); errors.Is(err, fs.ErrNotExist) {
		st.Gone = true
	} else if out, err := run(ctx, wt.Path, "status", "--porcelain", "-z", "--untracked-files=all"); err != nil {
		return st, err
	} else {
		st.Changed = len(split(out))
	}
	if _, err := run(ctx, wt.Repo, "rev-parse", "--verify", "-q", "refs/heads/"+wt.Branch); err != nil {
		st.BranchGone = true
		return st, nil
	}
	out, err := run(ctx, wt.Repo, "rev-list", "--count", "refs/heads/"+wt.Branch, "--not", wt.Base)
	if err != nil {
		return st, err
	}
	st.Commits, err = strconv.Atoi(strings.TrimSpace(string(out)))
	return st, err
}

// Remove removes a worktree (git worktree remove), with force even if it
// has changes. Of a worktree whose folder is gone, git's record goes (git
// worktree prune, which only drops such records).
func (Worktrees) Remove(ctx context.Context, wt model.Worktree, force bool) error {
	if _, err := os.Stat(wt.Path); errors.Is(err, fs.ErrNotExist) {
		_, err := run(ctx, wt.Repo, "worktree", "prune")
		return err
	}
	args := []string{"worktree", "remove", wt.Path}
	if force {
		args = append(args, "--force")
	}
	_, err := run(ctx, wt.Repo, args...)
	return err
}

// DeleteBranch deletes a worktree's branch, merged or not.
func (Worktrees) DeleteBranch(ctx context.Context, wt model.Worktree) error {
	_, err := run(ctx, wt.Repo, "branch", "-D", wt.Branch)
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

// Exclude adds a line (a pattern) to the repository's info/exclude, once.
func Exclude(ctx context.Context, folder, line string) error {
	out, err := run(ctx, folder, "rev-parse", "--path-format=absolute", "--git-path", "info/exclude")
	if err != nil {
		return err
	}
	path := strings.TrimSpace(string(out))
	b, err := os.ReadFile(path)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	for l := range strings.Lines(string(b)) {
		if strings.TrimSpace(l) == line {
			return nil
		}
	}
	if len(b) > 0 && b[len(b)-1] != '\n' {
		b = append(b, '\n')
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, append(b, line+"\n"...), 0o644)
}

package git

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"

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
	if err := worktreesFolder(repo); err != nil {
		return wt, "", err
	}
	if _, err := os.Lstat(wt.Path); err == nil {
		return wt, "", fmt.Errorf("%s: %w", wt.Path, fs.ErrExist)
	}
	if _, err := run(ctx, folder, "rev-parse", "--verify", "-q", "refs/heads/"+wt.Branch); err == nil {
		return wt, "", fmt.Errorf("branch %s: %w", wt.Branch, fs.ErrExist)
	}
	out, err := run(ctx, folder, "rev-parse", "--verify", "-q", "HEAD")
	if err != nil {
		return wt, "", errors.New("the repository has no commits yet")
	}
	wt.BaseCommit, wt.Base = strings.TrimSpace(string(out)), strings.TrimSpace(string(out)) // detached
	if out, err := run(ctx, folder, "symbolic-ref", "--short", "-q", "HEAD"); err == nil {
		wt.Base = strings.TrimSpace(string(out))
	}
	if err := Exclude(ctx, folder, "/.worktrees/"); err != nil {
		return wt, "", err
	}
	if _, err := run(ctx, folder, "worktree", "add", "-q", "-b", wt.Branch, wt.Path, wt.BaseCommit); err != nil {
		return wt, "", err
	}
	return wt, filepath.Join(wt.Path, sub), nil
}

// worktreesFolder makes <repo>/.worktrees, or checks the one there is a
// folder of the repository's own: a repository could bring a link there
// that sends worktrees anywhere (into ~/.claude/skills, say).
func worktreesFolder(repo string) error {
	dir := filepath.Join(repo, ".worktrees")
	fi, err := os.Lstat(dir)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		err = os.Mkdir(dir, 0o755)
	case err == nil && !fi.IsDir(): // a link too: Lstat doesn't follow it
		err = fmt.Errorf("%s is not a folder (a link?): Nushi won't make worktrees through it", dir)
	}
	if err != nil {
		return err
	}
	real, err := filepath.EvalSymlinks(dir)
	top, terr := filepath.EvalSymlinks(repo)
	if err != nil || terr != nil || real != filepath.Join(top, ".worktrees") {
		return fmt.Errorf("%s isn't in the repository's own folder", dir)
	}
	return nil
}

// Inspect says what removing a worktree and deleting its branch would lose.
func (Worktrees) Inspect(ctx context.Context, wt model.Worktree) (model.WorktreeState, error) {
	var st model.WorktreeState
	if _, err := os.Stat(wt.Path); errors.Is(err, fs.ErrNotExist) {
		st.Gone = true
	} else if out, err := run(ctx, wt.Path, "status", "--porcelain", "-z", "--untracked-files=all"); err != nil {
		return st, err
	} else if ignored, err := run(ctx, wt.Path, "ls-files", "-z", "--others", "--ignored", "--exclude-standard", "--directory"); err != nil {
		return st, err
	} else {
		st.Changed, st.Ignored = len(split(out)), len(split(ignored))
	}
	if _, err := run(ctx, wt.Repo, "rev-parse", "--verify", "-q", "refs/heads/"+wt.Branch); err != nil {
		st.BranchGone = true
		return st, nil
	}
	out, err := run(ctx, wt.Repo, "rev-list", "--count", "refs/heads/"+wt.Branch, "--not", BaseOf(ctx, wt))
	if err != nil {
		return st, err
	}
	st.Commits, err = strconv.Atoi(strings.TrimSpace(string(out)))
	return st, err
}

// BaseOf is what a worktree's work is counted from: its base branch, or
// the commit it started from once that branch is gone (merged and
// deleted, say).
func BaseOf(ctx context.Context, wt model.Worktree) string {
	if _, err := run(ctx, wt.Repo, "rev-parse", "--verify", "-q", wt.Base+"^{commit}"); err != nil && wt.BaseCommit != "" {
		return wt.BaseCommit
	}
	return wt.Base
}

// Remove removes a worktree (git worktree remove), with force even if it
// has changes. Of a worktree whose folder is gone, git's record of it goes
// (only its: not those of others whose folders are missing too, as prune
// would), unless git has none left.
func (Worktrees) Remove(ctx context.Context, wt model.Worktree, force bool) error {
	_, gone := os.Stat(wt.Path)
	args := []string{"worktree", "remove", wt.Path}
	if force {
		args = append(args, "--force")
	}
	_, err := run(ctx, wt.Repo, args...)
	if errors.Is(gone, fs.ErrNotExist) && err != nil && strings.Contains(err.Error(), "is not a working tree") {
		return nil
	}
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

// excludeMu keeps two Excludes from losing each other's line.
var excludeMu sync.Mutex

// Exclude adds a line (a pattern) to the repository's info/exclude, once.
// It writes only a regular file in a real folder: a repository could bring
// a link there to any file of the user's.
func Exclude(ctx context.Context, folder, line string) error {
	// Not --path-format=absolute: that resolves a link at the end.
	out, err := run(ctx, folder, "rev-parse", "--git-path", "info/exclude")
	if err != nil {
		return err
	}
	path := strings.TrimSpace(string(out))
	if !filepath.IsAbs(path) {
		path = filepath.Join(folder, path)
	}
	excludeMu.Lock()
	defer excludeMu.Unlock()
	dir := filepath.Dir(path)
	if fi, err := os.Lstat(dir); errors.Is(err, fs.ErrNotExist) {
		if err := os.Mkdir(dir, 0o755); err != nil {
			return err
		}
	} else if err != nil || !fi.IsDir() {
		return fmt.Errorf("%s is not a folder (a link?)", dir)
	}
	f, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE|os.O_APPEND|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0o644)
	if err != nil {
		return fmt.Errorf("%s: %w (a link?)", path, err)
	}
	defer f.Close()
	if fi, err := f.Stat(); err != nil || !fi.Mode().IsRegular() {
		return fmt.Errorf("%s is not a file", path)
	}
	b, err := io.ReadAll(io.LimitReader(f, 1<<20))
	if err != nil {
		return err
	}
	for l := range strings.Lines(string(b)) {
		if strings.TrimSpace(l) == line {
			return nil
		}
	}
	if len(b) > 0 && b[len(b)-1] != '\n' {
		line = "\n" + line
	}
	_, err = f.WriteString(line + "\n")
	return err
}

package git

import (
	"bufio"
	"bytes"
	"cmp"
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
// on a new branch (branch, else nushi/<name>) from folder's HEAD, or at
// from (a ref: a remote's branch, which the new branch then tracks, or
// another), and keeps .worktrees/ out of git through the repository's
// info/exclude. It returns the worktree and the folder in it that matches
// folder (the same subfolder). A name already taken (folder or branch)
// fails with fs.ErrExist.
func (Worktrees) Add(ctx context.Context, folder, name, branch, from string) (model.Worktree, string, error) {
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
	if resolved, err := filepath.EvalSymlinks(top); err == nil && resolved == repo {
		repo = top // the folder's spelling: git resolves symlinks
	}
	wt = model.Worktree{Repo: repo, Path: filepath.Join(repo, ".worktrees", name), Branch: cmp.Or(branch, "nushi/"+name)}
	if err := worktreesFolder(repo); err != nil {
		return wt, "", err
	}
	if _, err := os.Lstat(wt.Path); err == nil {
		return wt, "", fmt.Errorf("%s: %w", wt.Path, fs.ErrExist)
	}
	if _, err := run(ctx, folder, "rev-parse", "--verify", "-q", "refs/heads/"+wt.Branch); err == nil {
		return wt, "", fmt.Errorf("branch %s: %w", wt.Branch, fs.ErrExist)
	}
	add := []string{"worktree", "add", "-q"}
	if from == "" {
		out, err := run(ctx, folder, "rev-parse", "--verify", "-q", "HEAD")
		if err != nil {
			return wt, "", errors.New("the repository has no commits yet")
		}
		wt.BaseCommit, wt.Base = strings.TrimSpace(string(out)), strings.TrimSpace(string(out)) // detached
		if out, err := run(ctx, folder, "symbolic-ref", "--short", "-q", "HEAD"); err == nil {
			wt.Base = strings.TrimSpace(string(out))
		}
		add = append(add, "-b", wt.Branch, wt.Path, wt.BaseCommit)
	} else {
		if !strings.HasPrefix(from, "refs/") {
			return wt, "", fmt.Errorf("%q isn't a ref", from)
		}
		out, err := run(ctx, folder, "rev-parse", "--verify", "-q", from+"^{commit}")
		if err != nil {
			return wt, "", fmt.Errorf("%s isn't in the repository", from)
		}
		// Work is counted from what was fetched: what the branch has past
		// it is what pushing would add.
		wt.BaseCommit, wt.Base = strings.TrimSpace(string(out)), from
		if strings.HasPrefix(from, "refs/remotes/") {
			add = append(add, "--track")
		}
		add = append(add, "-b", wt.Branch, wt.Path, from)
	}
	if err := Exclude(ctx, folder, "/.worktrees/"); err != nil {
		return wt, "", err
	}
	if _, err := run(ctx, folder, add...); err != nil {
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
		err = os.Mkdir(dir, 0o755) //nolint:gosec // a worktree's folder, as git makes it
	case err == nil && !fi.IsDir(): // a link too: Lstat doesn't follow it
		err = fmt.Errorf("%s is not a folder (a link?): Nushi won't make worktrees through it", dir)
	}
	if err != nil {
		return err
	}
	resolved, err := filepath.EvalSymlinks(dir)
	top, terr := filepath.EvalSymlinks(repo)
	if err != nil || terr != nil || resolved != filepath.Join(top, ".worktrees") {
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
		return st, nil //nolint:nilerr // --verify failing is the answer: the branch is gone
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

// BranchUse says who else has a worktree's branch: whether the worktree
// still has it checked out, another worktree has, it tracks a remote's
// branch, or a remote has one of its name (it was pushed). It reads only
// the repository's own refs and config; it asks no remote.
func (Worktrees) BranchUse(ctx context.Context, wt model.Worktree) (model.BranchUse, error) {
	var u model.BranchUse
	out, err := run(ctx, wt.Repo, "worktree", "list", "--porcelain", "-z")
	if err != nil {
		return u, err
	}
	here := realPath(wt.Path)
	var path string
	for _, field := range split(out) { // entries end with an empty field
		if p, ok := strings.CutPrefix(field, "worktree "); ok {
			path = p
		} else if field == "branch refs/heads/"+wt.Branch {
			on := realPath(path) == here
			u.OnIt, u.Elsewhere = u.OnIt || on, u.Elsewhere || !on
		}
	}
	up, err := run(ctx, wt.Repo, "for-each-ref", "--format=%(upstream)", "refs/heads/"+wt.Branch)
	if err != nil {
		return u, err
	}
	u.Upstream = strings.TrimSpace(string(up)) != ""
	u.Pushed, err = remoteHas(ctx, wt.Repo, wt.Branch)
	return u, err
}

// remoteHas says whether a remote of repo has a branch named branch, as
// last fetched or pushed.
func remoteHas(ctx context.Context, repo, branch string) (bool, error) {
	out, err := run(ctx, repo, "for-each-ref", "--format=%(refname)", "refs/remotes")
	for ref := range strings.Lines(string(out)) {
		if strings.HasSuffix(strings.TrimSpace(ref), "/"+branch) { // the remote's name may hold "/" too
			return true, nil
		}
	}
	return false, err
}

// realPath is path with its links resolved, as git reports worktrees; path
// itself when it can't be (a folder that's gone).
func realPath(path string) string {
	if p, err := filepath.EvalSymlinks(path); err == nil {
		return p
	}
	return filepath.Clean(path)
}

// RenameBranch gives a worktree's branch the name to (git branch -m), which
// the worktrees that have it checked out follow; their folders stay. A
// name git doesn't take is refused, and one already taken (a branch of
// the repository's, or a remote's) fails with fs.ErrExist.
func (w Worktrees) RenameBranch(ctx context.Context, wt model.Worktree, to string) error {
	if err := w.CheckBranch(ctx, wt.Repo, to); err != nil {
		return err
	}
	if _, err := run(ctx, wt.Repo, "rev-parse", "--verify", "-q", "refs/heads/"+to); err == nil {
		return fmt.Errorf("a branch named %s: %w", to, fs.ErrExist)
	}
	if has, err := remoteHas(ctx, wt.Repo, to); err != nil || has {
		return cmp.Or(err, fmt.Errorf("a remote's branch named %s: %w", to, fs.ErrExist))
	}
	_, err := run(ctx, wt.Repo, "branch", "-m", wt.Branch, to)
	return err
}

// CheckBranch refuses a name git wouldn't take for a branch in repo:
// CheckBranch's rules, then git check-ref-format --branch.
func (Worktrees) CheckBranch(ctx context.Context, repo, name string) error {
	if err := CheckBranch(name); err != nil {
		return err
	}
	if _, err := run(ctx, repo, "check-ref-format", "--branch", name); err != nil {
		return fmt.Errorf("%q isn't a name git takes for a branch", name)
	}
	return nil
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
		if err := os.Mkdir(dir, 0o755); err != nil { //nolint:gosec // a repository's info folder, as git makes it
			return err
		}
	} else if err != nil || !fi.IsDir() {
		return fmt.Errorf("%s is not a folder (a link?)", dir)
	}
	f, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE|os.O_APPEND|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0o644) //nolint:gosec // info/exclude, as git makes it
	if err != nil {
		return fmt.Errorf("%s: %w (a link?)", path, err)
	}
	defer f.Close() //nolint:errcheck // for the paths that only read; the write's below
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
	return errors.Join(err, f.Close())
}

// CheckBranch refuses a name git wouldn't take for a new branch (git
// check-ref-format's rules), or one that reads as an option.
func CheckBranch(name string) error {
	bad := name == "" || name == "@" || len(name) > 200 || strings.HasPrefix(name, "-") ||
		strings.HasPrefix(name, "/") || strings.HasSuffix(name, "/") || strings.HasSuffix(name, ".") ||
		strings.Contains(name, "..") || strings.Contains(name, "//") || strings.Contains(name, "@{") ||
		strings.ContainsAny(name, " ~^:?*[\\\x7f")
	for _, r := range name {
		bad = bad || r < ' '
	}
	for part := range strings.SplitSeq(name, "/") {
		bad = bad || strings.HasPrefix(part, ".") || strings.HasSuffix(part, ".lock")
	}
	if bad {
		return fmt.Errorf("%q isn't a name git takes for a branch", name)
	}
	return nil
}

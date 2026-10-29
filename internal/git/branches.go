package git

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// List lists folder's repository's worktrees, the main one first, without
// those git would prune (their folders are gone) or a bare repository's
// entry. The one folder is in is Current.
func (Worktrees) List(ctx context.Context, folder string) ([]model.WorktreeEntry, error) {
	out, err := run(ctx, folder, "worktree", "list", "--porcelain", "-z")
	if err != nil {
		return nil, fmt.Errorf("%s is %w", folder, ErrNotRepository)
	}
	var list []model.WorktreeEntry
	var e model.WorktreeEntry
	skip := false
	for _, field := range append(split(out), "") { // an empty field ends each entry
		key, value, _ := strings.Cut(field, " ")
		switch key {
		case "worktree":
			e = model.WorktreeEntry{Path: value, Main: len(list) == 0 && !skip}
		case "HEAD":
			e.Head = value
		case "branch":
			e.Branch = strings.TrimPrefix(value, "refs/heads/")
		case "locked":
			e.Locked = true
		case "prunable", "bare":
			skip = true
		case "":
			if e.Path != "" && !skip {
				list = append(list, e)
			}
			e, skip = model.WorktreeEntry{}, false
		}
	}
	if top := checkout(list, folder); top >= 0 {
		list[top].Current = true
	}
	return list, nil
}

// checkout is the index of the worktree in list that folder is in: the
// deepest that holds it (a worktree inside the repository's folder is
// its own checkout), or -1.
func checkout(list []model.WorktreeEntry, folder string) int {
	here, at := RealPath(folder), -1
	for i, e := range list {
		if within(here, RealPath(e.Path)) && (at < 0 || len(e.Path) > len(list[at].Path)) {
			at = i
		}
	}
	return at
}

// within says whether folder is dir or a folder in it.
func within(folder, dir string) bool {
	rel, err := filepath.Rel(dir, folder)
	return err == nil && filepath.IsLocal(rel)
}

// Same says whether two folders are in the same checkout of a repository:
// the same worktree, not one inside the other's folder.
func Same(list []model.WorktreeEntry, a, b string) bool {
	i := checkout(list, a)
	return i >= 0 && i == checkout(list, b)
}

// Found returns the worktree folder is in, as a chat's that was there
// already, when it isn't its repository's own folder; nil otherwise
// (outside git too).
func (w Worktrees) Found(ctx context.Context, folder string) *model.Worktree {
	list, err := w.List(ctx, folder)
	if err != nil {
		return nil
	}
	i := checkout(list, folder)
	if i <= 0 || !list[0].Main {
		return nil // the main worktree, or none
	}
	e := list[i]
	path := e.Path // git's, links resolved; the folder's spelling if it has the same end
	if rel, err := filepath.Rel(e.Path, RealPath(folder)); err == nil {
		top := filepath.Clean(folder)
		if rel == "." {
			path = top
		} else if p, ok := strings.CutSuffix(top, "/"+rel); ok {
			path = p
		}
	}
	return &model.Worktree{Repo: list[0].Path, Path: path, Branch: e.Branch, Base: DefaultBase(ctx, folder),
		BaseCommit: e.Head, Told: e.Branch, Found: true}
}

// Branches lists folder's repository's local branches, the newest commit
// first, limit at most, each with the worktree that has it checked out.
func Branches(ctx context.Context, folder string, limit int) ([]model.Branch, error) {
	out, err := run(ctx, folder, "for-each-ref", "--sort=-committerdate", "--count="+strconv.Itoa(limit),
		"--format=%(refname)%00%(committerdate:unix)%00%(worktreepath)", "refs/heads")
	if err != nil {
		return nil, fmt.Errorf("%s is %w", folder, ErrNotRepository)
	}
	var list []model.Branch
	for line := range strings.Lines(string(out)) {
		f := strings.Split(strings.TrimSuffix(line, "\n"), "\x00")
		if len(f) != 3 {
			continue
		}
		at, _ := strconv.ParseInt(f[1], 10, 64)
		list = append(list, model.Branch{Name: strings.TrimPrefix(f[0], "refs/heads/"), Time: at, Worktree: f[2]})
	}
	return list, nil
}

// Changes lists folder's first n uncommitted changes, untracked files
// included, as git status --short says each ("M a.go", "?? b.txt").
func (Worktrees) Changes(ctx context.Context, folder string, n int) ([]string, error) {
	out, err := run(ctx, folder, "status", "--porcelain", "-z", "--untracked-files=all", "--ignore-submodules=dirty")
	if err != nil {
		return nil, err
	}
	var list []string
	fields := split(out)
	for i := 0; i < len(fields) && len(list) < n; i++ {
		f := fields[i]
		if len(f) <= 3 {
			continue
		}
		list = append(list, strings.TrimSpace(f[:2])+" "+f[3:])
		if f[0] == 'R' || f[0] == 'C' {
			i++
		}
	}
	return list, nil
}

// Changed counts folder's checkout's uncommitted changes to tracked files
// (staged or not); untracked files go along with a switch.
func (Worktrees) Changed(ctx context.Context, folder string) (int, error) {
	out, err := run(ctx, folder, "status", "--porcelain", "-z", "--untracked-files=no", "--ignore-submodules=dirty")
	if err != nil {
		return 0, err
	}
	n, fields := 0, split(out)
	for i := 0; i < len(fields); i++ {
		if f := fields[i]; len(f) > 3 {
			n++
			if f[0] == 'R' || f[0] == 'C' { // its old path follows, as a field of its own
				i++
			}
		}
	}
	return n, nil
}

// Branch is the branch folder has checked out; "" when HEAD is detached
// or it isn't in a repository.
func (Worktrees) Branch(ctx context.Context, folder string) string {
	b, _ := Head(ctx, folder)
	return b
}

// Switch checks out branch in folder's checkout (git switch), or a new
// branch of that name from HEAD with create. Only a local branch: no
// guessing a remote's. A branch that isn't there fails with
// fs.ErrNotExist, a new one whose name is taken with fs.ErrExist.
func (w Worktrees) Switch(ctx context.Context, folder, branch string, create bool) error {
	if err := w.CheckBranch(ctx, folder, branch); err != nil {
		return err
	}
	_, err := run(ctx, folder, "rev-parse", "--verify", "-q", "refs/heads/"+branch)
	switch {
	case create && err == nil:
		return fmt.Errorf("a branch named %s: %w", branch, fs.ErrExist)
	case !create && err != nil:
		return fmt.Errorf("no branch named %s: %w", branch, fs.ErrNotExist)
	}
	args := []string{"switch", "-q", "--no-guess", branch}
	if create {
		args = []string{"switch", "-q", "-c", branch}
	}
	if _, err := run(ctx, folder, args...); err != nil {
		msg := err.Error()
		if i := strings.Index(msg, "error: "); i >= 0 {
			msg = msg[i+len("error: "):]
		}
		msg, _, _ = strings.Cut(msg, "\n")
		return errors.New("git couldn't switch to " + branch + ": " + msg)
	}
	return nil
}

package git

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"unicode/utf8"

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
	// git gives the main worktree first, a bare repository's entry in its place.
	skip, first := false, true
	for _, field := range append(split(out), "") { // an empty field ends each entry
		key, value, _ := strings.Cut(field, " ")
		switch key {
		case "worktree":
			e, first = model.WorktreeEntry{Path: value, Main: first}, false
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
// (outside git too), and for one whose path or branch isn't valid UTF-8:
// git takes any bytes, and a chat's worktree goes to its clients by name.
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
	if !utf8.ValidString(list[0].Path) || !utf8.ValidString(path) || !utf8.ValidString(e.Branch) {
		return nil
	}
	base := DefaultBase(ctx, folder)
	if !utf8.ValidString(base) {
		base = ""
	}
	return &model.Worktree{Repo: list[0].Path, Path: path, Branch: e.Branch, Base: base,
		BaseCommit: e.Head, Told: e.Branch, Found: true}
}

// Locate says where folder is in git: its repository's common folder and
// the top of its work tree, both real paths. A folder whose .git is gone
// answers for the repository around it, if any, so what git lists as a
// worktree is only one when top is that folder.
func (Worktrees) Locate(ctx context.Context, folder string) (common, top string, err error) {
	out, err := run(ctx, folder, "rev-parse", "--path-format=absolute", "--git-common-dir", "--show-toplevel")
	if err != nil {
		return "", "", fmt.Errorf("%s is %w", folder, ErrNotRepository)
	}
	lines := strings.Split(strings.TrimSuffix(string(out), "\n"), "\n")
	if len(lines) != 2 { // a path with a newline in it: not one to read on
		return "", "", fmt.Errorf("%s: can't read where git says it is", folder)
	}
	return RealPath(lines[0]), RealPath(lines[1]), nil
}

// MergeBase is the latest commit where head left any of from, in folder's
// repository: git's best common ancestor of head and a merge of from.
// All must be object ids: they may come from a worktree's HEAD, which an
// agent can write.
func (Worktrees) MergeBase(ctx context.Context, folder, head string, from ...string) (string, error) {
	if !ObjectID(head) || len(from) == 0 || slices.ContainsFunc(from, func(s string) bool { return !ObjectID(s) }) {
		return "", fmt.Errorf("%q and %q aren't all commits", head, from)
	}
	out, err := run(ctx, folder, append([]string{"merge-base", head}, from...)...)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}

// DefaultTips are the commits the repository's default branch and its
// other copy (bases) are at, none if it has no default branch. An agent's
// worktree often starts there, not from the branch the chat's folder has
// out, which can be an old one.
func (Worktrees) DefaultTips(ctx context.Context, folder string) []string {
	base := DefaultBase(ctx, folder)
	if base == "" || strings.HasPrefix(base, "-") {
		return nil
	}
	var tips []string
	for _, ref := range bases(ctx, folder, base) {
		if tip, err := verify(ctx, folder, ref+"^{commit}"); err == nil && !slices.Contains(tips, tip) {
			tips = append(tips, tip)
		}
	}
	return tips
}

// Merged returns those of tips (object ids) git shows on HEAD or base (""
// for the repository's default branch) or its other copy (bases), at a
// few runs of git however many
// there are. A tip git no longer has isn't among them: reachable from
// nothing is not the same as on the branch.
func (Worktrees) Merged(ctx context.Context, folder, base string, tips []string) ([]string, error) {
	if len(tips) == 0 {
		return nil, nil
	}
	if i := slices.IndexFunc(tips, func(s string) bool { return !ObjectID(s) }); i >= 0 {
		return nil, fmt.Errorf("%q is not a commit", tips[i])
	}
	out, err := run(ctx, folder, append([]string{"rev-list", "--no-walk", "--ignore-missing"}, tips...)...)
	if err != nil {
		return nil, err
	}
	there := strings.Fields(string(out))
	if len(there) == 0 {
		return nil, nil
	}
	into := []string{"HEAD"}
	if b := cmp.Or(base, DefaultBase(ctx, folder)); b != "" && !strings.HasPrefix(b, "-") {
		into = append(into, bases(ctx, folder, b)...)
	}
	args := append(append([]string{"rev-list", "--ignore-missing"}, there...), "--not")
	if out, err = run(ctx, folder, append(append(args, into...), "--")...); err != nil {
		return nil, err
	}
	left := strings.Fields(string(out))
	return slices.DeleteFunc(there, func(tip string) bool { return slices.Contains(left, tip) }), nil
}

// hasBranch says repo has a local branch named name.
func hasBranch(ctx context.Context, repo, name string) bool {
	_, err := verify(ctx, repo, "refs/heads/"+name)
	return err == nil
}

// verify is the object id rev names in folder's repository (git rev-parse
// --verify); an error when it names none.
func verify(ctx context.Context, folder, rev string) (string, error) {
	out, err := run(ctx, folder, "rev-parse", "--verify", "-q", rev)
	return strings.TrimSpace(string(out)), err
}

// ObjectID says s is a whole object id, SHA-1's or SHA-256's.
func ObjectID(s string) bool {
	if len(s) != 40 && len(s) != 64 {
		return false
	}
	return strings.IndexFunc(s, func(r rune) bool { return (r < '0' || r > '9') && (r < 'a' || r > 'f') }) < 0
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

// statusEntries are folder's uncommitted changes as git status
// --porcelain gives each ("XY path"), untracked files with untracked. A
// rename's or copy's old path, a field of its own, isn't one; nor is what
// changed inside a submodule, where git would run a status (ADR 0023).
func statusEntries(ctx context.Context, folder string, untracked bool) ([]string, error) {
	files := "--untracked-files=no"
	if untracked {
		files = "--untracked-files=all"
	}
	out, err := run(ctx, folder, "status", "--porcelain", "-z", files, "--ignore-submodules=dirty")
	if err != nil {
		return nil, err
	}
	var list []string
	fields := split(out)
	for i := 0; i < len(fields); i++ {
		if f := fields[i]; len(f) > 3 {
			list = append(list, f)
			if f[0] == 'R' || f[0] == 'C' {
				i++
			}
		}
	}
	return list, nil
}

// Changes lists the first n of what removing the worktree at folder would
// lose (removalEntries).
func (Worktrees) Changes(ctx context.Context, folder string, n int) ([]string, error) {
	list, err := removalEntries(ctx, folder)
	return list[:min(n, len(list))], err
}

// removalEntries are what removing the worktree at folder would lose: its
// uncommitted changes, untracked files included, as git status --short
// says each ("M a.go", "?? b.txt"), and each checked-out submodule
// ("submodule vendor/lib"). The status stays out of submodules (ADR
// 0023), so it can't tell whether one holds work; git worktree remove
// takes force for any checked-out one, and these count it as a change.
func removalEntries(ctx context.Context, folder string) ([]string, error) {
	entries, err := statusEntries(ctx, folder, true)
	if err != nil {
		return nil, err
	}
	list := make([]string, 0, len(entries))
	listed := map[string]bool{}
	for _, f := range entries {
		list = append(list, strings.TrimSpace(f[:2])+" "+f[3:])
		listed[f[3:]] = true
	}
	out, err := run(ctx, folder, "ls-files", "-z", "--stage")
	if err != nil {
		return nil, err
	}
	for _, f := range split(out) { // "160000 <commit> <stage>\t<path>" for a submodule
		meta, path, _ := strings.Cut(f, "\t")
		if !strings.HasPrefix(meta, "160000 ") || listed[path] {
			continue
		}
		if _, err := os.Lstat(filepath.Join(folder, path, ".git")); err == nil {
			list = append(list, "submodule "+path)
			listed[path] = true
		}
	}
	return list, nil
}

// Changed counts folder's checkout's uncommitted changes to tracked files
// (staged or not); untracked files go along with a switch.
func (Worktrees) Changed(ctx context.Context, folder string) (int, error) {
	entries, err := statusEntries(ctx, folder, false)
	return len(entries), err
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
	switch has := hasBranch(ctx, folder, branch); {
	case create && has:
		return fmt.Errorf("a branch named %s: %w", branch, fs.ErrExist)
	case !create && !has:
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

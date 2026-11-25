// Package git reads a folder's changes with the git command.
package git

import (
	"bytes"
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

	"github.com/afrase/nushi/internal/model"
)

const (
	maxText  = 1 << 20  // the largest text shown in a diff, per side
	maxTotal = 32 << 20 // the text one Changes reads, past which files are left out
	gitlink  = "160000" // the mode git gives a submodule
)

// Span says which changes Changes reads: the uncommitted ones, counted
// from HEAD or, with Base, from where HEAD's branch left Base (their merge
// base), so the branch's commits too; or with Commit what that commit
// changed, with Since as well what the commits from Since to Commit changed,
// and with After instead what changed after After, up to Commit. With Path,
// only that file's change (its path relative to the folder; a rename's new
// path), and of the work tree's, a link or a file git doesn't track is
// skipped, so no answer means tracked and unchanged.
type Span struct{ Base, Commit, Since, After, Path string }

// Changes returns the folder's changes in span, untracked files included
// when they are uncommitted ones, with paths relative to the folder and
// each file's lines added and removed, and uncommitted ones say how much is
// staged. The folder may be anywhere inside a repository.
func Changes(ctx context.Context, folder string, span Span) ([]model.FileChange, error) { //nolint:gocognit // the span, its counts, then one pass reading the texts
	if span.Path != "" && !filepath.IsLocal(span.Path) {
		return nil, fmt.Errorf("%q is not a path inside the folder", span.Path)
	}
	from, to, err := ends(ctx, folder, span)
	if err != nil {
		return nil, err
	}
	changes, err := listed(ctx, folder, nil, from, to)
	if err != nil {
		return nil, err
	}
	if from != "" {
		revs := []string{from}
		if to != "" {
			revs = append(revs, to)
		}
		counts, err := numstat(ctx, folder, nil, revs...)
		if err != nil {
			return nil, err
		}
		for i := range changes { // an untracked file counts none here
			n := counts[changes[i].Path]
			changes[i].Added, changes[i].Removed = n[0], n[1]
		}
	}
	if span.Path != "" {
		changes = slices.DeleteFunc(changes, func(c model.FileChange) bool { return c.Path != span.Path })
		if to == "" {
			if changes, err = onePath(ctx, folder, span.Path, changes); err != nil {
				return nil, err
			}
		}
	}

	slices.SortFunc(changes, func(a, b model.FileChange) int { return strings.Compare(a.Path, b.Path) })
	files := openBlobs(folder)
	defer files.close()
	total := 0
	for i := range changes {
		c := &changes[i]
		if c.Skipped != "" {
			continue
		}
		if total > maxTotal {
			c.Skipped = "past what one view of changes loads"
			continue
		}
		var old, cur []byte
		if c.Status != "added" && c.Status != "untracked" {
			old, err = files.read(ctx, from, cmp.Or(c.OldPath, c.Path))
		}
		switch {
		case err != nil || c.Status == "deleted":
		case to != "":
			cur, err = files.read(ctx, to, c.Path)
		default:
			cur, err = worktree(filepath.Join(folder, c.Path))
		}
		switch {
		case err != nil: // one file that can't be read doesn't stop the rest
			c.Skipped, err = "unreadable", nil
		case bytes.IndexByte(old, 0) >= 0 || bytes.IndexByte(cur, 0) >= 0:
			c.Skipped = "binary"
		case len(old) > maxText || len(cur) > maxText:
			c.Skipped = "too large"
		default:
			c.Old, c.New = string(old), string(cur)
			total += len(old) + len(cur)
			if c.Status == "added" || c.Status == "untracked" {
				c.Added = lines(cur)
			}
		}
	}
	if span == (Span{}) {
		staged, unstaged, err := indexEntries(ctx, folder)
		if err != nil {
			return nil, err
		}
		markStaged(changes, staged, unstaged)
		if err := markHunks(ctx, folder, changes, staged, unstaged); err != nil {
			return nil, err
		}
	}
	return changes, nil
}

// onePath finishes Changes' answer for the work tree's file rel, changes
// being its entry or none: a symlink is skipped (worktree reads its target's
// path, not what it points at), and a file git doesn't track (an ignored
// one, or one outside this repository) is untracked and skipped, so that
// no entry at all means tracked and unchanged.
func onePath(ctx context.Context, folder, rel string, changes []model.FileChange) ([]model.FileChange, error) {
	if fi, err := os.Lstat(filepath.Join(folder, rel)); err == nil && fi.Mode()&os.ModeSymlink != 0 {
		if len(changes) == 0 {
			return []model.FileChange{{Path: rel, Status: "modified", Skipped: "a link"}}, nil
		}
		changes[0].Skipped = "a link"
		return changes, nil
	}
	if len(changes) > 0 {
		return changes, nil
	}
	out, err := run(ctx, folder, "ls-files", "-z", "--", ":(literal)"+rel)
	if err != nil {
		return nil, err
	}
	if len(out) == 0 {
		return []model.FileChange{{Path: rel, Status: "untracked", Skipped: "not tracked"}}, nil
	}
	return nil, nil
}

// numstat returns the lines added and removed per file (by its new path)
// between revs (a commit and the work tree, or two commits), as git diff
// counts them; a binary file counts none.
func numstat(ctx context.Context, folder string, blank []string, revs ...string) (map[string][2]int, error) {
	// Without --ignore-submodules=dirty, git runs a status in each
	// submodule, which runs the submodule's own filters.
	out, err := runTo(ctx, folder, blank, nil, append(append([]string{"diff"}, revs...), "--numstat", "-z", "-M", "--relative", "--ignore-submodules=dirty", "--no-ext-diff", "--no-textconv")...)
	if err != nil {
		return nil, err
	}
	counts := map[string][2]int{}
	fields := split(out)
	for i := 0; i < len(fields); i++ { // added, removed ("-" if binary), path
		added, rest, _ := strings.Cut(fields[i], "\t")
		removed, path, _ := strings.Cut(rest, "\t")
		if path == "" && i+2 < len(fields) { // renamed: the old path, the new one
			path = fields[i+2]
			i += 2
		}
		a, _ := strconv.Atoi(added)
		r, _ := strconv.Atoi(removed)
		counts[path] = [2]int{a, r}
	}
	return counts, nil
}

// lines counts a text's lines, a last one without a newline included.
func lines(b []byte) int {
	n := bytes.Count(b, []byte("\n"))
	if len(b) > 0 && b[len(b)-1] != '\n' {
		n++
	}
	return n
}

var (
	// ErrNotRepository says a folder isn't in a git repository.
	ErrNotRepository = errors.New("not in a git repository")
	// ErrGone says a folder doesn't exist (any more).
	ErrGone = errors.New("gone")
)

// repo checks that folder is in a git repository, and says whether it has
// a commit checked out.
func repo(ctx context.Context, folder string) (hasHead bool, err error) {
	if _, err := os.Stat(folder); errors.Is(err, fs.ErrNotExist) {
		return false, fmt.Errorf("%s is %w", folder, ErrGone)
	}
	if _, err := run(ctx, folder, "rev-parse", "--show-toplevel"); err != nil {
		return false, fmt.Errorf("%s is %w", folder, ErrNotRepository)
	}
	_, err = verify(ctx, folder, "HEAD")
	return err == nil, nil
}

// start returns the commit changes are counted from: HEAD, or with base
// where HEAD left base or its other copy (bases), the later of the two;
// "" before the first commit.
func start(ctx context.Context, folder, base string) (string, error) {
	hasHead, err := repo(ctx, folder)
	switch {
	case err != nil || !hasHead:
		return "", err
	case base == "":
		return "HEAD", nil
	case strings.HasPrefix(base, "-"):
		return "", fmt.Errorf("%q is not a branch", base)
	}
	// With more than two commits, git takes the best common ancestor of
	// HEAD and a merge of the rest.
	out, err := run(ctx, folder, append([]string{"merge-base", "HEAD"}, bases(ctx, folder, base)...)...)
	return strings.TrimSpace(string(out)), err
}

// ends returns the commits span's changes go from and to; to is "" for the
// work tree, and from is "" before the first commit.
func ends(ctx context.Context, folder string, span Span) (from, to string, err error) {
	if span.Commit == "" {
		from, err = start(ctx, folder, span.Base)
		return from, "", err
	}
	if _, err := repo(ctx, folder); err != nil {
		return "", "", err
	}
	since := cmp.Or(span.After, span.Since, span.Commit)
	if strings.HasPrefix(since, "-") || strings.HasPrefix(span.Commit, "-") {
		return "", "", fmt.Errorf("%q is not a commit", since)
	}
	if span.After != "" {
		return span.After, span.Commit, nil
	}
	from = since + "^"
	if _, err := verify(ctx, folder, from); err != nil {
		// The first commit: from nothing.
		out, err := run(ctx, folder, "hash-object", "-t", "tree", "/dev/null")
		if err != nil {
			return "", "", err
		}
		from = strings.TrimSpace(string(out))
	}
	return from, span.Commit, nil
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

// Status sums up the folder's changes as Changes lists them (the files,
// and the lines added and removed; binary and over-large files count no
// lines), and names the branch checked out, or the commit when none is.
// It runs on its own (the panel's card), so without the repository's own
// filters.
func Status(ctx context.Context, folder, base string) (model.FolderStatus, error) {
	var st model.FolderStatus
	from, err := start(ctx, folder, base)
	if err != nil {
		return st, err
	}
	if out, err := run(ctx, folder, "symbolic-ref", "--short", "-q", "HEAD"); err == nil {
		st.Branch = strings.TrimSpace(string(out))
	} else if out, err := run(ctx, folder, "rev-parse", "--short", "HEAD"); err == nil {
		st.Branch = strings.TrimSpace(string(out))
	}
	err = count(ctx, folder, from, &st)
	return st, err
}

// count adds folder's changes since from to st: tracked ones, from "" before
// the first commit, and untracked ones.
func count(ctx context.Context, folder, from string, st *model.FolderStatus) error {
	hasHead := from != ""
	if hasHead {
		off, err := noFilters(ctx, folder)
		if err != nil {
			return err
		}
		counts, err := numstat(ctx, folder, off, from)
		if err != nil {
			return err
		}
		add(st, counts)
	}
	added, err := untracked(ctx, folder, hasHead)
	if err != nil {
		return err
	}
	for _, p := range added {
		st.Files++
		if b, err := worktree(filepath.Join(folder, p)); err == nil && len(b) <= maxText && bytes.IndexByte(b, 0) < 0 {
			st.Added += lines(b)
		}
	}
	return nil
}

// add adds numstat's counts to st.
func add(st *model.FolderStatus, counts map[string][2]int) {
	for _, n := range counts {
		st.Files, st.Added, st.Removed = st.Files+1, st.Added+n[0], st.Removed+n[1]
	}
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

// Ignored says whether git ignores path (relative to folder); false
// outside git.
func Ignored(ctx context.Context, folder, path string) bool {
	_, err := run(ctx, folder, "check-ignore", "-q", "--", path)
	return err == nil
}

// IgnoredOf says which of paths (relative to folder, a folder's ending in
// "/" so a pattern for folders alone matches it) git ignores, in one run:
// none outside git, or when git can't say. A tracked file is never
// ignored, as git sees it.
func IgnoredOf(ctx context.Context, folder string, paths []string) map[string]bool {
	if len(paths) == 0 {
		return nil
	}
	// check-ignore reads each line as a pathspec, and refuses the whole
	// run (exit 128) on magic such as ":!x": a name starting with ":" is
	// asked as "./" and its name, which git echoes back as given.
	// GIT_LITERAL_PATHSPECS doesn't reach check-ignore.
	asked, as := make([]string, len(paths)), map[string]string{}
	for i, p := range paths {
		asked[i] = p
		if strings.HasPrefix(p, ":") {
			asked[i] = "./" + p
			as[asked[i]] = p
		}
	}
	cmd := command(ctx, folder, nil, "check-ignore", "-z", "--stdin")
	cmd.Stdin = strings.NewReader(strings.Join(asked, "\x00") + "\x00")
	out, err := cmd.Output() // exit 1: none ignored; 128: not a repository
	if err != nil {
		return nil
	}
	ignored := map[string]bool{}
	for _, p := range split(out) {
		if named, ok := as[p]; ok {
			p = named
		}
		ignored[p] = true
	}
	return ignored
}

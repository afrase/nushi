// Package git reads a folder's changes with the git command.
package git

import (
	"bytes"
	"cmp"
	"context"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
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
// changed, and with Since as well what the commits from Since to Commit
// changed.
type Span struct{ Base, Commit, Since string }

// Changes returns the folder's changes in span, untracked files included
// when they are uncommitted ones, with paths relative to the folder and
// each file's lines added and removed. The folder may be anywhere inside a
// repository.
func Changes(ctx context.Context, folder string, span Span) ([]model.FileChange, error) {
	from, to, err := ends(ctx, folder, span)
	if err != nil {
		return nil, err
	}
	hasHead := from != ""
	revs := []string{from}
	if to != "" {
		revs = append(revs, to)
	}
	var changes []model.FileChange
	if hasHead {
		out, err := run(ctx, folder, append(append([]string{"diff"}, revs...), "--raw", "-z", "-M", "--relative", "--ignore-submodules=dirty", "--no-ext-diff", "--no-textconv")...)
		if err != nil {
			return nil, err
		}
		fields := split(out)
		for i := 0; i+1 < len(fields); i += 2 { // ":<mode> <mode> <sha> <sha> <status>", the path
			head := strings.Fields(fields[i])
			if len(head) < 5 {
				return nil, fmt.Errorf("git diff: can't read %q", fields[i])
			}
			c := model.FileChange{Path: fields[i+1], Status: "modified"}
			switch head[4][0] {
			case 'A':
				c.Status = "added"
			case 'D':
				c.Status = "deleted"
			case 'R': // R<score>, the old path, the new one
				if i+2 < len(fields) {
					c.Status, c.OldPath, c.Path = "renamed", fields[i+1], fields[i+2]
					i++
				}
			}
			if head[0] == ":"+gitlink || head[1] == gitlink {
				c.Skipped = "a submodule"
			}
			changes = append(changes, c)
		}
		counts, err := numstat(ctx, folder, nil, revs...)
		if err != nil {
			return nil, err
		}
		for i := range changes {
			n := counts[changes[i].Path]
			changes[i].Added, changes[i].Removed = n[0], n[1]
		}
	}
	var added []string
	if to == "" {
		if added, err = untracked(ctx, folder, hasHead); err != nil {
			return nil, err
		}
	}
	status := "untracked"
	if !hasHead {
		status = "added" // before the first commit, every file is new
	}
	for _, p := range added {
		c := model.FileChange{Path: p, Status: status}
		if strings.HasSuffix(p, "/") { // git lists a repository inside the folder as a folder
			c.Path, c.Skipped = strings.TrimSuffix(p, "/"), "a repository of its own"
		}
		changes = append(changes, c)
	}

	slices.SortFunc(changes, func(a, b model.FileChange) int { return strings.Compare(a.Path, b.Path) })
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
			old, err = show(ctx, folder, from, cmp.Or(c.OldPath, c.Path))
		}
		switch {
		case err != nil || c.Status == "deleted":
		case to != "":
			cur, err = show(ctx, folder, to, c.Path)
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
	return changes, nil
}

// numstat returns the lines added and removed per file (by its new path)
// between revs (a commit and the work tree, or two commits), as git diff
// counts them; a binary file counts none.
func numstat(ctx context.Context, folder string, blank []string, revs ...string) (map[string][2]int, error) {
	// Without --ignore-submodules=dirty, git runs a status in each
	// submodule, which runs the submodule's own filters.
	out, err := runWith(ctx, folder, blank, append(append([]string{"diff"}, revs...), "--numstat", "-z", "-M", "--relative", "--ignore-submodules=dirty", "--no-ext-diff", "--no-textconv")...)
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
	_, err = run(ctx, folder, "rev-parse", "--verify", "-q", "HEAD")
	return err == nil, nil
}

// start returns the commit changes are counted from: HEAD, or with base
// the merge base of HEAD and base; "" before the first commit.
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
	out, err := run(ctx, folder, "merge-base", "HEAD", base)
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
	since := cmp.Or(span.Since, span.Commit)
	if strings.HasPrefix(since, "-") || strings.HasPrefix(span.Commit, "-") {
		return "", "", fmt.Errorf("%q is not a commit", since)
	}
	from = since + "^"
	if _, err := run(ctx, folder, "rev-parse", "--verify", "-q", from); err != nil {
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
	hasHead := from != ""
	if out, err := run(ctx, folder, "symbolic-ref", "--short", "-q", "HEAD"); err == nil {
		st.Branch = strings.TrimSpace(string(out))
	} else if out, err := run(ctx, folder, "rev-parse", "--short", "HEAD"); err == nil {
		st.Branch = strings.TrimSpace(string(out))
	}
	if hasHead {
		off, err := noFilters(ctx, folder)
		if err != nil {
			return st, err
		}
		counts, err := numstat(ctx, folder, off, from)
		if err != nil {
			return st, err
		}
		for _, n := range counts {
			st.Files, st.Added, st.Removed = st.Files+1, st.Added+n[0], st.Removed+n[1]
		}
	}
	added, err := untracked(ctx, folder, hasHead)
	if err != nil {
		return st, err
	}
	for _, p := range added {
		st.Files++
		if b, err := worktree(filepath.Join(folder, p)); err == nil && len(b) <= maxText && bytes.IndexByte(b, 0) < 0 {
			st.Added += lines(b)
		}
	}
	return st, nil
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

// run runs git in dir, with hooks, fsmonitor, signature checks, external
// diff and textconv drivers, and fetching missing objects (a partial
// clone's promisor remote, whose transport the config picks) off. A folder that was downloaded rather than
// cloned brings its own .git/config, which could set any of them. Clean
// filters still run when git compares the work tree (git diff does), unless
// noFilters turns them off: Changes shows what git shows, as the user's
// own git diff would.
func run(ctx context.Context, dir string, args ...string) ([]byte, error) {
	return runWith(ctx, dir, nil, args...)
}

// runWith is run with the config settings named in blank set empty. They
// go through GIT_CONFIG_KEY_<n>, which keeps a name apart from its value
// whatever it holds ("=" too, which -c would split at).
func runWith(ctx context.Context, dir string, blank []string, args ...string) ([]byte, error) {
	return runTo(ctx, dir, blank, nil, args...)
}

// runTo is runWith with the output going to out, unless out is nil.
func runTo(ctx context.Context, dir string, blank []string, out io.Writer, args ...string) ([]byte, error) {
	global := []string{"-c", "core.fsmonitor=false", "-c", "core.hooksPath=/dev/null", "-c", "log.showSignature=false", "-C", dir}
	cmd := exec.CommandContext(ctx, "git", append(global, args...)...)
	cmd.Env = append(os.Environ(), "GIT_OPTIONAL_LOCKS=0", "GIT_NO_LAZY_FETCH=1", "GIT_CONFIG_COUNT="+strconv.Itoa(len(blank)))
	for i, name := range blank {
		cmd.Env = append(cmd.Env, fmt.Sprintf("GIT_CONFIG_KEY_%d=%s", i, name), fmt.Sprintf("GIT_CONFIG_VALUE_%d=", i))
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = cmp.Or[io.Writer](out, &stdout), &stderr
	if err := cmd.Run(); err != nil {
		var exit *exec.ExitError
		if errors.As(err, &exit) {
			return nil, fmt.Errorf("git %s: %s", args[0], strings.TrimSpace(stderr.String()))
		}
		return nil, err
	}
	return stdout.Bytes(), nil
}

// noFilters returns the config settings to blank that turn off the filter
// drivers a repository's own config defines (filter.<name>.clean, .smudge
// and .process, by the exact names git lists), for the git runs Nushi
// starts on its own. The user's (git-lfs, in the global config) stay. When git
// can't list them, it fails: nothing runs with them on.
func noFilters(ctx context.Context, dir string) ([]string, error) {
	cmd := exec.CommandContext(ctx, "git", "-c", "core.fsmonitor=false", "-c", "core.hooksPath=/dev/null", "-C", dir,
		"config", "--show-scope", "--name-only", "--get-regexp", `^filter\.`)
	cmd.Env = append(os.Environ(), "GIT_NO_LAZY_FETCH=1")
	out, err := cmd.Output()
	var exit *exec.ExitError
	if errors.As(err, &exit) && exit.ExitCode() == 1 && len(exit.Stderr) == 0 {
		return nil, nil // none
	}
	if err != nil {
		return nil, fmt.Errorf("listing the repository's filters: %w", err)
	}
	var config []string
	for line := range strings.Lines(string(out)) {
		scope, name, _ := strings.Cut(strings.TrimSpace(line), "\t")
		key := name[strings.LastIndex(name, ".")+1:]
		if scope != "global" && scope != "system" && (key == "clean" || key == "smudge" || key == "process") {
			config = append(config, name)
		}
	}
	return config, nil
}

// split splits git's NUL-separated output.
func split(out []byte) []string {
	s := strings.TrimSuffix(string(out), "\x00")
	if s == "" {
		return nil
	}
	return strings.Split(s, "\x00")
}

// Ignored says whether git ignores path (relative to folder); false
// outside git.
func Ignored(ctx context.Context, folder, path string) bool {
	_, err := run(ctx, folder, "check-ignore", "-q", "--", path)
	return err == nil
}

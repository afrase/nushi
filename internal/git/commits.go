package git

import (
	"context"
	"fmt"
	"strconv"
	"strings"
)

// Commit is one commit of a branch: its hash, subject, time (Unix
// seconds) and the lines it added and removed.
type Commit struct {
	Hash, Short, Subject string
	Time                 int64
	Added, Removed       int
}

// DefaultBase names the branch a branch is counted from: the remote's
// default (origin/HEAD), else main or master; "" when there's none.
func DefaultBase(ctx context.Context, folder string) string {
	if out, err := run(ctx, folder, "symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD"); err == nil {
		return strings.TrimSpace(string(out))
	}
	for _, b := range []string{"main", "master"} {
		if _, err := run(ctx, folder, "rev-parse", "--verify", "-q", "refs/heads/"+b); err == nil {
			return b
		}
	}
	return ""
}

// Ahead counts the commits HEAD has that base doesn't.
func Ahead(ctx context.Context, folder, base string) (int, error) {
	if strings.HasPrefix(base, "-") {
		return 0, fmt.Errorf("%q is not a branch", base)
	}
	out, err := run(ctx, folder, "rev-list", "--count", base+"..HEAD")
	if err != nil {
		return 0, err
	}
	return strconv.Atoi(strings.TrimSpace(string(out)))
}

// Commits lists HEAD's commits that base doesn't have, newest first, or
// without a base the last limit commits; the lines they changed are counted
// in the folder only.
func Commits(ctx context.Context, folder, base string, limit int) ([]Commit, error) {
	if strings.HasPrefix(base, "-") {
		return nil, fmt.Errorf("%q is not a branch", base)
	}
	rev := "HEAD"
	if base != "" {
		rev = base + "..HEAD"
	}
	// With -z, a NUL ends each commit's line and each of its numstat lines
	// (added, removed, path). A commit's line is \x1e and its fields split
	// by \x1f, the subject last: a subject can hold those, never a NUL.
	out, err := run(ctx, folder, "log", "-z", "-n", strconv.Itoa(limit), "--no-renames", "--numstat", "--relative", "--no-ext-diff", "--no-textconv",
		"--format=%x1e%H%x1f%h%x1f%ct%x1f%s", rev, "--")
	if err != nil {
		return nil, err
	}
	var commits []Commit
	for rec := range strings.SplitSeq(string(out), "\x00") {
		if head, ok := strings.CutPrefix(rec, "\x1e"); ok {
			f := strings.SplitN(head, "\x1f", 4)
			if len(f) < 4 {
				return nil, fmt.Errorf("git log: a commit line of %d fields", len(f))
			}
			c := Commit{Hash: f[0], Short: f[1], Subject: f[3]}
			c.Time, _ = strconv.ParseInt(f[2], 10, 64)
			commits = append(commits, c)
			continue
		}
		a, rest, ok := strings.Cut(strings.TrimPrefix(rec, "\n"), "\t")
		if !ok || len(commits) == 0 {
			continue
		}
		c := &commits[len(commits)-1]
		r, _, _ := strings.Cut(rest, "\t")
		n, _ := strconv.Atoi(a) // "-" for binary files
		m, _ := strconv.Atoi(r)
		c.Added, c.Removed = c.Added+n, c.Removed+m
	}
	return commits, nil
}

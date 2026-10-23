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
	// A record per commit: \x1e, the fields split by \x1f, then its
	// numstat lines (added, removed, path).
	out, err := run(ctx, folder, "log", "-n", strconv.Itoa(limit), "--no-renames", "--numstat", "--relative", "--no-ext-diff", "--no-textconv",
		"--format=%x1e%H%x1f%h%x1f%ct%x1f%s", rev, "--")
	if err != nil {
		return nil, err
	}
	var commits []Commit
	for _, rec := range strings.Split(string(out), "\x1e")[1:] {
		head, stats, _ := strings.Cut(rec, "\n")
		f := strings.SplitN(head, "\x1f", 4)
		if len(f) < 4 {
			continue
		}
		c := Commit{Hash: f[0], Short: f[1], Subject: f[3]}
		c.Time, _ = strconv.ParseInt(f[2], 10, 64)
		for _, line := range strings.Split(stats, "\n") {
			a, rest, ok := strings.Cut(line, "\t")
			if !ok {
				continue
			}
			r, _, _ := strings.Cut(rest, "\t")
			n, _ := strconv.Atoi(a) // "-" for binary files
			m, _ := strconv.Atoi(r)
			c.Added, c.Removed = c.Added+n, c.Removed+m
		}
		commits = append(commits, c)
	}
	return commits, nil
}

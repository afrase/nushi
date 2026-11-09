package git

import (
	"cmp"
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
		if hasBranch(ctx, folder, b) {
			return b
		}
	}
	return ""
}

// bases is base with its other copy, if it's a branch with one: a local
// branch's upstream, or the local branch a remote one is the upstream of.
// Either can be ahead (a fetch, a pull in another folder), and a branch
// rebased onto the newer one left it there, not where it left the older:
// counting from the older one takes in every commit between the two.
// Only the branch of the same name pairs with a remote one: an agent's
// worktree made from origin/main tracks it too, and taking that branch
// would count its work from its own head. It is one run of git on the
// status's path; a commit or a tag pairs with nothing.
func bases(ctx context.Context, folder, base string) []string {
	out, err := run(ctx, folder, "for-each-ref", "--format=%(refname)%00%(upstream)", "refs/heads", "refs/remotes")
	if err != nil {
		return []string{base}
	}
	upstream := map[string]string{} // every branch, local and remote, by ref
	for line := range strings.SplitSeq(strings.TrimSpace(string(out)), "\n") {
		ref, up, _ := strings.Cut(line, "\x00")
		upstream[ref] = up
	}
	ref := ""
	for _, r := range []string{base, "refs/heads/" + base, "refs/remotes/" + base} {
		if _, ok := upstream[r]; ok {
			ref = r
			break
		}
	}
	other := ""
	if strings.HasPrefix(ref, "refs/heads/") {
		other = upstream[ref]
	} else if rest, ok := strings.CutPrefix(ref, "refs/remotes/"); ok {
		if _, name, ok := strings.Cut(rest, "/"); ok && upstream["refs/heads/"+name] == ref {
			other = "refs/heads/" + name
		}
	}
	if _, ok := upstream[other]; other == "" || !ok { // an upstream can be gone
		return []string{base}
	}
	return []string{base, other}
}

// Ahead counts the commits head ("" for HEAD) has that base doesn't.
func Ahead(ctx context.Context, folder, base, head string) (int, error) {
	if strings.HasPrefix(base, "-") {
		return 0, fmt.Errorf("%q is not a branch", base)
	}
	if strings.HasPrefix(head, "-") {
		return 0, fmt.Errorf("%q is not a commit", head)
	}
	args := append([]string{"rev-list", "--count", cmp.Or(head, "HEAD"), "--not"}, bases(ctx, folder, base)...)
	out, err := run(ctx, folder, append(args, "--")...)
	if err != nil {
		return 0, err
	}
	return strconv.Atoi(strings.TrimSpace(string(out)))
}

// Commits lists the commits of head ("" for HEAD) that base doesn't have,
// newest first, or without a base its last limit commits; the lines they
// changed are counted in the folder only.
func Commits(ctx context.Context, folder, base, head string, limit int) ([]Commit, error) {
	if strings.HasPrefix(base, "-") {
		return nil, fmt.Errorf("%q is not a branch", base)
	}
	if strings.HasPrefix(head, "-") {
		return nil, fmt.Errorf("%q is not a commit", head)
	}
	revs := []string{cmp.Or(head, "HEAD")}
	if base != "" {
		revs = append(append(revs, "--not"), bases(ctx, folder, base)...)
	}
	// With -z, a NUL ends each commit's line and each of its numstat lines
	// (added, removed, path). A commit's line is \x1e and its fields split
	// by \x1f, the subject last: a subject can hold those, never a NUL.
	args := []string{"log", "-z", "-n", strconv.Itoa(limit), "--no-renames", "--numstat", "--relative", "--no-ext-diff", "--no-textconv",
		"--format=%x1e%H%x1f%h%x1f%ct%x1f%s"}
	out, err := run(ctx, folder, append(append(args, revs...), "--")...)
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

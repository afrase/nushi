package git

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"
)

// Remote is one of a repository's remotes: its name and the URL it
// fetches from (as git rewrites it).
type Remote struct{ Name, URL string }

// Remotes are folder's repository's remotes, read from its config (no
// network).
func Remotes(ctx context.Context, folder string) ([]Remote, error) {
	out, err := run(ctx, folder, "remote", "-v")
	if err != nil {
		return nil, err
	}
	var rs []Remote
	for line := range strings.Lines(string(out)) {
		name, rest, ok := strings.Cut(strings.TrimSpace(line), "\t")
		u, kind, _ := strings.Cut(rest, " ")
		if ok && kind == "(fetch)" {
			rs = append(rs, Remote{Name: name, URL: u})
		}
	}
	return rs, nil
}

// Fetch fetches refspec from folder's repository's remote, with no tags,
// never asking for a password on a terminal (the daemon has none: a
// remote that needs one fails), and gives up after two minutes. It runs
// the remote's transport, as the user's own git fetch would.
func Fetch(ctx context.Context, folder, remote, refspec string) error {
	if strings.HasPrefix(remote, "-") || strings.HasPrefix(refspec, "-") {
		return errors.New("a remote or refspec that reads as an option")
	}
	ctx, cancel := context.WithTimeout(ctx, 2*time.Minute)
	defer cancel()
	cmd := command(ctx, folder, nil, "fetch", "--quiet", "--no-tags", "--no-write-fetch-head", "--", remote, refspec)
	cmd.Env = append(cmd.Env, "GIT_TERMINAL_PROMPT=0", "GIT_ASKPASS=", "SSH_ASKPASS=")
	var stderr strings.Builder
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		if msg := strings.TrimSpace(stderr.String()); msg != "" {
			return fmt.Errorf("git fetch: %s", msg)
		}
		return fmt.Errorf("git fetch: %w", err)
	}
	return nil
}

// Head is the branch folder has checked out ("" when HEAD is detached or
// the folder isn't a repository) and the remote it is pushed to: its
// upstream's remote (branch.<name>.pushRemote, then remote.pushDefault,
// then branch.<name>.remote), "" when none is set.
func Head(ctx context.Context, folder string) (branch, remote string) {
	out, err := run(ctx, folder, "symbolic-ref", "--short", "-q", "HEAD")
	if err != nil {
		return "", ""
	}
	branch = strings.TrimSpace(string(out))
	for _, key := range []string{"branch." + branch + ".pushRemote", "remote.pushDefault", "branch." + branch + ".remote"} {
		if out, err := run(ctx, folder, "config", "--get", key); err == nil {
			if r := strings.TrimSpace(string(out)); r != "" && r != "." {
				return branch, r
			}
		}
	}
	return branch, ""
}

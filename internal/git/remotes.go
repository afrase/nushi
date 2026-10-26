package git

import (
	"context"
	"strings"
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

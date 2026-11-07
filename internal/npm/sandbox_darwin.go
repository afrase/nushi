package npm

import (
	"context"
	"os/exec"
	"path/filepath"
	"strconv"
)

// writingOnlyIn makes the command name args under macOS's sandbox, which
// lets it write in dir (and /dev/null) and nowhere else.
func writingOnlyIn(ctx context.Context, dir, name string, args ...string) (*exec.Cmd, error) {
	resolved, err := filepath.EvalSymlinks(dir) // what the sandbox sees
	if err != nil {
		return nil, err
	}
	profile := `(version 1)(allow default)(deny file-write* (require-not (require-any (literal "/dev/null") (subpath ` + strconv.Quote(resolved) + `))))`
	return exec.CommandContext(ctx, "/usr/bin/sandbox-exec", append([]string{"-p", profile, name}, args...)...), nil //nolint:gosec // npm ci under the sandbox, fixed arguments
}

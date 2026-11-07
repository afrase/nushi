package readonly

import (
	"context"
	"os/exec"

	"github.com/afrase/nushi/internal/procgroup"
)

const profile = `(version 1)(allow default)(deny network*)(deny file-write* (require-not (literal "/dev/null")))`

// Output runs path with args, read-only, in env (nil: the daemon's), and
// returns what it printed on stdout. What it starts goes with it when it
// overruns Timeout.
func Output(ctx context.Context, env []string, path string, args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, Timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "/usr/bin/sandbox-exec", append([]string{"-p", profile, path}, args...)...) //nolint:gosec // a found CLI's --version, under the sandbox
	cmd.Env = env
	procgroup.Bound(cmd)
	return cmd.Output()
}

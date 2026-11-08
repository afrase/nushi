package claudemcp

import (
	"context"
	"os/exec"
)

// Terminal is a command that runs argv in a terminal of its own, for a
// CLI that won't run without one: script(1)'s, keeping no typescript
// (/dev/null), passing on argv's exit status as BSD's script does. env is
// its environment, nil for the daemon's.
func Terminal(ctx context.Context, env []string, argv ...string) (*exec.Cmd, error) {
	cmd := exec.CommandContext(ctx, "/usr/bin/script", append([]string{"-q", "/dev/null"}, argv...)...) //nolint:gosec // the caller's command, as words
	cmd.Env = env
	return cmd, nil
}

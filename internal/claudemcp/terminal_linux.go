package claudemcp

import (
	"context"
	"os"
	"os/exec"
	"slices"
	"strings"
)

// Terminal is a command that runs argv in a terminal of its own, for a
// CLI that won't run without one: script(1)'s, keeping no typescript
// (/dev/null). util-linux's script takes the command only as a shell's
// line (-c), each word quoted here, which it runs with $SHELL: /bin/sh,
// so a fish or nu login shell can't read the quoting another way. -e
// passes on argv's exit status, as BSD's script does unasked. env is its
// environment, nil for the daemon's.
func Terminal(ctx context.Context, env []string, argv ...string) (*exec.Cmd, error) {
	words := make([]string, len(argv))
	for i, a := range argv {
		words[i] = shellQuote(a)
	}
	cmd := exec.CommandContext(ctx, "/usr/bin/script", "-q", "-e", "-c", strings.Join(words, " "), "/dev/null") //nolint:gosec // the caller's command, each word quoted
	if env == nil {
		env = os.Environ()
	}
	cmd.Env = append(slices.Clip(env), "SHELL=/bin/sh") // the last of a name wins
	return cmd, nil
}

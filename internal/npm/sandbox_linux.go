package npm

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
)

// ErrNoBubblewrap is why an install is refused on Linux without bwrap on
// PATH: npm runs only under bubblewrap's sandbox, and the user can install
// it.
var ErrNoBubblewrap = errors.New("setting up needs bubblewrap (bwrap), and there's none on PATH: install it from your distribution's packages")

// writingOnlyIn makes the command name args under bubblewrap, which lets it
// write in dir and nowhere else, as macOS's sandbox does (ADR 0097): every
// file is there to read, read-only (/tmp too: an empty one of its own would
// hide what the user's npm settings name there, as it hid the tests'),
// with a /dev of bubblewrap's own (/dev/null among it) and the /proc of a
// PID namespace of its own, and dir read-write. The network stays, as npm
// fetches from the registry. bwrap is first run once around true, so a
// system that won't let it make its namespaces (no unprivileged user
// namespaces, Ubuntu's AppArmor rule) gets its reason here rather than as
// npm's failure.
func writingOnlyIn(ctx context.Context, dir, name string, args ...string) (*exec.Cmd, error) {
	bwrap, err := exec.LookPath("bwrap")
	if err != nil {
		return nil, ErrNoBubblewrap
	}
	resolved, err := filepath.EvalSymlinks(dir) // what the mount namespace sees
	if err != nil {
		return nil, err
	}
	sandbox := []string{
		"--ro-bind", "/", "/",
		"--dev", "/dev",
		"--proc", "/proc",
		"--bind", resolved, resolved,
		"--unshare-pid", "--die-with-parent", "--new-session",
		"--",
	}
	if out, err := exec.CommandContext(ctx, bwrap, append(sandbox, "true")...).CombinedOutput(); err != nil { //nolint:gosec // bwrap around true, fixed arguments
		return nil, fmt.Errorf("npm's sandbox, bubblewrap, doesn't run here: %w: %s", err, strings.TrimSpace(string(out)))
	}
	return exec.CommandContext(ctx, bwrap, slices.Concat(sandbox, []string{name}, args)...), nil //nolint:gosec // npm ci under the sandbox, fixed arguments
}

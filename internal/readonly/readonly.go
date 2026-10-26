// Package readonly runs a program so that it can't change anything: under
// macOS's sandbox (sandbox-exec), with every file write but /dev/null's
// and every network connection denied. It's for asking a program what it
// is (its version, whether it's signed in) without letting it write a
// cache, a log or a setting on the way.
package readonly

import (
	"context"
	"os/exec"
	"syscall"
	"time"
)

const profile = `(version 1)(allow default)(deny network*)(deny file-write* (require-not (literal "/dev/null")))`

// Timeout bounds a run.
var Timeout = 10 * time.Second

// Output runs path with args, read-only, in env (nil: the daemon's), and
// returns what it printed on stdout. What it starts goes with it when it
// overruns Timeout.
func Output(ctx context.Context, env []string, path string, args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, Timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "/usr/bin/sandbox-exec", append([]string{"-p", profile, path}, args...)...) //nolint:gosec // a found CLI's --version, under the sandbox
	cmd.Env = env
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	cmd.WaitDelay = time.Second
	return cmd.Output()
}

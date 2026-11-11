package homebrew

import (
	"context"
	"os"
	"os/exec"
	"syscall"

	"github.com/afrase/nushi/internal/procgroup"
)

// run runs name with args in env, as the daemon's own child in a session
// of its own: no terminal to ask on, no chat's process group to end with,
// and killed with what it started when ctx ends. It returns the end of
// what the command printed (maxOutput at most).
func run(ctx context.Context, env []string, name string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...) //nolint:gosec // Upgrade's fixed arguments: a prefix's own brew, one of two cask names
	cmd.Env = env
	if home, err := os.UserHomeDir(); err == nil {
		cmd.Dir = home // not a folder inside the app brew replaces
	}
	out := &tail{max: maxOutput}
	cmd.Stdout, cmd.Stderr = out, out // one writer for both: exec writes to it from one goroutine
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	procgroup.Bound(cmd)
	err := cmd.Run()
	return out.end(), err
}

// tail keeps the end of what's written to it: its last max bytes.
type tail struct {
	buf []byte
	max int
}

func (t *tail) Write(p []byte) (int, error) {
	t.buf = append(t.buf, p...)
	if len(t.buf) > 2*t.max {
		t.buf = append(t.buf[:0], t.buf[len(t.buf)-t.max:]...)
	}
	return len(p), nil
}

func (t *tail) end() []byte { return t.buf[max(0, len(t.buf)-t.max):] }

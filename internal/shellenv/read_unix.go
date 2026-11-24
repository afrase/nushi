//go:build unix

package shellenv

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"syscall"
	"time"

	"github.com/afrase/nushi/internal/procgroup"
)

// source is what Status names the reading after: the shell it runs.
func source(shell string) string { return shell }

// Read runs shell as a login, interactive shell (stdin /dev/null, a session
// of its own, killed with what it started after timeout) and returns the
// environment it printed, without the variables a shell sets for itself
// and Nushi's own (Own), and the umask and open-files limit it then had.
// env is the shell's environment; what the shell writes to stderr is
// dropped unread.
func Read(ctx context.Context, shell string, env []string, timeout time.Duration) ([]string, Limits, error) {
	return read(ctx, shell, "-l -i", env, timeout)
}

// ReadLogin is Read of a login shell that isn't interactive (-l -c):
// zsh's .zshrc, bash's .bashrc and fish's `status is-interactive` blocks
// don't run.
func ReadLogin(ctx context.Context, shell string, env []string, timeout time.Duration) ([]string, Limits, error) {
	return read(ctx, shell, "-l", env, timeout)
}

// read is Read with flags, "-l -i" or "-l", before the -c.
func read(ctx context.Context, shell, flags string, env []string, timeout time.Duration) ([]string, Limits, error) {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	mark := make([]byte, 12)
	_, _ = rand.Read(mark)
	start, end, done := "nushi-env-start-"+hex.EncodeToString(mark), "nushi-env-end-"+hex.EncodeToString(mark), "nushi-env-done-"+hex.EncodeToString(mark)
	// The same line in fish, zsh, bash, sh, dash and ksh: the environment
	// between two marks, then the umask and the soft open-files limit, a
	// line each, before a third (parseLimits).
	line := fmt.Sprintf("printf '%%s' %s; /usr/bin/env -0; printf '%%s' %s; printf '\\n%s'; umask; printf '\\n%s'; ulimit -S -n; printf '%%s' %s",
		start, end, umaskKey, openFilesKey, done)
	args := append(strings.Fields(flags), "-c", line)
	cmd := exec.CommandContext(ctx, shell, args...) //nolint:gosec // the user's login shell, the line above
	cmd.Env = append(slices.Clone(env), Resolving+"=1")
	if home, err := os.UserHomeDir(); err == nil {
		cmd.Dir = home
	}
	out := &limited{max: maxOutput}
	cmd.Stdout = out
	procgroup.Session(cmd) // no terminal to take or wait on
	procgroup.Bound(cmd)   // something it started in the background may hold stdout
	err := cmd.Run()
	vars, perr := parse(out.Bytes(), start, end)
	switch {
	case perr == nil:
		return vars, parseLimits(out.Bytes(), end, done), nil // the end mark came: a config's exit status, or a hang after, doesn't matter
	case ctx.Err() != nil:
		return nil, Limits{}, fmt.Errorf("%s took over %s", filepath.Base(shell), timeout)
	case err != nil:
		return nil, Limits{}, fmt.Errorf("%s %s before printing its environment", filepath.Base(shell), ended(err))
	case out.over:
		return nil, Limits{}, fmt.Errorf("%s printed over %d MB", filepath.Base(shell), maxOutput>>20)
	}
	return nil, Limits{}, fmt.Errorf("%s: %w", filepath.Base(shell), perr)
}

// The keys of parseLimits' lines.
const (
	umaskKey     = "umask="
	openFilesKey = "nofile="
)

// parseLimits takes the umask and the soft open-files limit from between
// the end mark (the last, which parse took) and the done mark after it,
// as the shell printed them; "" for one that isn't there. Nothing but the
// line runs between the marks, so a config's output can't stand in for
// them.
func parseLimits(out []byte, end, done string) Limits {
	e := bytes.LastIndex(out, []byte(end))
	if e < 0 {
		return Limits{}
	}
	printed, _, ok := bytes.Cut(out[e+len(end):], []byte(done))
	if !ok {
		return Limits{}
	}
	var l Limits
	for line := range strings.Lines(string(printed)) {
		line = strings.TrimSpace(line)
		if v, ok := strings.CutPrefix(line, umaskKey); ok {
			l.Umask = v
		} else if v, ok := strings.CutPrefix(line, openFilesKey); ok {
			l.OpenFiles = v
		}
	}
	return l
}

// maxOutput bounds what the shell may print (its environment and anything
// its config prints first).
const maxOutput = 8 << 20

// ended says how a run ended: "exited with status 1", "was killed by
// signal 9", or why it couldn't start (exec's words, which name the
// program, never what it printed).
func ended(err error) string {
	if exit, ok := errors.AsType[*exec.ExitError](err); ok {
		if st, ok := exit.Sys().(syscall.WaitStatus); ok && st.Signaled() {
			return "was killed by " + st.Signal().String()
		}
		return fmt.Sprintf("exited with status %d", exit.ExitCode())
	}
	return "couldn't start (" + err.Error() + ")"
}

// parse takes the environment from between the last start mark and the
// end mark after it: what a shell's config printed first is skipped.
func parse(out []byte, start, end string) ([]string, error) {
	e := bytes.LastIndex(out, []byte(end))
	if e < 0 {
		return nil, errors.New("no environment in what it printed")
	}
	s := bytes.LastIndex(out[:e], []byte(start))
	if s < 0 {
		return nil, errors.New("no environment in what it printed")
	}
	var vars []string
	for kv := range bytes.SplitSeq(out[s+len(start):e], []byte{0}) {
		name, _, ok := bytes.Cut(kv, []byte("="))
		if !ok || len(name) == 0 || shells[string(name)] || Own(string(name)) {
			continue
		}
		vars = append(vars, string(kv))
	}
	return vars, nil
}

// kept is base without the variables a reading of the shell (vars, run
// with base) doesn't have: those its profile or rc unset. What the
// reading leaves out itself (shells, Own) isn't the shell's to unset.
func kept(base, vars []string) []string {
	has := map[string]bool{}
	for _, kv := range vars {
		name, _, _ := strings.Cut(kv, "=")
		has[name] = true
	}
	return slices.DeleteFunc(slices.Clone(base), func(kv string) bool {
		name, _, _ := strings.Cut(kv, "=")
		return !has[name] && !shells[name] && !Own(name)
	})
}

// shells are the variables each shell sets for itself (where it is, how
// deep): the shell's are the reading's, not an agent's.
var shells = map[string]bool{"_": true, "PWD": true, "OLDPWD": true, "SHLVL": true}

// limited keeps what's written, up to max bytes.
type limited struct {
	bytes.Buffer
	max  int
	over bool
}

func (l *limited) Write(p []byte) (int, error) {
	n := len(p)
	if room := l.max - l.Len(); n > room {
		l.over = true
		p = p[:max(room, 0)]
	}
	_, _ = l.Buffer.Write(p)
	return n, nil // the rest is dropped, not an error: the shell goes on to its end
}

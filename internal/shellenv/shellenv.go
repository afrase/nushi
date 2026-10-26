// Package shellenv reads the environment the user's login shell gives a
// terminal: it runs the shell as a login, interactive shell that prints
// its environment between two marks, as VS Code's "resolve shell
// environment" does. Agents start with it (ADR 0048), whatever started the
// daemon. The values are never logged or kept anywhere but in memory; the
// log has the shell, how long it took and how it ended, and the names the
// shell adds at DEBUG.
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
)

// Resolving is set in the shell's environment while it's read, so a shell
// config can skip what only a terminal wants (starting tmux, a greeting).
const Resolving = "NUSHI_RESOLVING_ENVIRONMENT"

// maxOutput bounds what the shell may print (its environment and anything
// its config prints first).
const maxOutput = 8 << 20

// Read runs shell as a login, interactive shell (stdin /dev/null, a session
// of its own, killed with what it started after timeout) and returns the
// environment it printed, without the variables a shell sets for itself
// and Nushi's own (Own). env is the shell's environment; what the shell
// writes to stderr is dropped unread.
func Read(ctx context.Context, shell string, env []string, timeout time.Duration) ([]string, error) {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	mark := make([]byte, 12)
	_, _ = rand.Read(mark)
	start, end := "nushi-env-start-"+hex.EncodeToString(mark), "nushi-env-end-"+hex.EncodeToString(mark)
	// The same line in fish, zsh, bash, sh, dash and ksh.
	line := fmt.Sprintf("printf '%%s' %s; /usr/bin/env -0; printf '%%s' %s", start, end)
	cmd := exec.CommandContext(ctx, shell, "-l", "-i", "-c", line) //nolint:gosec // the user's login shell, the line above
	cmd.Env = append(slices.Clone(env), Resolving+"=1")
	if home, err := os.UserHomeDir(); err == nil {
		cmd.Dir = home
	}
	out := &limited{max: maxOutput}
	cmd.Stdout = out
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true} // no terminal to take or wait on
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	cmd.WaitDelay = time.Second // something it started in the background may hold stdout
	err := cmd.Run()
	vars, perr := parse(out.Bytes(), start, end)
	switch {
	case perr == nil:
		return vars, nil // the end mark came: a config's exit status, or a hang after, doesn't matter
	case ctx.Err() != nil:
		return nil, fmt.Errorf("%s took over %s", filepath.Base(shell), timeout)
	case err != nil:
		return nil, fmt.Errorf("%s %s before printing its environment", filepath.Base(shell), ended(err))
	case out.over:
		return nil, fmt.Errorf("%s printed over %d MB", filepath.Base(shell), maxOutput>>20)
	}
	return nil, fmt.Errorf("%s: %w", filepath.Base(shell), perr)
}

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

// shells are the variables each shell sets for itself (where it is, how
// deep): the shell's are the reading's, not an agent's.
var shells = map[string]bool{"_": true, "PWD": true, "OLDPWD": true, "SHLVL": true}

// Own says the variable named name is Nushi's: the daemon's settings
// (NUSHI_DATA, NUSHI_LOG), what its launcher sets (NUSHID_BIN,
// NUSHID_LOG), a chat's tools server's (NUSHI_SOCKET, NUSHI_TOOLS_KEY).
// None goes to an agent.
func Own(name string) bool {
	return strings.HasPrefix(name, "NUSHI_") || strings.HasPrefix(name, "NUSHID_")
}

// Merge is base with over's variables on top (over wins), and Nushi's own
// left out. The order is base's, then what over adds.
func Merge(base, over []string) []string {
	at := map[string]int{}
	var out []string
	for _, list := range [][]string{base, over} {
		for _, kv := range list {
			name, _, _ := strings.Cut(kv, "=")
			if Own(name) {
				continue
			}
			if i, ok := at[name]; ok {
				out[i] = kv
				continue
			}
			at[name] = len(out)
			out = append(out, kv)
		}
	}
	return out
}

// LookPath finds the program name in env's PATH, as exec.LookPath does in
// the daemon's; "" when it isn't there. A name with a slash is itself.
func LookPath(name string, env []string) string {
	if strings.Contains(name, "/") {
		if program(name) {
			return name
		}
		return ""
	}
	for _, dir := range filepath.SplitList(Get(env, "PATH")) {
		if dir == "" {
			continue // the current folder, which exec.LookPath refuses too
		}
		if p := filepath.Join(dir, name); program(p) {
			return p
		}
	}
	return ""
}

func program(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.Mode().IsRegular() && st.Mode()&0o111 != 0
}

// Get is the value of the variable named name in env, the last one when
// it's there twice (as exec does); "" when it isn't.
func Get(env []string, name string) string {
	for _, kv := range slices.Backward(env) {
		if v, ok := strings.CutPrefix(kv, name+"="); ok {
			return v
		}
	}
	return ""
}

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

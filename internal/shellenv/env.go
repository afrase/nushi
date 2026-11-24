package shellenv

import (
	"context"
	"errors"
	"log/slog"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// Timeout bounds a reading.
var Timeout = 5 * time.Second

// Env is the environment agents start with: the shell's, read at start
// and again when asked, over the daemon's own (base), Nushi's own
// variables left out. Until a reading has worked it's the daemon's.
type Env struct {
	shell string
	base  []string
	off   bool // never read: agents get base (tests, NUSHI_SHELL_ENV=off)

	reading sync.Mutex             // one reading at a time
	first   chan struct{}          // closed once the first reading ended
	use     func(environ []string) // called after each reading that worked (Use)

	mu      sync.Mutex
	vars    []string  // the last reading that worked; nil before one has
	read    time.Time // when the last reading ended, worked or not
	problem string    // why it didn't, "" when it did
}

// New is the environment of shell over base (the daemon's), not read yet:
// Start reads it. On Windows there's no shell to run: the registry's
// environment is read, and Status names it Windows.
func New(shell string, base []string) *Env {
	return &Env{shell: source(shell), base: slices.Clone(base), first: make(chan struct{})}
}

// Off is base alone, never read from a shell: for a daemon whose
// environment must be exactly what started it (a test's fake agents on
// its own PATH).
func Off(base []string) *Env {
	e := New("", base)
	e.off = true
	close(e.first)
	return e
}

// Use has f called with Environ's environment after each reading that
// works, before Environ answers with it: the daemon applies it to its
// own (ADR 0048). Call it before Start.
func (e *Env) Use(f func(environ []string)) { e.use = f }

// Start reads the shell's environment in the background; Environ and
// LookPath wait for it (Timeout at most).
func (e *Env) Start() {
	if e.off {
		return
	}
	go func() {
		defer close(e.first)
		e.Refresh(context.Background(), 0)
	}()
}

// Refresh reads the shell's environment again unless the last reading
// is younger than maxAge (or one is under way: Refresh waits for it).
// A reading that fails keeps the last that worked, and says why in Status.
func (e *Env) Refresh(ctx context.Context, maxAge time.Duration) {
	if e.off {
		return
	}
	e.reading.Lock()
	defer e.reading.Unlock()
	e.mu.Lock()
	fresh := !e.read.IsZero() && time.Since(e.read) < maxAge
	e.mu.Unlock()
	if fresh {
		return
	}
	start := time.Now()
	vars, err := Read(context.WithoutCancel(ctx), e.shell, e.base, Timeout) // a client gone mid-way doesn't make it a failure
	log := slog.With("shell", e.shell, "took", time.Since(start).Round(time.Millisecond))
	e.mu.Lock()
	first := e.vars == nil
	e.mu.Unlock()
	var login []string
	loginWorked := false
	if err != nil && first {
		login, loginWorked = e.readLogin(ctx)
	}
	e.mu.Lock()
	e.read = time.Now()
	switch {
	case err == nil:
		e.vars, e.problem = vars, ""
		log.Info("shell environment read", "vars", len(vars))
		if slog.Default().Enabled(ctx, slog.LevelDebug) {
			log.Debug("shell environment adds", "names", strings.Join(added(e.base, vars), " ")) // names only, never values
		}
	case loginWorked:
		e.vars, e.problem = login, err.Error()
		log.Warn("shell environment read without its interactive config", "why", err) // never what it printed
	default:
		e.problem = err.Error()
		log.Warn("shell environment not read; agents start with the last read or the daemon's", "why", err) // never what it printed
	}
	worked, environ := err == nil || loginWorked, Merge(e.base, e.vars)
	e.mu.Unlock()
	if worked && e.use != nil {
		e.use(environ)
	}
}

// readLogin is the shell's environment as a login shell that isn't
// interactive gives it (-l -c), and whether that worked: what agents and
// the daemon start with when no interactive reading has worked, as they
// did when the daemon started through that shell (ADR 0036). Without it
// a config that hangs or ends only when interactive (one that runs tmux)
// would leave launchd's bare PATH.
func (e *Env) readLogin(ctx context.Context) ([]string, bool) {
	vars, err := ReadLogin(context.WithoutCancel(ctx), e.shell, e.base, Timeout)
	if err != nil && !errors.Is(err, errors.ErrUnsupported) {
		slog.Warn("shell environment not read as a plain login shell either", "shell", e.shell, "why", err)
	}
	return vars, err == nil
}

// added are the names of over's variables base doesn't have.
func added(base, over []string) []string {
	has := map[string]bool{}
	for _, kv := range base {
		name, _, _ := strings.Cut(kv, "=")
		has[nameKey(name)] = true
	}
	var out []string
	for _, kv := range over {
		if name, _, _ := strings.Cut(kv, "="); !has[nameKey(name)] {
			out = append(out, name)
		}
	}
	slices.Sort(out)
	return out
}

// wait waits for the first reading to end.
func (e *Env) wait() { <-e.first }

// Environ is the environment an agent starts with: the shell's over the
// daemon's, without Nushi's own variables. The agent's own overrides go
// after it (exec takes a name's last value).
func (e *Env) Environ() []string {
	e.wait()
	e.mu.Lock()
	defer e.mu.Unlock()
	return Merge(e.base, e.vars)
}

// LookPath finds name on the PATH agents get; "" when it isn't there.
func (e *Env) LookPath(name string) string { return LookPath(name, e.Environ()) }

// Status is how the last reading went, for Settings › Agents: the shell,
// when, and why it failed. Nothing of the environment itself.
func (e *Env) Status() model.ShellEnv {
	e.mu.Lock()
	defer e.mu.Unlock()
	return model.ShellEnv{Shell: e.shell, Read: e.read, Problem: e.problem}
}

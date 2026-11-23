// Package agents finds the agents chats can run on this machine: each one's
// CLI on the login shell's PATH (Env: the environment agents start with),
// its version, and what else it needs.
// Finding them only asks each CLI what it is (Probe), run as the user
// as its chats run it. An agent whose ACP side is an npm package (an
// adapter) runs once that's set up, which happens only when asked
// (SetUp). ADR 0037.
package agents

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"regexp"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/procgroup"
)

// Agent is one agent as main describes it.
type Agent struct {
	Name, Title string
	CLI         string   // its program, looked for on PATH: "claude"
	Also        []string // where else it may be: Ante's ~/.ante/bin/ante
	Min         string   // the oldest version Nushi runs: Ante's bridge follows 0.2.14
	Adapter     *Adapter // nil when it speaks ACP itself, or through Nushi's bridge
	Tested      []string // the CLI's versions Nushi was tried with, oldest first
	// SignedIn says whether the CLI is signed in, "yes" or "no", or ""
	// when it can't tell cheaply; run runs the CLI with args (Probe).
	SignedIn func(run func(args ...string) ([]byte, error)) string
	// SignIn is what the user runs in a terminal to sign the CLI in:
	// "codex login". "": Nushi doesn't know it.
	SignIn string
	// NoSignIn are the ids of sign-in methods the agent may offer through
	// ACP that Nushi doesn't (chats' Kind.NoSignIn, ADR 0145).
	NoSignIn []string
	// Own says whether the agent runs, for now, through Nushi's own ACP
	// agent rather than its Adapter, as the user's setting for the agent
	// says (Codex's Go agent, ADR 0142). It is asked each time, so a change
	// needs no restart; while it says so, the agent has no Adapter. nil:
	// never.
	Own func() bool
}

// Probe runs a program and returns its stdout: Run's, or a test's.
type Probe func(ctx context.Context, path string, args ...string) ([]byte, error)

// ProbeTimeout bounds a Probe's run: a CLI asked its version that hangs
// (a prompt, a network wait) is stopped with what it started.
var ProbeTimeout = 10 * time.Second

// Run is the Probe that runs the program in env's environment (nil, or
// env returning nil: the daemon's), for at most ProbeTimeout.
func Run(env func() []string) Probe {
	return func(ctx context.Context, path string, args ...string) ([]byte, error) {
		ctx, cancel := context.WithTimeout(ctx, ProbeTimeout)
		defer cancel()
		cmd := exec.CommandContext(ctx, path, args...) //nolint:gosec // a CLI found on PATH, asked its version or sign-in
		if env != nil {
			cmd.Env = env()
		}
		procgroup.Bound(cmd)
		return cmd.Output()
	}
}

// Status is an agent as found now.
type Status struct {
	Agent
	Path     string // its CLI; "" when it isn't installed
	Version  string // as the CLI says it; "" when that couldn't be read
	Problem  string // why it can't run, in a few words; "" when it can
	SignedIn string // "yes", "no", or "" (unknown)
	// With an adapter: the version pinned, the one set up ("" when it
	// isn't), how many packages it installs, and where.
	Pinned, Installed string
	Packages          int
	Folder            string
	Ready             bool // a chat can start
	Awake             int  // its chats whose agent runs
}

// Env is the environment agents start with (internal/shellenv): the login
// shell's, read again when asked. Finding an agent looks on its PATH.
type Env interface {
	Environ() []string
	LookPath(name string) string
	Refresh(ctx context.Context, maxAge time.Duration)
	Status() model.ShellEnv
}

type Service struct {
	agents     []Agent
	probe      Probe
	env        Env
	dir        string // <data>/agents: an adapter goes into dir/<agent>
	installer  Installer
	chats      Chats
	installing sync.Mutex // one install or removal at a time

	mu    sync.Mutex
	found map[string]string // each agent as last logged
}

// New is the agents service: agents found with probe on env's PATH, their
// adapters set up by installer in dir.
func New(agents []Agent, probe Probe, env Env, dir string, installer Installer) *Service {
	return &Service{agents: agents, probe: probe, env: env, dir: dir, installer: installer}
}

// UseChats gives the service the chats feature, once there is one.
func (s *Service) UseChats(c Chats) { s.chats = c }

// Environ is the environment an agent starts with.
func (s *Service) Environ() []string { return s.env.Environ() }

// Environment reads the shell's environment again if the last reading is
// older than maxAge, and says how the last went.
func (s *Service) Environment(ctx context.Context, maxAge time.Duration) model.ShellEnv {
	s.env.Refresh(ctx, maxAge)
	return s.env.Status()
}

// agent is the agent named name as it runs now (Agent.Own), and whether
// it is known.
func (s *Service) agent(name string) (Agent, bool) {
	i := slices.IndexFunc(s.agents, func(a Agent) bool { return a.Name == name })
	if i < 0 {
		return Agent{}, false
	}
	return now(s.agents[i]), true
}

// WithOwn are the agents that can run through Nushi's own agent (an Own),
// by name, in the order they're listed.
func (s *Service) WithOwn() []string {
	var out []string
	for _, a := range s.agents {
		if a.Own != nil {
			out = append(out, a.Name)
		}
	}
	return out
}

// now is a as it runs now: through Nushi's own agent, with no adapter,
// when its Own says so.
func now(a Agent) Agent {
	if a.Own != nil && a.Own() {
		a.Adapter = nil
	}
	return a
}

// List finds every agent, all at once, and tells the chats which are ready.
func (s *Service) List(ctx context.Context) []Status {
	out := make([]Status, len(s.agents))
	var wg sync.WaitGroup
	for i, a := range s.agents {
		wg.Go(func() { out[i] = s.find(ctx, now(a)) })
	}
	wg.Wait()
	s.logFound(out)
	for _, st := range out {
		if st.Ready { // its chats that couldn't start it (it was set up or installed meanwhile) may now
			s.chats.AgentReady(st.Name)
		}
	}
	return out
}

// logFound logs each agent found, when it changed since the last time.
func (s *Service) logFound(found []Status) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.found == nil {
		s.found = map[string]string{}
	}
	for _, st := range found {
		args := []any{"agent", st.Name, "path", st.Path, "version", st.Version, "problem", st.Problem, "signed_in", st.SignedIn,
			"adapter", st.Installed, "pinned", st.Pinned, "ready", st.Ready}
		if line := fmt.Sprint(args...); s.found[st.Name] != line {
			s.found[st.Name] = line
			slog.Info("agent found", args...)
		}
	}
}

func (s *Service) find(ctx context.Context, a Agent) (st Status) {
	st = Status{Agent: a, Path: s.lookPath(a.CLI, a.Also), Awake: s.chats.Awake(a.Name)}
	if a.Adapter != nil {
		st.Folder = s.folder(a.Name)
		st.Pinned, st.Packages = a.Adapter.pinned()
		st.Installed, _ = s.installer.Installed(st.Folder, a.Adapter.Package, a.Adapter.Bin)
	}
	defer func() { st.Ready = st.Problem == "" && (a.Adapter == nil || st.Installed != "") }()
	if st.Path == "" {
		st.Problem = "Not installed"
		return st
	}
	if out, err := s.probe(ctx, st.Path, "--version"); err == nil {
		st.Version = versionIn(string(out))
	}
	old, _ := agentproc.Older(st.Version, a.Min) // false when either is none
	switch {
	case a.Min != "" && st.Version != "" && old:
		st.Problem = fmt.Sprintf("Needs %s or newer", a.Min)
	case a.Adapter != nil && s.lookPath("node", nil) == "":
		st.Problem = "Needs Node"
	}
	if a.SignedIn != nil && st.Problem == "" {
		st.SignedIn = a.SignedIn(func(args ...string) ([]byte, error) { return s.probe(ctx, st.Path, args...) })
	}
	return st
}

// lookPath finds name on the agents' PATH, else the first of also that is
// a program.
func (s *Service) lookPath(name string, also []string) string {
	if p := s.env.LookPath(name); p != "" {
		return p
	}
	for _, p := range also {
		if st, err := os.Stat(p); err == nil && st.Mode().IsRegular() && st.Mode()&0o111 != 0 {
			return p
		}
	}
	return ""
}

var versionRE = regexp.MustCompile(`\d+\.\d+(\.\d+)?(-[0-9A-Za-z.-]+)?`)

// versionIn finds the version in what `--version` printed: "2.1.310
// (Claude Code)", "codex-cli 0.163.0", "ante 0.2.14"; without build
// metadata ("0.5.3+1.4.0.74f46864", PiG's, is 0.5.3).
func versionIn(out string) string {
	line, _, _ := strings.Cut(strings.TrimSpace(out), "\n")
	return versionRE.FindString(line)
}

// Run finds what starting the agent named name takes, or says why it
// can't start. It asks no CLI anything, so it's quick.
// An agent running through Nushi's own (Agent.Own) has no Program: its
// Harness starts that agent instead, as Own said when Run asked it.
func (s *Service) Run(name string) (model.AgentRun, error) {
	a, ok := s.agent(name)
	if !ok {
		return model.AgentRun{}, fmt.Errorf("Nushi doesn't know the agent %q", name)
	}
	r := model.AgentRun{CLI: s.lookPath(a.CLI, a.Also), Env: s.Environ()}
	if a.Adapter != nil {
		r.Node = s.lookPath("node", nil)
	}
	switch {
	case r.CLI == "":
		return r, fmt.Errorf("%s isn't installed: there's no %s on PATH", a.Title, a.CLI)
	case a.Adapter == nil:
		return r, nil
	case r.Node == "":
		return r, fmt.Errorf("%s needs Node, and there's none on PATH", a.Title)
	}
	if _, r.Program = s.installer.Installed(s.folder(name), a.Adapter.Package, a.Adapter.Bin); r.Program == "" {
		return r, fmt.Errorf("%s isn't set up: Settings › Agents", a.Title)
	}
	return r, nil
}

// Explain adds to why the agent named name failed to start, when its CLI
// is a version it wasn't tested with, which versions it was.
func (s *Service) Explain(name string) func(error) error {
	return func(err error) error {
		a, ok := s.agent(name)
		run, rerr := s.Run(name)
		if !ok || rerr != nil || len(a.Tested) == 0 {
			return err
		}
		out, _ := s.probe(context.Background(), run.CLI, "--version")
		v := versionIn(string(out))
		if v == "" || slices.Contains(a.Tested, v) {
			return err
		}
		return fmt.Errorf("%w (Nushi was tested with %s %s; this is %s)", err, a.Title, strings.Join(a.Tested, " and "), v)
	}
}

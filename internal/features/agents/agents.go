// Package agents finds the agents chats can run on this Mac: each one's
// CLI on the login shell's PATH, its version, and what else it needs.
// Finding them changes nothing: a CLI is only asked what it is, with
// writes and the network denied (Probe). An agent whose ACP side is an
// npm package (an adapter) runs once that's set up, which happens only
// when asked (SetUp). ADR 0037.
package agents

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"sync"
)

// Agent is one agent as main describes it.
type Agent struct {
	Name, Title string
	CLI         string   // its program, looked for on PATH: "claude"
	Also        []string // where else it may be: Ante's ~/.ante/bin/ante
	Page        string   // where to get it
	Needs       string   // a program it runs under, also on PATH: omp's "bun"
	Min         string   // the oldest version Nushi runs: Ante's bridge follows 0.2.14
	Adapter     *Adapter // nil when it speaks ACP itself, or through Nushi's bridge
	Tested      []string // the CLI's versions Nushi was tried with, oldest first
	// SignedIn says whether the CLI is signed in, "yes" or "no", or ""
	// when it can't tell cheaply; run runs the CLI with args, read-only.
	SignedIn func(run func(args ...string) ([]byte, error)) string
}

// Probe runs a program read-only (internal/readonly) and returns its
// stdout.
type Probe func(ctx context.Context, path string, args ...string) ([]byte, error)

// Status is an agent as found now.
type Status struct {
	Agent
	Path     string // its CLI; "" when it isn't installed
	Version  string // as the CLI says it; "" when that couldn't be read
	Problem  string // why it can't run, in a few words; "" when it can
	SignedIn string // "yes", "no", or "" (unknown)
	// With an adapter: the version pinned, the one set up ("" when it
	// isn't), its program, how many packages it installs, and where.
	Pinned, Installed, Program string
	Packages                   int
	Folder                     string
	Ready                      bool // a chat can start
	Awake                      int  // its chats whose agent runs
}

type Service struct {
	agents     []Agent
	probe      Probe
	dir        string // <data>/agents: an adapter goes into dir/<agent>
	installer  Installer
	chats      Chats
	installing sync.Mutex // one install or removal at a time

	mu    sync.Mutex
	found map[string]string // each agent as last logged
}

func New(agents []Agent, probe Probe, dir string, installer Installer) *Service {
	return &Service{agents: agents, probe: probe, dir: dir, installer: installer}
}

// UseChats gives the service the chats feature, once there is one.
func (s *Service) UseChats(c Chats) { s.chats = c }

// List finds every agent, all at once, and tells the chats which are ready.
func (s *Service) List(ctx context.Context) []Status {
	out := make([]Status, len(s.agents))
	var wg sync.WaitGroup
	for i, a := range s.agents {
		wg.Go(func() { out[i] = s.find(ctx, a) })
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
	st = Status{Agent: a, Path: lookPath(a.CLI, a.Also), Awake: s.chats.Awake(a.Name)}
	if a.Adapter != nil {
		st.Folder = s.folder(a.Name)
		st.Pinned, st.Packages = a.Adapter.pinned()
		st.Installed, st.Program = s.installer.Installed(st.Folder, a.Adapter.Package, a.Adapter.Bin)
	}
	defer func() { st.Ready = st.Problem == "" && (a.Adapter == nil || st.Installed != "") }()
	if st.Path == "" {
		st.Problem = "Not installed"
		return st
	}
	if out, err := s.probe(ctx, st.Path, "--version"); err == nil {
		st.Version = versionIn(string(out))
	}
	switch {
	case a.Min != "" && st.Version != "" && older(st.Version, a.Min):
		st.Problem = fmt.Sprintf("Needs %s or newer", a.Min)
	case a.Needs != "" && lookPath(a.Needs, nil) == "":
		st.Problem = "Needs " + strings.ToUpper(a.Needs[:1]) + a.Needs[1:]
	case a.Adapter != nil && lookPath("node", nil) == "":
		st.Problem = "Needs Node"
	}
	if a.SignedIn != nil && st.Problem == "" {
		st.SignedIn = a.SignedIn(func(args ...string) ([]byte, error) { return s.probe(ctx, st.Path, args...) })
	}
	return st
}

// lookPath finds name on PATH, else the first of also that is a program.
func lookPath(name string, also []string) string {
	if p, err := exec.LookPath(name); err == nil {
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

// older says version a comes before b, by their first three numbers.
func older(a, b string) bool {
	x, y := numbers(a), numbers(b)
	return slices.Compare(x[:], y[:]) < 0
}

func numbers(v string) [3]int {
	if i := strings.IndexAny(v, "-+"); i >= 0 {
		v = v[:i]
	}
	var out [3]int
	for i, p := range strings.SplitN(v, ".", 3) {
		out[i], _ = strconv.Atoi(p)
	}
	return out
}

// Run is what starting an agent takes: its CLI, and with an adapter, the
// adapter's program (run by the Node on PATH).
type Run struct{ CLI, Program string }

// Run finds what starting the agent named name takes, or says why it
// can't start. It asks no CLI anything, so it's quick.
func (s *Service) Run(name string) (Run, error) {
	i := slices.IndexFunc(s.agents, func(a Agent) bool { return a.Name == name })
	if i < 0 {
		return Run{}, fmt.Errorf("Nushi doesn't know the agent %q", name)
	}
	a := s.agents[i]
	r := Run{CLI: lookPath(a.CLI, a.Also)}
	switch {
	case r.CLI == "":
		return r, fmt.Errorf("%s isn't installed: there's no %s on PATH", a.Title, a.CLI)
	case a.Needs != "" && lookPath(a.Needs, nil) == "":
		return r, fmt.Errorf("%s needs %s, and there's none on PATH", a.Title, a.Needs)
	case a.Adapter == nil:
		return r, nil
	case lookPath("node", nil) == "":
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
		i := slices.IndexFunc(s.agents, func(a Agent) bool { return a.Name == name })
		run, rerr := s.Run(name)
		if i < 0 || rerr != nil || len(s.agents[i].Tested) == 0 {
			return err
		}
		a := s.agents[i]
		out, _ := s.probe(context.Background(), run.CLI, "--version")
		v := versionIn(string(out))
		if v == "" || slices.Contains(a.Tested, v) {
			return err
		}
		return fmt.Errorf("%w (Nushi was tested with %s %s; this is %s)", err, a.Title, strings.Join(a.Tested, " and "), v)
	}
}

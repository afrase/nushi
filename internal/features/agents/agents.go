// Package agents finds the agents chats can run on this Mac: each one's
// CLI on the login shell's PATH, its version, and what else it needs.
// Finding them changes nothing: a CLI is only asked what it is, with
// writes and the network denied (Probe). ADR 0037.
package agents

import (
	"context"
	"fmt"
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
}

type Service struct {
	agents []Agent
	probe  Probe
}

func New(agents []Agent, probe Probe) *Service { return &Service{agents: agents, probe: probe} }

// List finds every agent, all at once.
func (s *Service) List(ctx context.Context) []Status {
	out := make([]Status, len(s.agents))
	var wg sync.WaitGroup
	for i, a := range s.agents {
		wg.Go(func() { out[i] = s.find(ctx, a) })
	}
	wg.Wait()
	return out
}

func (s *Service) find(ctx context.Context, a Agent) Status {
	st := Status{Agent: a, Path: lookPath(a.CLI, a.Also)}
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

var versionRE = regexp.MustCompile(`\d+\.\d+(\.\d+)?([-+][0-9A-Za-z.-]+)?`)

// versionIn finds the version in what `--version` printed: "2.1.310
// (Claude Code)", "codex-cli 0.163.0", "ante 0.2.14".
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

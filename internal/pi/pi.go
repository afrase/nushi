// Package pi runs Pi (pi.dev) and PiG (pi-in-go.dev, a Go port of Pi) as
// Nushi's agents. Neither speaks ACP; their RPC mode (`pi --mode rpc`, one
// protocol: JSON lines of commands, responses and events) does what Nushi
// needs. So Nushi brings an ACP agent for them, the bridge: `nushid pi-acp`
// and `nushid pig-acp` run it, a program in RPC mode per session underneath
// (ADR 0039), as it does for Ante. A Flavor says which program; nothing
// outside this package knows the protocol (ADR 0078).
//
// The bridge follows PiG's author's ACP adapter, pig-acp (MichaelKinsy/
// pigpen, components/acp; MIT, itself a port of Sergii Kozak's pi-acp,
// MIT) where they meet: how the program's events map to updates, its tools
// to tool calls, the session folders. It doesn't run it or depend on its
// module.
package pi

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/procgroup"
)

// Flavor is a program that speaks Pi's RPC mode, and the names it has.
type Flavor struct {
	Name, Title string // as Nushi calls it
	CLI         string // its program
	Version     string // whose RPC mode the bridge follows; newer ones are tried, and say so in the log
	Min         string // the oldest the bridge runs; see check
	Page        string // where to get it
	Needs       string // a program it runs under
	Folder      string // its folder in your home and in a project
	Env         string // its variables' prefix
	XDG         bool   // its home can move: <Env>_HOME, $XDG_CONFIG_HOME/<CLI>
}

var (
	// Pi is Pi itself, a Node program.
	Pi = Flavor{Name: "pi", Title: "Pi", CLI: "pi", Version: "1.4.0", Min: "0.80.4", Page: "https://pi.dev",
		Needs: "node", Folder: ".pi", Env: "PI"}
	// PiG is the Go port.
	PiG = Flavor{Name: "pig", Title: "PiG", CLI: "pig", Version: "0.5.3", Page: "https://pi-in-go.dev/install/",
		Folder: ".pig", Env: "PIG", XDG: true}
)

// Command is the nushid subcommand that runs the bridge for f.
func (f Flavor) Command() string { return f.Name + "-acp" }

// AgentName is the bridge's name in its initialize answer.
func (f Flavor) AgentName() string { return "nushi-" + f.Name }

// Harness is a Flavor as Nushi runs it, for the chats feature's interfaces.
type Harness struct{ Flavor }

// Info is what Harness is.
func (h Harness) Info() model.HarnessInfo {
	return model.HarnessInfo{Name: h.Name, Title: h.Title, Resume: h.CLI + " --session"}
}

// Gone says a session/load error means the program no longer has the session: the
// bridge answers ACP's "Resource not found".
func (Harness) Gone(err error) bool { return agentproc.NotFound(err) }

// Start starts the bridge, as ante.Harness does Ante's: this executable's
// Command, in dir (the daemon's folder) and r's environment, its stderr to
// log.
func (h Harness) Start(dir string, r model.AgentRun, client acp.Client, log *slog.Logger) (*agentproc.Agent, error) {
	cmd, err := agentproc.SelfCommand(h.Command(), dir, r.Env) // the bridge finds the CLI on that PATH
	if err != nil {
		return nil, err
	}
	return agentproc.Start(cmd, client, log)
}

// logTo is where the bridge's own lines go: its stderr, which the daemon
// logs with the chat's attributes.
var (
	logMu   sync.Mutex
	logTo   io.Writer = os.Stderr
	logName           = "pi-acp"
)

func logf(format string, args ...any) {
	logMu.Lock()
	defer logMu.Unlock()
	_, _ = fmt.Fprintf(logTo, format+"\n", args...) // stderr, which the daemon reads
}

func warnf(format string, args ...any) { logf(logName+": "+format, args...) }

// debugf writes a line the daemon logs at DEBUG (acp's stderr lines).
func debugf(format string, args ...any) { logf(agentproc.DebugPrefix+logName+": "+format, args...) }

// Main runs the bridge for f on stdin and stdout: the Command.
func (f Flavor) Main() {
	logName = f.Command()
	cfg := Config{Flavor: f, Dirs: f.DirsFromEnv()}
	bin, err := exec.LookPath(f.CLI)
	if err != nil {
		err = fmt.Errorf("%s isn't installed: there's no %s on PATH", f.Title, f.CLI)
	} else {
		cfg.Version, err = f.version(bin)
	}
	cfg.Problem = err
	cfg.Spawn = func(cwd string, args ...string) (Program, error) { return spawn(bin, cwd, args) }
	Serve(os.Stdin, os.Stdout, cfg)
}

// version reads the program's version (Pi's "1.4.0"; PiG's
// "0.5.3+1.4.0.74f46864": its own, then the Pi it ports), and says so when
// it isn't the one the bridge follows.
func (f Flavor) version(bin string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, "--version")
	procgroup.Bound(cmd)
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("couldn't run %s --version: %w", bin, err)
	}
	v, _, _ := strings.Cut(strings.TrimSpace(string(out)), "+")
	if err := f.check(v); err != nil {
		return "", err
	}
	if v != f.Version {
		warnf("%s %s isn't %s, whose RPC mode the bridge follows", f.CLI, v, f.Version)
	}
	return v, nil
}

// check refuses a version older than Min, or one it can't read. Trust
// shows no card because the program gates a folder's code itself, which
// Pi does only since 0.79.0 (ADR 0078): an older one would run a folder's
// extensions unasked, so saying so on the Agents page isn't enough.
func (f Flavor) check(v string) error {
	if f.Min == "" {
		return nil
	}
	got, want := numbers(v), numbers(f.Min)
	switch {
	case got == nil:
		return fmt.Errorf("couldn't read %s's version from %q", f.Title, v)
	case slices.Compare(got, want) < 0:
		return fmt.Errorf("%s %s is older than the %s Nushi needs", f.Title, v, f.Min)
	}
	return nil
}

// numbers reads a version's three numbers, a prerelease's tag left out;
// nil if it hasn't three.
func numbers(v string) []int {
	v, _, _ = strings.Cut(v, "-")
	parts := strings.Split(v, ".")
	if len(parts) != 3 {
		return nil
	}
	out := make([]int, 3)
	for i, p := range parts {
		n, err := strconv.Atoi(p)
		if err != nil {
			return nil
		}
		out[i] = n
	}
	return out
}

// spawn starts the program with args in cwd, in a process group of its own, its
// stderr to the bridge's (its last line kept); its start and exit go to
// the log.
func spawn(bin, cwd string, args []string) (Program, error) {
	p, err := agentproc.Pipe(bin, args, cwd, nil, os.Stderr) // the user's pi (ADR 0039)
	if err != nil {
		return Program{}, err
	}
	started := time.Now()
	warnf("started pid=%d args=%q", p.Pid, args)
	go func() {
		status := "exit status 0"
		if err := p.Wait(); err != nil {
			status = err.Error() // "exit status 1", "signal: killed"
		}
		warnf("exited pid=%d ran=%s %s", p.Pid, time.Since(started).Round(100*time.Millisecond), status)
	}()
	return Program{In: p.In, Out: p.Out, Kill: p.Kill, Said: p.Said}, nil
}

// DirsFromEnv finds f's sessions folder as the program does (and as
// pig-acp's paths.go reads it): <Env>_CODING_AGENT_SESSION_DIR, else the
// sessionDir of the agent folder's settings.json, else the agent folder's
// sessions.
func (f Flavor) DirsFromEnv() Dirs {
	trash, _ := exec.LookPath("trash")
	if d := os.Getenv(f.Env + "_CODING_AGENT_SESSION_DIR"); d != "" {
		return Dirs{Sessions: tilde(d), Trash: trash}
	}
	agent := f.AgentDir()
	var settings struct {
		SessionDir string `json:"sessionDir"`
	}
	if b, err := os.ReadFile(filepath.Join(agent, "settings.json")); err == nil && json.Unmarshal(b, &settings) == nil && settings.SessionDir != "" { //nolint:gosec // the program's own settings
		d := tilde(settings.SessionDir)
		if !filepath.IsAbs(d) {
			d = filepath.Join(agent, d)
		}
		return Dirs{Sessions: d, Trash: trash}
	}
	return Dirs{Sessions: filepath.Join(agent, "sessions"), Trash: trash}
}

// AgentDir is f's agent folder (settings, sessions, trust decisions):
// <Env>_CODING_AGENT_DIR, else <its home>/agent.
func (f Flavor) AgentDir() string {
	if d := os.Getenv(f.Env + "_CODING_AGENT_DIR"); d != "" {
		return tilde(d)
	}
	return filepath.Join(f.home(), "agent")
}

// home is f's own folder: ~/<Folder>, which an XDG Flavor lets
// <Env>_HOME, then $XDG_CONFIG_HOME/<CLI>, move.
func (f Flavor) home() string {
	if f.XDG {
		if h := os.Getenv(f.Env + "_HOME"); h != "" {
			return tilde(h)
		}
		if x := os.Getenv("XDG_CONFIG_HOME"); x != "" {
			return filepath.Join(tilde(x), f.CLI)
		}
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, f.Folder)
}

func tilde(p string) string {
	home, _ := os.UserHomeDir()
	if p == "~" {
		return home
	}
	if rest, ok := strings.CutPrefix(p, "~/"); ok {
		return filepath.Join(home, rest)
	}
	return p
}

// ForkAt says how to fork a session at a message, if the agent is the
// bridge: its own meta, which cuts after the turn that has the message
// (pi forks before a message of the user's).
func (h Harness) ForkAt(init *acp.InitializeResponse) func(messageID string) map[string]any {
	if init.AgentInfo == nil || init.AgentInfo.Name != h.AgentName() {
		return nil
	}
	return func(messageID string) map[string]any {
		return map[string]any{"pi": map[string]any{"afterMessage": messageID}}
	}
}

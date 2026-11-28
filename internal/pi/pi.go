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
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/agentproc"
	"github.com/afrase/nushi/internal/model"
)

// Flavor is a program that speaks Pi's RPC mode, and the names it has.
type Flavor struct {
	Name, Title string   // as Nushi calls it
	CLI         string   // its program
	Version     string   // whose RPC mode the bridge follows; others are tried, and say so in the log
	Tested      []string // the versions the bridge was tried with, oldest first
	Min         string   // the oldest the bridge runs; see check
	Folder      string   // its folder in your home and in a project
	Env         string   // its variables' prefix
	XDG         bool     // its home can move: <Env>_HOME, $XDG_CONFIG_HOME/<CLI>
	// Own is the subcommand that names the program's own version when
	// --version names only the Pi it ports (PiG 0.8.0's `pig version`);
	// "" when --version is its own. See ReadVersion.
	Own string
}

var (
	// Pi is Pi itself, a Node program.
	Pi = Flavor{Name: "pi", Title: "Pi", CLI: "pi", Version: "1.4.0", Tested: []string{"1.4.0"}, Min: "0.80.4",
		Folder: ".pi", Env: "PI"}
	// PiG is the Go port.
	PiG = Flavor{Name: "pig", Title: "PiG", CLI: "pig", Version: "0.8.0", Tested: []string{"0.5.3", "0.8.0"},
		Folder: ".pig", Env: "PIG", XDG: true, Own: "version"}
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
	cfg.Spawn = func(cwd string, args ...string) (agentproc.Program, error) { return spawn(bin, cwd, args) }
	Serve(os.Stdin, os.Stdout, cfg)
}

// version reads the program's version (ReadVersion), and says so when it
// isn't the one the bridge follows.
func (f Flavor) version(bin string) (string, error) {
	v, err := f.ReadVersion(func(bare []string, args ...string) ([]byte, error) {
		var env []string // nil and "": the bridge's own
		var dir string
		if bare != nil {
			env, dir = agentproc.Bare(os.Environ(), bare)
		}
		return agentproc.Output(bin, env, dir, args...)
	})
	if err != nil {
		return "", err
	}
	if err := f.check(v); err != nil {
		return "", err
	}
	switch {
	case v == "":
		warnf("couldn't read %s's version; the bridge follows %s's RPC mode", f.CLI, f.Version)
	case v != f.Version:
		warnf("%s %s isn't %s, whose RPC mode the bridge follows", f.CLI, v, f.Version)
	}
	return v, nil
}

// ownSince is the Pi that PiG 0.8.0 ports, the first PiG seen to print
// only Pi's version for --version, and to have `pig version`.
const ownSince = "1.6.0"

// ReadVersion reads the program's own version with run (the program run
// with args, its stdout; with bare not nil, in an environment of PATH and
// bare alone, in bare's HOME: agentproc.Bare). --version is Pi's "1.4.0", PiG 0.5.3's
// "0.5.3+1.4.0.74f46864" (its own, then the Pi it ports and its commit),
// PiG 0.8.0's "1.6.0" (the Pi alone), whose own is then the first line of
// Own (`pig version`: "pig: 0.8.0", then "upstream pi: 1.6.0" and more).
// Own is asked only of a program whose --version names Pi 1.6.0 or later:
// a PiG between 0.5.3 and 0.8.0 may lack it, and would take "version" for
// a prompt. So Own runs bare too (ownBare): no key to call a model with,
// no settings or sessions of the user's to write to. "" when it can't be
// read; an error when --version can't run.
func (f Flavor) ReadVersion(run func(bare []string, args ...string) ([]byte, error)) (string, error) {
	out, err := run(nil, "--version")
	if err != nil {
		return "", err
	}
	line := firstLine(out)
	if own, _, ok := strings.Cut(line, "+"); ok {
		if agentproc.Numbers(own) == nil {
			return "", nil // not a version: unknown, as Own's garbage is
		}
		return own, nil
	}
	if f.Own == "" {
		return line, nil
	}
	if old, err := agentproc.Older(line, ownSince); err != nil || old {
		return "", nil //nolint:nilerr // not a version this reads: unknown, not a failure
	}
	out, err = f.ownBare(run)
	if err != nil {
		return "", nil //nolint:nilerr // --version ran: the program is there, its own version unknown
	}
	v, ok := strings.CutPrefix(firstLine(out), f.CLI+": ")
	if !ok || agentproc.Numbers(v) == nil {
		return "", nil
	}
	return v, nil
}

// ownBare runs Own with its home, <Env>_HOME and agent folder in an empty
// temp folder, removed after, and no other variable but PATH; the home is
// its working folder, so it reads no AGENTS.md or folder of the user's.
func (f Flavor) ownBare(run func(bare []string, args ...string) ([]byte, error)) ([]byte, error) {
	dir, err := os.MkdirTemp("", "nushi-"+f.CLI+"-version-")
	if err != nil {
		return nil, err
	}
	defer func() { _ = os.RemoveAll(dir) }()
	bare := []string{"HOME=" + filepath.Join(dir, "home"), f.Env + "_HOME=" + filepath.Join(dir, f.CLI),
		f.Env + "_CODING_AGENT_DIR=" + filepath.Join(dir, "agent")}
	for _, kv := range bare {
		_, d, _ := strings.Cut(kv, "=")
		if err := os.Mkdir(d, 0o700); err != nil {
			return nil, err
		}
	}
	return run(bare, f.Own)
}

// firstLine is out's first line, trimmed.
func firstLine(out []byte) string {
	line, _, _ := strings.Cut(strings.TrimSpace(string(out)), "\n")
	return strings.TrimSpace(line)
}

// check refuses a version older than Min, or one it can't read. Trust
// shows no card because the program gates a folder's code itself, which
// Pi does only since 0.79.0 (ADR 0078): an older one would run a folder's
// extensions unasked, so saying so on the Agents page isn't enough.
func (f Flavor) check(v string) error {
	if f.Min == "" {
		return nil
	}
	got, want := agentproc.Numbers(v), agentproc.Numbers(f.Min)
	switch {
	case got == nil:
		return fmt.Errorf("couldn't read %s's version from %q", f.Title, v)
	case slices.Compare(got, want) < 0:
		return fmt.Errorf("%s %s is older than the %s Nushi needs", f.Title, v, f.Min)
	}
	return nil
}

// spawn starts the program with args in cwd, in the bridge's process
// group, so the daemon's stop of the bridge ends it and what it started
// (what a closed session's pi left lives until then), its stderr to the
// bridge's (its last line kept); its start and exit go to the log.
func spawn(bin, cwd string, args []string) (agentproc.Program, error) {
	p, err := agentproc.Pipe(bin, args, cwd, nil, os.Stderr, false) // the user's pi (ADR 0039)
	if err != nil {
		return agentproc.Program{}, err
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
	return p.Program(), nil
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

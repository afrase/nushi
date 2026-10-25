// Package pig runs PiG (pi-in-go.dev, a Go port of the Pi coding agent) as
// one of Nushi's agents. PiG speaks no ACP of its own; its RPC mode
// (`pig --mode rpc`, Pi 1.4.0's protocol: JSON lines of commands,
// responses and events) does what Nushi needs. So Nushi brings an ACP agent
// for it, the bridge: `nushid pig-acp` runs it, a `pig --mode rpc` per
// session underneath (ADR 0039), as it does for Ante. Nothing outside this
// package knows PiG's protocol.
//
// The bridge follows the author's ACP adapter, pig-acp (MichaelKinsy/
// pigpen, components/acp; MIT, itself a port of Sergii Kozak's pi-acp,
// MIT) where they meet: how pig's events map to updates, its tools to
// tool calls, the session folders. It doesn't run it or depend on its
// module.
package pig

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/afrase/nushi/acp"
)

// Command is the nushid subcommand that runs the bridge.
const Command = "pig-acp"

// CLI is PiG's program, Version the PiG whose RPC mode the bridge follows
// (newer ones are tried, and say so in the log), and Page where to get it.
const (
	CLI     = "pig"
	Version = "0.5.3"
	Page    = "https://pi-in-go.dev/install/"
)

// Tested are the PiG versions the bridge was run with.
var Tested = []string{Version}

// Resume is the terminal command that opens a PiG session by its id.
const Resume = "pig --session"

// Start starts the bridge, as ante.Start does Ante's: this executable's
// Command, in dir (the daemon's folder), its stderr to log.
func Start(dir string, h acp.Handler, log *slog.Logger) (*acp.Client, error) {
	self, err := os.Executable()
	if err != nil {
		return nil, err
	}
	cmd := exec.Command(self, Command) //nolint:gosec,noctx // lives until Stop or Close, not a context; this nushid as the bridge
	cmd.Dir = dir
	return acp.Start(cmd, h, log)
}

// logTo is where the bridge's own lines go: its stderr, which the daemon
// logs with the chat's attributes.
var (
	logMu sync.Mutex
	logTo io.Writer = os.Stderr
)

func logf(format string, args ...any) {
	logMu.Lock()
	defer logMu.Unlock()
	fmt.Fprintf(logTo, format+"\n", args...)
}

func warnf(format string, args ...any) { logf("pig-acp: "+format, args...) }

// debugf writes a line the daemon logs at DEBUG (acp's stderr lines).
func debugf(format string, args ...any) { logf(acp.DebugPrefix+"pig-acp: "+format, args...) }

// Main runs the bridge on stdin and stdout: the Command.
func Main() {
	cfg := Config{Dirs: DirsFromEnv()}
	bin, err := exec.LookPath(CLI)
	if err != nil {
		err = errors.New("PiG isn't installed: there's no pig on PATH")
	} else {
		cfg.Version, err = version(bin)
	}
	cfg.Problem = err
	cfg.Spawn = func(cwd string, args ...string) (Pig, error) { return spawn(bin, cwd, args) }
	Serve(os.Stdin, os.Stdout, cfg)
}

// version reads pig's version ("0.5.3+1.4.0.74f46864": PiG's, then the
// Pi it ports), and says so when it isn't the one the bridge follows.
func version(bin string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, bin, "--version").Output()
	if err != nil {
		return "", fmt.Errorf("couldn't run %s --version: %w", bin, err)
	}
	v, _, _ := strings.Cut(strings.TrimSpace(string(out)), "+")
	if v != Version {
		warnf("pig %s isn't %s, whose RPC mode the bridge follows", v, Version)
	}
	return v, nil
}

// spawn starts pig with args in cwd, in a process group of its own, its
// stderr to the bridge's (its last lines kept); its start and exit go to
// the log.
func spawn(bin, cwd string, args []string) (Pig, error) {
	cmd := exec.Command(bin, args...) //nolint:gosec,noctx // lives until Stop or Close, not a context; the user's pig (ADR 0039)
	cmd.Dir = cwd
	said := &lastLines{}
	cmd.Stderr = io.MultiWriter(os.Stderr, said)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	in, err := cmd.StdinPipe()
	if err != nil {
		return Pig{}, err
	}
	out, err := cmd.StdoutPipe()
	if err != nil {
		return Pig{}, err
	}
	if err := cmd.Start(); err != nil {
		return Pig{}, err
	}
	started := time.Now()
	warnf("pig started pid=%d args=%q", cmd.Process.Pid, args)
	exited := make(chan struct{})
	go func() {
		status := "exit status 0"
		if err := cmd.Wait(); err != nil {
			status = err.Error() // "exit status 1", "signal: killed"
		}
		warnf("pig exited pid=%d ran=%s %s", cmd.Process.Pid, time.Since(started).Round(100*time.Millisecond), status)
		close(exited)
	}()
	kill := func() {
		syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
		<-exited
	}
	return Pig{In: in, Out: out, Kill: kill, Said: said.String}, nil
}

// lastLines keeps the start of the last line written to it that has
// anything in it ("Error: Failed to load extension …").
type lastLines struct {
	mu   sync.Mutex
	line []byte
	last string
}

func (l *lastLines) Write(p []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	for _, c := range p {
		switch {
		case c == '\n':
			if s := strings.TrimSpace(string(l.line)); s != "" && !strings.HasPrefix(s, "Hint:") {
				l.last = s
			}
			l.line = l.line[:0]
		case len(l.line) < 500:
			l.line = append(l.line, c)
		}
	}
	return len(p), nil
}

func (l *lastLines) String() string {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.last
}

// DirsFromEnv finds PiG's sessions folder as pig does (and as pig-acp's
// paths.go reads it): PIG_CODING_AGENT_SESSION_DIR, else the sessionDir
// of the agent folder's settings.json, else the agent folder's sessions.
// The agent folder is PIG_CODING_AGENT_DIR, else <PiG's home>/agent, the
// home being PIG_HOME, else $XDG_CONFIG_HOME/pig, else ~/.pig.
func DirsFromEnv() Dirs {
	trash, _ := exec.LookPath("trash")
	if d := os.Getenv("PIG_CODING_AGENT_SESSION_DIR"); d != "" {
		return Dirs{Sessions: tilde(d), Trash: trash}
	}
	agent := AgentDir()
	var settings struct {
		SessionDir string `json:"sessionDir"`
	}
	if b, err := os.ReadFile(filepath.Join(agent, "settings.json")); err == nil && json.Unmarshal(b, &settings) == nil && settings.SessionDir != "" { //nolint:gosec // PiG's own settings
		d := tilde(settings.SessionDir)
		if !filepath.IsAbs(d) {
			d = filepath.Join(agent, d)
		}
		return Dirs{Sessions: d, Trash: trash}
	}
	return Dirs{Sessions: filepath.Join(agent, "sessions"), Trash: trash}
}

// AgentDir is PiG's agent folder (settings, sessions, trust decisions).
func AgentDir() string {
	if d := os.Getenv("PIG_CODING_AGENT_DIR"); d != "" {
		return tilde(d)
	}
	return filepath.Join(Home(), "agent")
}

// Home is PiG's own folder: PIG_HOME, else $XDG_CONFIG_HOME/pig, else ~/.pig.
func Home() string {
	if h := os.Getenv("PIG_HOME"); h != "" {
		return tilde(h)
	}
	if x := os.Getenv("XDG_CONFIG_HOME"); x != "" {
		return filepath.Join(tilde(x), "pig")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".pig")
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
// (pig forks before a message of the user's).
func ForkAt(init *acp.InitializeResponse) func(messageID string) map[string]any {
	if init.AgentInfo == nil || init.AgentInfo.Name != AgentName {
		return nil
	}
	return func(messageID string) map[string]any {
		return map[string]any{"pig": map[string]any{"afterMessage": messageID}}
	}
}

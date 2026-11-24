// Package agentproc runs an agent's process and speaks ACP to it through
// acp-go, with what Nushi logs of it (ADR 0038): its start and exit, each
// line of its stderr, what it is once initialized, the sessions it opens,
// and the calls that failed or were slow; never what they carried. Pipe
// starts the program a bridge speaks another protocol to (pipe.go).
package agentproc

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/afrase/acp-go/steering"
	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/batchfile"
	"github.com/afrase/nushi/internal/model"
)

// NotFound says an agent's error is ACP's "Resource not found" (-32002),
// which claudeacp's session/load answers for a session claude has no
// transcript of, as PiG's bridge does.
func NotFound(err error) bool {
	e, ok := errors.AsType[*acp.Error](err)
	return ok && e.Code == acp.ErrorCodeResourceNotFound
}

// Agent is an agent's process and the connection to it.
type Agent struct {
	*acp.AgentConn
	cmd      *exec.Cmd
	log      *slog.Logger
	stderr   *stderrLines
	ended    chan struct{} // closed once its exit is logged, its stderr read to the end
	canFork  bool          // set by Initialize
	canSteer bool          // the same
	bySignal bool          // StopBySignal was called
	stopped  atomic.Bool   // Close or Stop was called: its end isn't a death
}

// Start runs cmd, in its own process group, and speaks ACP over its stdin
// and stdout; what the agent sends goes to client, and what happens to
// log. On Windows an npm shim runs as node and its script
// (batchfile.Guard).
func Start(cmd *exec.Cmd, client acp.Client, log *slog.Logger) (*Agent, error) {
	if log == nil {
		log = slog.New(slog.DiscardHandler)
	}
	batchfile.Guard(cmd)
	stderr := &stderrLines{log: log, waiting: true}
	cmd.Stderr = stderr
	calls := &callLog{}
	calls.inner.Store(handlerOf(log))
	started := time.Now()
	conn, err := acp.Start(cmd, func(*acp.AgentConn) acp.Client { return client }, acp.WithLogger(slog.New(calls)), acp.WithWriteLimit(model.MaxAgentMessage), acp.WithReadLimit(MaxRead))
	if err != nil {
		stderr.setLog(log) // what it wrote, if it ran at all
		return nil, err
	}
	log = log.With("pid", cmd.Process.Pid)
	calls.inner.Store(handlerOf(log))
	log.Info("agent started", "cmd", strings.Join(cmd.Args, " "))
	stderr.setLog(log) // what it wrote before this goes after "agent started"
	a := &Agent{AgentConn: conn, cmd: cmd, log: log, stderr: stderr, ended: make(chan struct{})}
	go func() {
		<-conn.Done() // its process has been waited for, and its stderr read
		stderr.flush()
		a.exited(time.Since(started))
		close(a.ended)
	}()
	return a, nil
}

// SelfCommand is this executable run as an agent built into it: its
// subcommand sub, in dir with env. Its caller Starts it; an agent of the
// user's own runs through Start alone.
func SelfCommand(sub, dir string, env []string) (*exec.Cmd, error) {
	self, err := os.Executable()
	if err != nil {
		return nil, err
	}
	cmd := exec.Command(self, sub) //nolint:gosec,noctx // lives until Stop or Close, not a context; this executable as the agent
	cmd.Dir, cmd.Env = dir, env
	return cmd, nil
}

// Connect is an Agent of a connection Nushi didn't start a process for
// (a test's fake over pipes): its Pid is 0, and Stop closes it.
func Connect(conn *acp.AgentConn, log *slog.Logger) *Agent {
	if log == nil {
		log = slog.New(slog.DiscardHandler)
	}
	return &Agent{AgentConn: conn, log: log}
}

// MaxRead is the largest message read from an agent, generous: a longer
// line is read to its end and skipped, rather than the daemon growing
// until it holds it (acp-go answers a request so with an error, fails the
// call a response answers, drops a notification, and logs it), and the
// connection goes on. A var for tests.
var MaxRead = 256 << 20

func handlerOf(l *slog.Logger) *handler { return &handler{l.Handler()} }

// Pid is the agent's process id, the first of its process group; 0 for
// one Connect made.
func (a *Agent) Pid() int {
	if a.cmd == nil {
		return 0
	}
	return a.cmd.Process.Pid
}

// Close kills the agent's process group.
func (a *Agent) Close() error {
	a.stopped.Store(true)
	return a.AgentConn.Close()
}

// StopBySignal has Stop send the agent's process SIGTERM first, and close
// its input only once it has exited or grace is over. Its harness calls it
// on the Agent Start returned, before anything else has it. It is for an
// agent whose input closing is the wrong way to end it: opencode exits at
// once then and leaves the shell commands it was running, while a SIGTERM
// cancels its turn and takes them with it (docs/facts/opencode.md). The
// input stays open meanwhile so that its closing can't be what the agent
// acts on.
func (a *Agent) StopBySignal() { a.bySignal = true }

// StopEnds says whether a clean stop of the agent (Stop, Close) ends p,
// its own process or one below it, as it is now: one in its process
// group, which the stop kills, or any for an agent stopped by signal,
// whose SIGTERM takes what it runs (docs/facts/opencode.md). One that
// leads a group of its own below another agent outlives the stop, as
// Claude's and Ante's background commands do (ADR 0032, 0130). False for
// an agent Connect made.
func (a *Agent) StopEnds(p model.Process) bool {
	if a.cmd == nil {
		return false
	}
	return a.bySignal || p.Pgid == a.cmd.Process.Pid
}

// Stop ends the agent gently: its input closes, which an agent takes as
// the end of the connection (claudeacp closes its sessions, their turns
// cancelled, so they are recorded as ended), and once it has exited,
// or after grace, it is killed. One stopped by signal (StopBySignal) is
// sent SIGTERM and waited for before that, within the same grace.
func (a *Agent) Stop(grace time.Duration) error {
	a.stopped.Store(true)
	ctx, cancel := context.WithTimeout(context.Background(), grace)
	defer cancel()
	if a.bySignal && a.cmd != nil && a.cmd.Process.Signal(syscall.SIGTERM) == nil {
		select {
		case <-a.Done():
		case <-ctx.Done():
		}
	}
	if err := a.Shutdown(ctx); err != nil && ctx.Err() == nil {
		return err
	}
	return nil
}

// Initialize initializes the connection, and logs what the agent is and
// the capabilities Nushi uses.
func (a *Agent) Initialize(ctx context.Context, req *acp.InitializeRequest) (*acp.InitializeResponse, error) {
	start := time.Now()
	resp, err := a.AgentConn.Initialize(ctx, req)
	if err != nil {
		return nil, err
	}
	var caps []string
	add := func(name string, ok bool) {
		if ok {
			caps = append(caps, name)
		}
	}
	if c := resp.AgentCapabilities; c != nil {
		add("load", c.LoadSession)
		if s := c.SessionCapabilities; s != nil {
			add("list", s.List != nil)
			add("resume", s.Resume != nil)
			add("close", s.Close != nil)
			add("delete", s.Delete != nil)
			a.canFork = s.Fork != nil
		}
		add("images", c.PromptCapabilities != nil && c.PromptCapabilities.Image)
	}
	a.canSteer = steering.Supported(resp.Meta)
	add("fork", a.canFork)
	add("steer", a.canSteer)
	args := []any{"protocol", resp.ProtocolVersion, "took", time.Since(start).Round(time.Millisecond)}
	if i := resp.AgentInfo; i != nil {
		args = append(args, "impl", i.Name+" "+i.Version)
	}
	a.log.Info("agent initialized", append(args, "caps", strings.Join(caps, ","))...)
	return resp, nil
}

// CanFork reports whether the agent advertised session/fork when it was
// initialized.
func (a *Agent) CanFork() bool { return a.canFork }

// CanSteer reports whether it advertised steering ([steering]).
func (a *Agent) CanSteer() bool { return a.canSteer }

// Steer hands prompt to the session's running turn. It returns false, and
// the agent does nothing, when no turn runs: the message then belongs in a
// session/prompt.
func (a *Agent) Steer(ctx context.Context, session acp.SessionID, prompt []acp.ContentBlock) (bool, error) {
	outcome, err := steering.Steer(ctx, a.AgentConn, string(session), prompt)
	return err == nil && outcome == steering.Injected, err
}

// NewSession opens a session, and logs it.
func (a *Agent) NewSession(ctx context.Context, req *acp.NewSessionRequest) (*acp.NewSessionResponse, error) {
	start := time.Now()
	resp, err := a.AgentConn.NewSession(ctx, req)
	if err == nil {
		a.opened("session/new", resp.SessionID, start)
	}
	return resp, err
}

// LoadSession reopens a session, and logs it.
func (a *Agent) LoadSession(ctx context.Context, req *acp.LoadSessionRequest) (*acp.LoadSessionResponse, error) {
	start := time.Now()
	resp, err := a.AgentConn.LoadSession(ctx, req)
	if err == nil {
		a.opened("session/load", req.SessionID, start)
	}
	return resp, err
}

// ForkSession forks a session, and logs the fork.
func (a *Agent) ForkSession(ctx context.Context, req *acp.ForkSessionRequest) (*acp.ForkSessionResponse, error) {
	start := time.Now()
	resp, err := a.AgentConn.ForkSession(ctx, req)
	if err == nil {
		a.opened("session/fork", resp.SessionID, start, "from", string(req.SessionID))
	}
	return resp, err
}

func (a *Agent) opened(method string, session acp.SessionID, start time.Time, args ...any) {
	a.log.Info(method, append([]any{"session", string(session), "took", time.Since(start).Round(time.Millisecond)}, args...)...)
}

// whyWait is how long Why waits for the agent's process to end.
const whyWait = 2 * time.Second

// Why says how the agent's process ended and the line of its stderr that
// says why ("exit 1: Error: Cannot find module 'x'", "SIGKILL"), for the
// chat's notice: masked and cut (tail), never a bridge's DEBUG line or a
// key. It waits up to whyWait for the end, as a call can fail on the
// connection's end before the process has been waited for and its stderr
// read; one still running by then gives the line alone. "" for an agent
// Connect made.
func (a *Agent) Why() string {
	if a.cmd == nil {
		return ""
	}
	select {
	case <-a.ended:
	case <-time.After(whyWait):
		return a.stderr.tail.String()
	}
	how := "exit " + strconv.Itoa(a.cmd.ProcessState.ExitCode())
	if sig, ok := killedBy(a.cmd.ProcessState); ok {
		how = sig
	}
	if line := a.stderr.tail.String(); line != "" {
		return how + ": " + line
	}
	return how
}

// exited logs the agent's process ending: its exit code or signal, how
// long it ran, and whether Nushi stopped it or it died.
func (a *Agent) exited(ran time.Duration) {
	args := []any{"ran", ran.Round(100 * time.Millisecond)}
	if sig, ok := killedBy(a.cmd.ProcessState); ok {
		args = append(args, "signal", sig)
	} else {
		args = append(args, "code", a.cmd.ProcessState.ExitCode())
	}
	if a.stopped.Load() {
		a.log.Info("agent exited", append(args, "stopped", true)...)
		return
	}
	a.log.Warn("agent died", args...)
}

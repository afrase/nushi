// Package agentproc runs an agent's process and speaks ACP to it through
// acp-go, with what Nushi logs of it (ADR 0038): its start and exit, each
// line of its stderr, what it is once initialized, the sessions it opens,
// and the calls that failed or were slow; never what they carried.
package agentproc

import (
	"context"
	"errors"
	"log/slog"
	"os/exec"
	"strings"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/afrase/acp-go/steering"
	acp "github.com/afrase/acp-go/unstable"
	"golang.org/x/sys/unix"
)

// Agent is an agent's process and the connection to it.
type Agent struct {
	*acp.AgentConn
	cmd      *exec.Cmd
	log      *slog.Logger
	canFork  bool        // set by Initialize
	canSteer bool        // the same
	stopped  atomic.Bool // Close or Stop was called: its end isn't a death
}

// Start runs cmd, in its own process group, and speaks ACP over its stdin
// and stdout; what the agent sends goes to client, and what happens to
// log.
func Start(cmd *exec.Cmd, client acp.Client, log *slog.Logger) (*Agent, error) {
	if log == nil {
		log = slog.New(slog.DiscardHandler)
	}
	stderr := &stderrLines{log: log}
	cmd.Stderr = stderr
	calls := &callLog{}
	calls.inner.Store(handlerOf(log))
	started := time.Now()
	conn, err := acp.Start(cmd, func(*acp.AgentConn) acp.Client { return client }, acp.WithLogger(slog.New(calls)), acp.WithWriteLimit(MaxMessage), acp.WithReadLimit(MaxRead))
	if err != nil {
		return nil, err
	}
	log = log.With("pid", cmd.Process.Pid)
	calls.inner.Store(handlerOf(log))
	stderr.setLog(log)
	log.Info("agent started", "cmd", strings.Join(cmd.Args, " "))
	a := &Agent{AgentConn: conn, cmd: cmd, log: log}
	go func() {
		<-conn.Done() // its process has been waited for, and its stderr read
		stderr.flush()
		a.exited(time.Since(started))
	}()
	return a, nil
}

// Connect is an Agent of a connection Nushi didn't start a process for
// (a test's fake over pipes): its Pid is 0, and Stop closes it.
func Connect(conn *acp.AgentConn, log *slog.Logger) *Agent {
	if log == nil {
		log = slog.New(slog.DiscardHandler)
	}
	return &Agent{AgentConn: conn, log: log}
}

// MaxMessage is the largest message written to an agent, kept below what
// agents read in one line (claude-agent-acp's SDK: 32 MiB, past which it
// ends the connection).
const MaxMessage = 30 << 20

// MaxRead is the largest message read from an agent, generous: a longer
// line ends the connection and the agent with it (its chat sees it die),
// rather than the daemon growing until it does. A var for tests.
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

// Stop ends the agent gently: its input closes, which an agent takes as
// the end of the connection (claude-agent-acp cancels its turns and closes
// its sessions, so they are recorded as ended), and once it has exited,
// or after grace, it is killed.
func (a *Agent) Stop(grace time.Duration) error {
	a.stopped.Store(true)
	ctx, cancel := context.WithTimeout(context.Background(), grace)
	defer cancel()
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

// exited logs the agent's process ending: its exit code or signal, how
// long it ran, and whether Nushi stopped it or it died.
func (a *Agent) exited(ran time.Duration) {
	args := []any{"ran", ran.Round(100 * time.Millisecond)}
	if ws, ok := a.cmd.ProcessState.Sys().(syscall.WaitStatus); ok && ws.Signaled() {
		args = append(args, "signal", unix.SignalName(ws.Signal()))
	} else {
		args = append(args, "code", a.cmd.ProcessState.ExitCode())
	}
	switch {
	case errors.Is(a.Err(), acp.ErrTooLarge):
		a.log.Warn("agent ended: it sent a message over the read limit", append(args, "limit", MaxRead)...)
	case a.stopped.Load():
		a.log.Info("agent exited", append(args, "stopped", true)...)
	default:
		a.log.Warn("agent died", args...)
	}
}

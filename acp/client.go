package acp

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"os/exec"
	"strings"
	"sync/atomic"
	"syscall"
	"time"
)

// Version is the ACP version this client speaks.
const Version ProtocolVersion = 1

// Handler answers what the agent sends to the client.
type Handler interface {
	// SessionUpdate is called for each session/update, in order.
	SessionUpdate(SessionNotification)
	// RequestPermission answers session/request_permission. It may block
	// until the user decides; ctx ends if the agent goes away.
	RequestPermission(context.Context, RequestPermissionRequest) (*RequestPermissionResponse, error)
	// CreateElicitation answers elicitation/create (a form for the user, such
	// as Claude's AskUserQuestion), blocking like RequestPermission.
	CreateElicitation(context.Context, CreateElicitationRequest) (*CreateElicitationResponse, error)
}

// Client is a connection to one agent.
type Client struct {
	conn     *conn
	cmd      *exec.Cmd
	stdin    io.Closer
	canFork  bool        // initialize advertised session/fork
	canSteer bool        // and steering (see Steer)
	stopped  atomic.Bool // Close or Stop was called: its end isn't a death
}

// Start runs the agent command, in its own process group, and speaks ACP over
// its stdin and stdout. What happens goes to log: the process starting and
// exiting (log.go), each line of its stderr, and the calls (conn).
func Start(cmd *exec.Cmd, h Handler, log *slog.Logger) (*Client, error) {
	log = orDiscard(log)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	stderr := &stderrLines{log: log}
	cmd.Stderr = stderr
	cmd.WaitDelay = time.Second // past the agent's exit, for a process it left holding its stderr
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	started := time.Now()
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	log = log.With("pid", cmd.Process.Pid)
	stderr.mu.Lock()
	stderr.log = log
	stderr.mu.Unlock()
	log.Info("agent started", "cmd", strings.Join(cmd.Args, " "))
	c := Connect(stdout, stdin, h, log)
	c.cmd, c.stdin = cmd, stdin
	go func() {
		<-c.conn.done
		_ = cmd.Wait()
		stderr.flush()
		c.exited(log, time.Since(started))
	}()
	return c, nil
}

// Connect speaks ACP over r and w; log gets the calls (conn).
func Connect(r io.Reader, w io.Writer, h Handler, log *slog.Logger) *Client {
	return &Client{conn: newConn(r, w, orDiscard(log), func(ctx context.Context, method string, params json.RawMessage) (any, error) {
		switch method {
		case "session/update":
			var n SessionNotification
			if err := json.Unmarshal(params, &n); err != nil {
				return nil, err
			}
			h.SessionUpdate(n)
			return nil, nil
		case "session/request_permission":
			var req RequestPermissionRequest
			if err := json.Unmarshal(params, &req); err != nil {
				return nil, err
			}
			return h.RequestPermission(ctx, req)
		case "elicitation/create":
			var req CreateElicitationRequest
			if err := json.Unmarshal(params, &req); err != nil {
				return nil, err
			}
			return h.CreateElicitation(ctx, req)
		}
		return nil, ErrMethodNotFound
	})}
}

// Pid is the agent's process id (the first of its process group), or 0
// for an agent Connect speaks to.
func (c *Client) Pid() int {
	if c.cmd == nil {
		return 0
	}
	return c.cmd.Process.Pid
}

// Done is closed when the connection to the agent ends.
func (c *Client) Done() <-chan struct{} { return c.conn.done }

// Close kills the agent's process group (launchers such as npx leave the
// agent in a child process).
func (c *Client) Close() error {
	if c.cmd == nil {
		return nil
	}
	c.stopped.Store(true)
	return syscall.Kill(-c.cmd.Process.Pid, syscall.SIGKILL)
}

// Stop ends the agent gently, then kills what is left of it: its input
// closes, which an agent takes as the end of the connection (claude-agent-acp
// cancels its turns and closes its sessions, so they are recorded as
// ended), and once its process has exited, or after grace, Close.
func (c *Client) Stop(grace time.Duration) error {
	if c.cmd == nil {
		return nil
	}
	c.stopped.Store(true)
	_ = c.stdin.Close() // closing stdin asks the agent to end; Close kills it if it doesn't
	select {
	case <-c.conn.done:
	case <-time.After(grace):
	}
	return c.Close()
}

// Initialize sends initialize: the protocol version and capabilities.
func (c *Client) Initialize(ctx context.Context, req InitializeRequest) (*InitializeResponse, error) {
	var raw json.RawMessage
	start := time.Now()
	if err := c.conn.call(ctx, "initialize", req, &raw); err != nil {
		return nil, err
	}
	var resp InitializeResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		return nil, err
	}
	var caps struct {
		Meta struct {
			Steering struct {
				Supported bool `json:"supported"`
			} `json:"steering"`
		} `json:"_meta"`
		AgentCapabilities struct {
			SessionCapabilities struct {
				Fork json.RawMessage `json:"fork"`
			} `json:"sessionCapabilities"`
		} `json:"agentCapabilities"`
	}
	_ = json.Unmarshal(raw, &caps)
	fork := caps.AgentCapabilities.SessionCapabilities.Fork
	c.canFork = len(fork) > 0 && string(fork) != "null"
	c.canSteer = caps.Meta.Steering.Supported
	c.initialized(&resp, time.Since(start))
	return &resp, nil
}

// CloseSession ends a session the agent keeps (session/close).
func (c *Client) CloseSession(ctx context.Context, req CloseSessionRequest) error {
	return c.conn.call(ctx, "session/close", req, nil)
}

// DeleteSession deletes the agent's history of a session (session/delete).
func (c *Client) DeleteSession(ctx context.Context, req DeleteSessionRequest) error {
	return c.conn.call(ctx, "session/delete", req, nil)
}

// ListSessions lists the agent's sessions (session/list), a page at a time.
func (c *Client) ListSessions(ctx context.Context, req ListSessionsRequest) (*ListSessionsResponse, error) {
	var resp ListSessionsResponse
	return &resp, c.conn.call(ctx, "session/list", req, &resp)
}

// NewSession sends session/new.
func (c *Client) NewSession(ctx context.Context, req NewSessionRequest) (*NewSessionResponse, error) {
	var resp NewSessionResponse
	start := time.Now()
	err := c.conn.call(ctx, "session/new", req, &resp)
	c.opened(err, "session/new", string(resp.SessionID), start)
	return &resp, err
}

// LoadSession reopens a session; the agent replays its history as session
// updates before answering.
func (c *Client) LoadSession(ctx context.Context, req LoadSessionRequest) (*LoadSessionResponse, error) {
	var resp LoadSessionResponse
	start := time.Now()
	err := c.conn.call(ctx, "session/load", req, &resp)
	c.opened(err, "session/load", string(req.SessionID), start)
	return &resp, err
}

// Prompt sends session/prompt and waits for the turn to end.
func (c *Client) Prompt(ctx context.Context, req PromptRequest) (*PromptResult, error) {
	wait, err := c.StartPrompt(req)
	if err != nil {
		return nil, err
	}
	return wait(ctx)
}

// StartPrompt sends a prompt and returns once it is written to the agent,
// so a session/cancel sent after it can't reach the agent first; wait
// returns the turn's result when it ends.
func (c *Client) StartPrompt(req PromptRequest) (wait func(context.Context) (*PromptResult, error), err error) {
	w, err := c.conn.send("session/prompt", req)
	if err != nil {
		return nil, err
	}
	return func(ctx context.Context) (*PromptResult, error) {
		var resp PromptResult
		return &resp, w(ctx, &resp)
	}, nil
}

// Cancel asks the agent to stop the session's running turn, whose prompt
// then ends with stop reason "cancelled".
func (c *Client) Cancel(req CancelNotification) error {
	return c.conn.notify("session/cancel", req)
}

// SetConfigOption sends session/set_config_option.
func (c *Client) SetConfigOption(ctx context.Context, req SetSessionConfigOptionRequest) (*SetSessionConfigOptionResponse, error) {
	var resp SetSessionConfigOptionResponse
	return &resp, c.conn.call(ctx, "session/set_config_option", req, &resp)
}

// SetMode sends session/set_mode.
func (c *Client) SetMode(ctx context.Context, req SetSessionModeRequest) error {
	return c.conn.call(ctx, "session/set_mode", req, nil)
}

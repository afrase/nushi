package acp

import (
	"context"
	"encoding/json"
	"io"
	"os/exec"
	"syscall"
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
	conn    *conn
	cmd     *exec.Cmd
	canFork bool // initialize advertised session/fork
}

// Start runs the agent command, in its own process group, and speaks ACP over
// its stdin and stdout.
func Start(cmd *exec.Cmd, h Handler) (*Client, error) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	c := Connect(stdout, stdin, h)
	c.cmd = cmd
	go func() {
		<-c.conn.done
		_ = cmd.Wait()
	}()
	return c, nil
}

// Connect speaks ACP over r and w.
func Connect(r io.Reader, w io.Writer, h Handler) *Client {
	return &Client{conn: newConn(r, w, func(ctx context.Context, method string, params json.RawMessage) (any, error) {
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

// Done is closed when the connection to the agent ends.
func (c *Client) Done() <-chan struct{} { return c.conn.done }

// Close kills the agent's process group (launchers such as npx leave the
// agent in a child process).
func (c *Client) Close() error {
	if c.cmd == nil {
		return nil
	}
	return syscall.Kill(-c.cmd.Process.Pid, syscall.SIGKILL)
}

func (c *Client) Initialize(ctx context.Context, req InitializeRequest) (*InitializeResponse, error) {
	var raw json.RawMessage
	if err := c.conn.call(ctx, "initialize", req, &raw); err != nil {
		return nil, err
	}
	var resp InitializeResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		return nil, err
	}
	var caps struct {
		AgentCapabilities struct {
			SessionCapabilities struct {
				Fork json.RawMessage `json:"fork"`
			} `json:"sessionCapabilities"`
		} `json:"agentCapabilities"`
	}
	json.Unmarshal(raw, &caps)
	fork := caps.AgentCapabilities.SessionCapabilities.Fork
	c.canFork = len(fork) > 0 && string(fork) != "null"
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

func (c *Client) NewSession(ctx context.Context, req NewSessionRequest) (*NewSessionResponse, error) {
	var resp NewSessionResponse
	return &resp, c.conn.call(ctx, "session/new", req, &resp)
}

// LoadSession reopens a session; the agent replays its history as session
// updates before answering.
func (c *Client) LoadSession(ctx context.Context, req LoadSessionRequest) (*LoadSessionResponse, error) {
	var resp LoadSessionResponse
	return &resp, c.conn.call(ctx, "session/load", req, &resp)
}

func (c *Client) Prompt(ctx context.Context, req PromptRequest) (*PromptResult, error) {
	var resp PromptResult
	return &resp, c.conn.call(ctx, "session/prompt", req, &resp)
}

// Cancel asks the agent to stop the session's running turn, whose prompt
// then ends with stop reason "cancelled".
func (c *Client) Cancel(req CancelNotification) error {
	return c.conn.notify("session/cancel", req)
}

func (c *Client) SetConfigOption(ctx context.Context, req SetSessionConfigOptionRequest) (*SetSessionConfigOptionResponse, error) {
	var resp SetSessionConfigOptionResponse
	return &resp, c.conn.call(ctx, "session/set_config_option", req, &resp)
}

func (c *Client) SetMode(ctx context.Context, req SetSessionModeRequest) error {
	return c.conn.call(ctx, "session/set_mode", req, nil)
}

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
}

// Client is a connection to one agent.
type Client struct {
	conn *conn
	cmd  *exec.Cmd
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
	var resp InitializeResponse
	return &resp, c.conn.call(ctx, "initialize", req, &resp)
}

func (c *Client) NewSession(ctx context.Context, req NewSessionRequest) (*NewSessionResponse, error) {
	var resp NewSessionResponse
	return &resp, c.conn.call(ctx, "session/new", req, &resp)
}

func (c *Client) Prompt(ctx context.Context, req PromptRequest) (*PromptResponse, error) {
	var resp PromptResponse
	return &resp, c.conn.call(ctx, "session/prompt", req, &resp)
}

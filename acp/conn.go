package acp

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"runtime/debug"
	"strconv"
	"sync"
	"time"
)

func (e *Error) Error() string { return fmt.Sprintf("acp error %d: %s", e.Code, e.Message) }

// ErrMethodNotFound answers a request for a method this side doesn't serve.
var ErrMethodNotFound = &Error{Code: -32601, Message: "method not found"}

type frame struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *Error          `json:"error,omitempty"`
}

// handleFunc answers one request or notification from the other side. For a
// notification the result is ignored.
type handleFunc func(ctx context.Context, method string, params json.RawMessage) (any, error)

// MaxFrame is the largest message this side writes, kept below what
// agents read in one line (claude-agent-acp's SDK: 32 MiB, past which it
// ends the connection).
const MaxFrame = 30 << 20

// ErrTooLarge is a message over MaxFrame, which isn't written.
var ErrTooLarge = errors.New("the message is too large to send to the agent")

// conn is a JSON-RPC 2.0 connection over newline-delimited JSON. Lines read
// have no size limit, and nothing is queued or dropped: notifications are
// handled in order on the reading goroutine, so a slow handler slows the
// reader. Requests from the other side are handled on their own goroutines,
// after every notification that arrived before them; their context ends with
// the connection, or when the other side withdraws them ($/cancel_request).
type conn struct {
	w      io.Writer
	handle handleFunc
	log    *slog.Logger
	junk   int             // lines read that weren't JSON-RPC (on the reading goroutine)
	ctx    context.Context //nolint:containedctx // the connection's own: requests from the other side end with it
	cancel context.CancelFunc

	writeMu sync.Mutex
	mu      sync.Mutex
	nextID  int64
	pending map[string]chan frame
	// incoming cancels the other side's requests being handled, by id.
	incoming map[string]context.CancelFunc
	err      error         // set once the read side ends
	done     chan struct{} // closed with err
}

func newConn(r io.Reader, w io.Writer, log *slog.Logger, handle handleFunc) *conn {
	c := makeConn(w, log, handle)
	go c.read(r)
	return c
}

// makeConn makes a connection that reads nothing until read runs.
func makeConn(w io.Writer, log *slog.Logger, handle handleFunc) *conn {
	c := &conn{w: w, handle: handle, log: log, pending: map[string]chan frame{}, incoming: map[string]context.CancelFunc{}, done: make(chan struct{})}
	c.ctx, c.cancel = context.WithCancel(context.Background())
	return c
}

func (c *conn) read(r io.Reader) {
	br := bufio.NewReader(r)
	var err error
	for {
		var line []byte
		line, err = br.ReadBytes('\n')
		if len(bytes.TrimSpace(line)) > 0 {
			c.dispatch(line)
		}
		if err != nil {
			break
		}
	}
	if errors.Is(err, io.EOF) {
		err = io.ErrUnexpectedEOF
	}
	if c.junk > maxJunk {
		c.log.Warn("lines that weren't JSON-RPC", "lines", c.junk)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.err = fmt.Errorf("agent connection closed: %w", err)
	c.cancel()
	close(c.done) // before the calls fail, so a failed call can tell why
	for id, ch := range c.pending {
		close(ch)
		delete(c.pending, id)
	}
}

//nolint:contextcheck // requests from the other side end with the connection
func (c *conn) dispatch(line []byte) {
	var f frame
	if err := json.Unmarshal(line, &f); err != nil {
		// Not JSON-RPC: agents sometimes log to stdout. Its size only:
		// it may be anything.
		if c.junk++; c.junk <= maxJunk {
			c.log.Warn("a line that isn't JSON-RPC", "bytes", len(line), "err", err)
		}
		return
	}
	switch {
	case f.Method == "" && f.ID != nil: // a response
		c.mu.Lock()
		ch := c.pending[string(f.ID)]
		delete(c.pending, string(f.ID))
		c.mu.Unlock()
		if ch != nil {
			ch <- f
		}
	case f.ID == nil && f.Method == "$/cancel_request":
		c.withdrawn(f.Params)
	case f.ID == nil: // a notification
		switch _, err := c.safeHandle(c.ctx, f.Method, f.Params); {
		case errors.Is(err, ErrMethodNotFound): // an extension this side doesn't follow
			c.log.Debug("acp notification ignored", "rpc", f.Method)
		case err != nil:
			c.log.Warn("acp notification failed", "rpc", f.Method, "err", err)
		case f.Method != "session/update": // each chunk of a reply is one
			c.log.Debug("acp notification", "rpc", f.Method)
		}
	default: // a request
		ctx, cancel := context.WithCancel(c.ctx)
		key := string(bytes.TrimSpace(f.ID))
		c.mu.Lock()
		c.incoming[key] = cancel
		c.mu.Unlock()
		go func() {
			defer func() {
				c.mu.Lock()
				delete(c.incoming, key)
				c.mu.Unlock()
				cancel()
			}()
			start := time.Now()
			result, err := c.safeHandle(ctx, f.Method, f.Params)
			c.logged("acp request from the agent", f.Method, time.Since(start), err)
			reply := frame{JSONRPC: "2.0", ID: f.ID}
			if err != nil {
				var rpcErr *Error
				if !errors.As(err, &rpcErr) {
					rpcErr = &Error{Code: -32603, Message: err.Error()}
				}
				reply.Error = rpcErr
			} else if reply.Result, err = json.Marshal(result); err != nil {
				reply.Error = &Error{Code: -32603, Message: err.Error()}
			}
			_ = c.write(reply)
		}()
	}
}

// withdrawn ends the context of a request the other side withdrew: an
// agent may stop waiting for an answer (another one came, or the work it
// was for ended) without cancelling the turn.
func (c *conn) withdrawn(params json.RawMessage) {
	var p struct {
		RequestID json.RawMessage `json:"requestId"`
	}
	if json.Unmarshal(params, &p) != nil {
		return
	}
	c.mu.Lock()
	cancel := c.incoming[string(bytes.TrimSpace(p.RequestID))]
	c.mu.Unlock()
	if cancel != nil {
		cancel()
	}
}

// safeHandle runs the handler, turning a panic (a handler choking on what
// the agent sent) into an error, so one bad message can't take the process
// down; the panic is logged with its stack.
func (c *conn) safeHandle(ctx context.Context, method string, params json.RawMessage) (result any, err error) {
	defer func() {
		if p := recover(); p != nil {
			err = fmt.Errorf("handling %s: %v", method, p)
			c.log.Error("acp handler panicked", "rpc", method, "panic", fmt.Sprint(p), "stack", string(debug.Stack()))
		}
	}()
	return c.handle(ctx, method, params)
}

func (c *conn) write(f frame) error {
	b, err := json.Marshal(f)
	if err != nil {
		return err
	}
	if len(b) >= MaxFrame {
		return ErrTooLarge
	}
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_, err = c.w.Write(append(b, '\n'))
	return err
}

// call sends a request and decodes its result into result (unless nil).
func (c *conn) call(ctx context.Context, method string, params, result any) error {
	wait, err := c.send(method, params)
	if err != nil {
		return err
	}
	return wait(ctx, result)
}

// send writes a request and returns once it is written; wait then waits
// for its result and decodes it into result (unless nil).
func (c *conn) send(method string, params any) (wait func(ctx context.Context, result any) error, err error) {
	p, err := json.Marshal(params)
	if err != nil {
		return nil, err
	}
	ch := make(chan frame, 1)
	c.mu.Lock()
	if c.err != nil {
		c.mu.Unlock()
		return nil, c.err
	}
	c.nextID++
	id := json.RawMessage(strconv.FormatInt(c.nextID, 10))
	c.pending[string(id)] = ch
	c.mu.Unlock()

	start := time.Now()
	if err := c.write(frame{JSONRPC: "2.0", ID: id, Method: method, Params: p}); err != nil {
		c.forget(id)
		err = fmt.Errorf("%s: %w", method, err)
		c.logged("acp call", method, 0, err)
		return nil, err
	}
	return func(ctx context.Context, result any) error {
		err := c.await(ctx, method, id, ch, result)
		c.logged("acp call", method, time.Since(start), err)
		return err
	}, nil
}

// Slow is how long a call or a request from the agent takes before it is
// logged as slow. A prompt (a turn) and a request for the user's answer
// take as long as they take.
var Slow = 5 * time.Second

// mayTakeLong are those methods.
var mayTakeLong = map[string]bool{"session/prompt": true, "session/request_permission": true, "elicitation/create": true}

// maxJunk is how many lines that aren't JSON-RPC are logged one by one;
// the rest are counted when the connection ends.
const maxJunk = 5

// logged logs a call or a request from the agent once it ended: a failure
// with the error (the agent's own, for a call), a slow one, and at DEBUG
// every one, with how long it took; never what it carried.
func (c *conn) logged(what, method string, took time.Duration, err error) {
	took = took.Round(time.Millisecond)
	switch {
	case err != nil && !errors.Is(err, context.Canceled):
		c.log.Warn(what+" failed", "rpc", method, "took", took, "err", err)
	case took >= Slow && !mayTakeLong[method]:
		c.log.Warn(what+" slow", "rpc", method, "took", took)
	default:
		c.log.Debug(what, "rpc", method, "took", took)
	}
}

func (c *conn) await(ctx context.Context, method string, id json.RawMessage, ch chan frame, result any) error {
	select {
	case f, ok := <-ch:
		if !ok {
			return fmt.Errorf("%s: %w", method, c.err)
		}
		if f.Error != nil {
			return fmt.Errorf("%s: %w", method, f.Error)
		}
		if result == nil {
			return nil
		}
		return json.Unmarshal(f.Result, result)
	case <-ctx.Done():
		c.forget(id)
		return &gaveUpError{ctx.Err(), id}
	}
}

// gaveUpError is a call whose context ended before its answer came: the id it
// went out under, which $/cancel_request names to withdraw it.
type gaveUpError struct {
	error
	id json.RawMessage
}

func (g *gaveUpError) Unwrap() error { return g.error }

func withdrawable(err error) json.RawMessage {
	if g, ok := errors.AsType[*gaveUpError](err); ok {
		return g.id
	}
	return nil
}

func (c *conn) forget(id json.RawMessage) {
	c.mu.Lock()
	delete(c.pending, string(id))
	c.mu.Unlock()
}

func (c *conn) notify(method string, params any) error {
	p, err := json.Marshal(params)
	if err != nil {
		return err
	}
	return c.write(frame{JSONRPC: "2.0", Method: method, Params: p})
}

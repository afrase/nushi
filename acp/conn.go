package acp

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strconv"
	"sync"
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

// conn is a JSON-RPC 2.0 connection over newline-delimited JSON. Lines have
// no size limit, and nothing is queued or dropped: notifications are handled
// in order on the reading goroutine, so a slow handler slows the reader.
// Requests from the other side are handled on their own goroutines, after
// every notification that arrived before them.
type conn struct {
	w      io.Writer
	handle handleFunc

	writeMu sync.Mutex
	mu      sync.Mutex
	nextID  int64
	pending map[string]chan frame
	err     error         // set once the read side ends
	done    chan struct{} // closed with err
}

func newConn(r io.Reader, w io.Writer, handle handleFunc) *conn {
	c := &conn{w: w, handle: handle, pending: map[string]chan frame{}, done: make(chan struct{})}
	go c.read(r)
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
	c.mu.Lock()
	c.err = fmt.Errorf("agent connection closed: %w", err)
	for id, ch := range c.pending {
		close(ch)
		delete(c.pending, id)
	}
	c.mu.Unlock()
	close(c.done)
}

func (c *conn) dispatch(line []byte) {
	var f frame
	if err := json.Unmarshal(line, &f); err != nil {
		return // not JSON-RPC; agents sometimes log to stdout
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
	case f.ID == nil: // a notification
		_, _ = c.handle(context.Background(), f.Method, f.Params)
	default: // a request
		go func() {
			result, err := c.handle(context.Background(), f.Method, f.Params)
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

func (c *conn) write(f frame) error {
	b, err := json.Marshal(f)
	if err != nil {
		return err
	}
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_, err = c.w.Write(append(b, '\n'))
	return err
}

// call sends a request and decodes its result into result (unless nil).
func (c *conn) call(ctx context.Context, method string, params, result any) error {
	p, err := json.Marshal(params)
	if err != nil {
		return err
	}
	ch := make(chan frame, 1)
	c.mu.Lock()
	if c.err != nil {
		c.mu.Unlock()
		return c.err
	}
	c.nextID++
	id := json.RawMessage(strconv.FormatInt(c.nextID, 10))
	c.pending[string(id)] = ch
	c.mu.Unlock()

	if err := c.write(frame{JSONRPC: "2.0", ID: id, Method: method, Params: p}); err != nil {
		c.forget(id)
		return fmt.Errorf("%s: %w", method, err)
	}
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
		return ctx.Err()
	}
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

package acp

import (
	"context"
	"encoding/json"
	"io"
)

// Peer is the agent's side of a connection, for an agent Nushi brings
// itself (its Ante bridge): it answers the client's requests and
// notifications with handle, as conn does (notifications in order,
// requests each on its own goroutine), and calls and notifies the client.
type Peer struct{ conn *conn }

// NewPeer makes the agent's side of a connection that writes to w; it
// reads nothing until Serve.
func NewPeer(w io.Writer, handle func(ctx context.Context, method string, params json.RawMessage) (any, error)) *Peer {
	return &Peer{conn: makeConn(w, handle)}
}

// Serve reads the client's messages from r, until r ends.
func (p *Peer) Serve(r io.Reader) { go p.conn.read(r) }

// Call sends the client a request and decodes its result into result
// (unless nil).
func (p *Peer) Call(ctx context.Context, method string, params, result any) error {
	return p.conn.call(ctx, method, params, result)
}

// Notify sends the client a notification.
func (p *Peer) Notify(method string, params any) error { return p.conn.notify(method, params) }

// Done is closed when the client's side of the connection ends.
func (p *Peer) Done() <-chan struct{} { return p.conn.done }

// Call sends the agent a request for one of its extensions (a method
// starting "_") and decodes its result into result (unless nil).
func (c *Client) Call(ctx context.Context, method string, params, result any) error {
	return c.conn.call(ctx, method, params, result)
}

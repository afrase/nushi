package relay

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// KeepAlive is how often a client pings the relay; a client that hears
// nothing back for three times as long drops the connection.
var KeepAlive = 25 * time.Second

// Dialer connects to a relay.
type Dialer struct {
	// Proxies names the proxies to try for a URL, in order; a nil entry is
	// a direct connection. Nil connects directly.
	Proxies func(*url.URL) ([]*url.URL, error)
}

// Listen waits at id for a dialer; the connection's first ReadMessage
// returns the dialer's first message.
func (d *Dialer) Listen(ctx context.Context, relay, id string) (*Conn, error) {
	return d.connect(ctx, relay, "listen", id)
}

// Dial meets the listener waiting at id.
func (d *Dialer) Dial(ctx context.Context, relay, id string) (*Conn, error) {
	return d.connect(ctx, relay, "dial", id)
}

func (d *Dialer) connect(ctx context.Context, relay, side, id string) (*Conn, error) {
	u, err := url.Parse(relay)
	if err != nil || (u.Scheme != "ws" && u.Scheme != "wss") || u.Host == "" {
		return nil, fmt.Errorf("the relay %q isn't a ws:// or wss:// URL", relay)
	}
	u = u.JoinPath("v1", side, id)
	proxies := []*url.URL{nil}
	if d.Proxies != nil {
		if proxies, err = d.Proxies(u); err != nil {
			return nil, err
		}
	}
	var errs []error
	for _, p := range proxies {
		wd := websocket.Dialer{Proxy: func(*http.Request) (*url.URL, error) { return p, nil }, HandshakeTimeout: 20 * time.Second}
		ws, resp, err := wd.DialContext(ctx, u.String(), nil)
		if err == nil {
			return newConn(ws), nil
		}
		if resp != nil {
			err = fmt.Errorf("the relay answered %s", resp.Status)
		}
		if p != nil {
			err = fmt.Errorf("through the proxy %s: %w", p.Redacted(), err)
		}
		errs = append(errs, err)
	}
	return nil, errors.Join(errs...)
}

// Conn is a connection to a relay, carrying binary messages to and from
// the peer. It keeps itself alive with pings.
type Conn struct {
	ws    *websocket.Conn
	wmu   sync.Mutex
	done  chan struct{}
	once  sync.Once
	first []byte
	every time.Duration
}

func newConn(ws *websocket.Conn) *Conn {
	every := KeepAlive
	c := &Conn{ws: ws, done: make(chan struct{}), every: every}
	alive := func() { _ = ws.SetReadDeadline(time.Now().Add(3 * every)) }
	alive()
	ws.SetPongHandler(func(string) error { alive(); return nil })
	go func() {
		t := time.NewTicker(every)
		defer t.Stop()
		for {
			select {
			case <-c.done:
				return
			case <-t.C:
				if ws.WriteControl(websocket.PingMessage, nil, time.Now().Add(every)) != nil {
					c.Close()
					return
				}
			}
		}
	}()
	return c
}

// Wait blocks until the peer's first message has come; ReadMessage then
// returns it.
func (c *Conn) Wait() error {
	m, err := c.ReadMessage()
	c.first = m
	return err
}

// ReadMessage returns the peer's next message.
func (c *Conn) ReadMessage() ([]byte, error) {
	if m := c.first; m != nil {
		c.first = nil
		return m, nil
	}
	kind, m, err := c.ws.ReadMessage()
	if err != nil {
		return nil, err
	}
	if kind != websocket.BinaryMessage {
		return nil, errors.New("relay: a message that isn't binary")
	}
	_ = c.ws.SetReadDeadline(time.Now().Add(3 * c.every))
	return m, nil
}

// WriteMessage sends one message to the peer.
func (c *Conn) WriteMessage(m []byte) error {
	c.wmu.Lock()
	defer c.wmu.Unlock()
	_ = c.ws.SetWriteDeadline(time.Now().Add(3 * c.every))
	return c.ws.WriteMessage(websocket.BinaryMessage, m)
}

func (c *Conn) Close() error {
	c.once.Do(func() { close(c.done) })
	return c.ws.Close()
}

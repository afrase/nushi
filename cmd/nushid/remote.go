package main

import "net"

// channels is a net.Listener fed by remote access: each paired device's
// channel, for the API's second server.
type channels struct {
	conns chan net.Conn
	done  chan struct{}
}

func newChannels() *channels { return &channels{conns: make(chan net.Conn), done: make(chan struct{})} }

func (c *channels) serve(conn net.Conn) {
	select {
	case c.conns <- conn:
	case <-c.done:
		_ = conn.Close() // the daemon is stopping
	}
}

func (c *channels) Accept() (net.Conn, error) {
	select {
	case conn := <-c.conns:
		return conn, nil
	case <-c.done:
		return nil, net.ErrClosed
	}
}

func (c *channels) Close() error {
	select {
	case <-c.done:
	default:
		close(c.done)
	}
	return nil
}

func (c *channels) Addr() net.Addr { return &net.UnixAddr{Name: "noise", Net: "noise"} }

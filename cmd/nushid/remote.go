package main

import (
	"log/slog"
	"net"
	"os"
	"os/exec"
	"strconv"
)

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
		conn.Close()
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

// keepAwake keeps the Mac from idle sleep while remote access is on:
// caffeinate, which ends with the daemon too.
func keepAwake() (stop func()) {
	cmd := exec.Command("/usr/bin/caffeinate", "-i", "-w", strconv.Itoa(os.Getpid())) //nolint:gosec,noctx // caffeinate with our pid, until stop
	if err := cmd.Start(); err != nil {
		slog.Warn("keeping the Mac awake", "err", err)
		return func() {}
	}
	go cmd.Wait()
	return func() { cmd.Process.Kill() }
}

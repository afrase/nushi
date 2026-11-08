package relay

import (
	"context"
	"encoding/binary"
	"io"
	"net"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"testing"
)

// socks5Proxy is a SOCKS5 proxy without auth that sends every host to
// 127.0.0.1 (the port kept), noting the host names it was asked for.
func socks5Proxy(t *testing.T) (string, func() []string) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ln.Close() })
	var mu sync.Mutex
	var seen []string
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			go func() {
				defer func() { _ = c.Close() }()
				host, port, ok := socks5Handshake(c)
				if !ok {
					return
				}
				mu.Lock()
				seen = append(seen, host)
				mu.Unlock()
				target, err := net.Dial("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(port)))
				if err != nil {
					return
				}
				defer func() { _ = target.Close() }()
				_, _ = c.Write([]byte{5, 0, 0, 1, 0, 0, 0, 0, 0, 0})
				go func() { _, _ = io.Copy(target, c) }()
				_, _ = io.Copy(c, target)
			}()
		}
	}()
	return ln.Addr().String(), func() []string { mu.Lock(); defer mu.Unlock(); return append([]string(nil), seen...) }
}

// socks5Handshake reads a no-auth greeting and a CONNECT to a host name.
func socks5Handshake(c net.Conn) (host string, port int, ok bool) {
	head := make([]byte, 2)
	if _, err := io.ReadFull(c, head); err != nil || head[0] != 5 {
		return "", 0, false
	}
	if _, err := io.ReadFull(c, make([]byte, head[1])); err != nil {
		return "", 0, false
	}
	if _, err := c.Write([]byte{5, 0}); err != nil {
		return "", 0, false
	}
	req := make([]byte, 5) // version, CONNECT, reserved, type, name length
	if _, err := io.ReadFull(c, req); err != nil || req[1] != 1 || req[3] != 3 {
		return "", 0, false
	}
	rest := make([]byte, int(req[4])+2)
	if _, err := io.ReadFull(c, rest); err != nil {
		return "", 0, false
	}
	return string(rest[:req[4]]), int(binary.BigEndian.Uint16(rest[req[4]:])), true
}

// A socks5h proxy (curl's and ssh -D's name) carries the connection, the
// relay's host name resolved at the proxy.
func TestThroughASocks5hProxy(t *testing.T) {
	_, port, _ := net.SplitHostPort(strings.TrimPrefix(start(t, Defaults), "ws://"))
	relayURL := "ws://relay.test:" + port
	addr, seen := socks5Proxy(t)
	p := &url.URL{Scheme: "socks5h", Host: addr}
	dl := Dialer{Proxies: func(*url.URL) ([]*url.URL, error) { return []*url.URL{p}, nil }}
	key := newKey()
	l, err := dl.Listen(context.Background(), relayURL, key)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = l.Close() }()
	d, err := dl.Dial(context.Background(), relayURL, idOf(key))
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = d.Close() }()
	send(t, d, "hello")
	expect(t, l, "hello")
	if s := seen(); len(s) != 2 || s[0] != "relay.test" || s[1] != "relay.test" {
		t.Fatalf("the proxy saw %v", s)
	}
	if p.Scheme != "socks5h" {
		t.Errorf("the caller's URL changed: %s", p)
	}
}

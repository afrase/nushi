package main

import (
	"errors"
	"net"
	"net/http"
	"os"
	"syscall"
	"testing"
)

// On SIGTERM, as for a restart, the chats close while the socket still
// answers: an app that sees no daemon starts one, which mustn't reopen
// sessions the old daemon's agents are still ending.
func TestChatsCloseBeforeTheSocket(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	srv := &http.Server{Handler: http.NotFoundHandler()} //nolint:gosec // a test's loopback server
	stop := make(chan os.Signal, 1)
	stop <- syscall.SIGTERM
	answered := false
	why, err := serve(srv, ln, stop, nil, func() {
		if c, err := net.Dial("tcp", ln.Addr().String()); err == nil {
			answered = true
			_ = c.Close()
		}
	})
	if why != "SIGTERM" || !errors.Is(err, http.ErrServerClosed) {
		t.Errorf("serve = %q, %v", why, err)
	}
	if !answered {
		t.Error("the socket was gone before the chats closed")
	}
}

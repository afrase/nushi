package relay

import (
	"io"
	"log"
	"net"
	"net/http"
	"time"
)

// NewServer is the relay's HTTP server: New's handler, with timeouts and
// caps on connections that aren't WebSockets (yet), so idle keep-alive
// connections can't pile up. One waiting for its next request goes after
// HTTPIdle; they are counted apart from the WebSockets under the same
// caps, Total and PerIP by the TCP peer's address (behind a proxy, with
// IPHeader, only Total: every connection is the proxy's).
func NewServer(lim Limits) *http.Server {
	s := New(lim).(*server)
	return &http.Server{Handler: s, ConnState: s.connState,
		ReadHeaderTimeout: 10 * time.Second, ReadTimeout: 10 * time.Second, IdleTimeout: lim.HTTPIdle, MaxHeaderBytes: 8 << 10,
		ErrorLog: log.New(io.Discard, "", 0)} // its messages name clients' addresses
}

// connState counts a connection from its accept until it closes or becomes
// a WebSocket (which join counts), and closes one over the caps.
func (s *server) connState(c net.Conn, st http.ConnState) {
	s.mu.Lock()
	defer s.mu.Unlock()
	switch st {
	case http.StateNew:
		key := ""
		if s.lim.IPHeader == "" {
			key = keyOf(c.RemoteAddr().String())
		}
		if s.plain.total >= s.lim.Total || key != "" && s.plain.by[key] >= s.lim.PerIP {
			c.Close()
			return
		}
		s.plain.conns[c] = key
		s.plain.total++
		if key != "" {
			s.plain.by[key]++
		}
	case http.StateHijacked, http.StateClosed:
		key, ok := s.plain.conns[c]
		if !ok {
			return
		}
		delete(s.plain.conns, c)
		s.plain.total--
		if key != "" {
			if s.plain.by[key]--; s.plain.by[key] == 0 {
				delete(s.plain.by, key)
			}
		}
	}
}

// plain counts the connections that aren't WebSockets.
type plain struct {
	conns map[net.Conn]string // and their address's key
	by    map[string]int
	total int
}

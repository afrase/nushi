package relay

import (
	"context"
	"io"
	"log"
	"net"
	"net/http"
	"time"
)

// NewServer is the relay's HTTP server: New's handler, with timeouts and
// caps on plain connections (not WebSockets, or not yet), so idle ones
// can't pile up or crowd out the daemons and phones. A plain connection
// gets 5 s for its request's headers and waits HTTPIdle for the next one.
// Per address, at most PlainPerIP are open and new ones come at the
// WebSockets' rate; the address is the TCP peer's from the accept, or
// behind a proxy (IPHeader) the header's once a request has come. When
// Total are open, the one idle longest makes way for a new one.
func NewServer(lim Limits) *http.Server {
	s := New(lim).(*server)
	h := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !s.attribute(r) {
			w.Header().Set("Connection", "close")
			http.Error(w, "busy", http.StatusServiceUnavailable)
			return
		}
		s.ServeHTTP(w, r)
	})
	return &http.Server{Handler: h, ConnState: s.connState,
		ConnContext:       func(ctx context.Context, c net.Conn) context.Context { return context.WithValue(ctx, connKey{}, c) },
		ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, IdleTimeout: lim.HTTPIdle, MaxHeaderBytes: 8 << 10,
		ErrorLog: log.New(io.Discard, "", 0)} // its messages name clients' addresses
}

type connKey struct{}

// plain counts the plain connections.
type plain struct {
	conns map[net.Conn]*plainConn
	by    map[string]*source // per address: conns open and the rate
	swept time.Time
}

type plainConn struct {
	key   string    // its address's, once known
	idle  bool      // waiting for a request: new, or between two
	since time.Time // when it began to wait
}

// connState counts a connection from its accept until it closes or becomes
// a WebSocket (which join counts).
func (s *server) connState(c net.Conn, st http.ConnState) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	pc := s.plain.conns[c]
	switch st {
	case http.StateNew:
		key := ""
		if s.lim.IPHeader == "" {
			key = keyOf(c.RemoteAddr().String())
			if !s.admitPlain(key, now) {
				c.Close()
				return
			}
		}
		if len(s.plain.conns) >= s.lim.Total && !s.shed() {
			s.unPlain(key, now)
			c.Close()
			return
		}
		s.plain.conns[c] = &plainConn{key: key, idle: true, since: now}
	case http.StateActive:
		if pc != nil {
			pc.idle = false
		}
	case http.StateIdle:
		if pc != nil {
			pc.idle, pc.since = true, now
		}
	case http.StateHijacked, http.StateClosed:
		if pc != nil {
			delete(s.plain.conns, c)
			s.unPlain(pc.key, now)
		}
	}
}

// attribute counts r's connection under the header's address, behind a
// proxy; it says no when that address is over its caps.
func (s *server) attribute(r *http.Request) bool {
	if s.lim.IPHeader == "" {
		return true
	}
	c, _ := r.Context().Value(connKey{}).(net.Conn)
	key := s.sourceKey(r)
	s.mu.Lock()
	defer s.mu.Unlock()
	pc := s.plain.conns[c]
	if pc == nil || pc.key == key {
		return true
	}
	now := time.Now()
	if !s.admitPlain(key, now) {
		return false
	}
	if pc.key != "" {
		s.unPlain(pc.key, now)
	}
	pc.key = key
	return true
}

// admitPlain counts a plain connection from key, within its caps. Called
// with s.mu.
func (s *server) admitPlain(key string, now time.Time) bool {
	if now.Sub(s.plain.swept) > time.Minute {
		s.plain.swept = now
		for k, src := range s.plain.by {
			if s.refill(src, now); src.conns == 0 && src.tokens >= s.lim.NewBurst {
				delete(s.plain.by, k)
			}
		}
	}
	src := s.plain.by[key]
	if src == nil {
		src = &source{tokens: s.lim.NewBurst, last: now}
		s.plain.by[key] = src
	}
	if s.refill(src, now); src.tokens < 1 || src.conns >= s.lim.PlainPerIP {
		return false
	}
	src.tokens--
	src.conns++
	return true
}

// unPlain uncounts a plain connection from key. Called with s.mu.
func (s *server) unPlain(key string, now time.Time) {
	src := s.plain.by[key]
	if key == "" || src == nil {
		return
	}
	if src.conns--; src.conns == 0 {
		if s.refill(src, now); src.tokens >= s.lim.NewBurst {
			delete(s.plain.by, key)
		}
	}
}

// shed closes the plain connection idle longest, if one is idle. Called
// with s.mu.
func (s *server) shed() bool {
	var oldest net.Conn
	for c, pc := range s.plain.conns {
		if pc.idle && (oldest == nil || pc.since.Before(s.plain.conns[oldest].since)) {
			oldest = c
		}
	}
	if oldest == nil {
		return false
	}
	s.unPlain(s.plain.conns[oldest].key, time.Now())
	delete(s.plain.conns, oldest)
	oldest.Close()
	return true
}

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
// caps on plain connections (not WebSockets, or not yet), so idle or slow
// ones can't pile up or crowd out the daemons and phones. A new connection
// gets FirstWait for its first request's headers, a later request 5 s, and
// it waits HTTPIdle between requests. Per address, at most PlainPerIP are
// open and new ones come at the WebSockets' rate; the address is the TCP
// peer's from the accept, or behind a proxy (IPHeader) the header's once a
// request has come. New connections that haven't sent a request yet have
// a budget of their own, a tenth of Total: when it's spent, the oldest of
// them makes way for a new one. When Total are open, the oldest of them
// does, else the one idle longest.
func NewServer(lim Limits) *http.Server {
	s := New(lim).(*server) //nolint:forcetypeassert // New makes one
	h := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !s.served(r) {
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
	fresh int                // conns without a request yet
	swept time.Time
}

type plainConn struct {
	key   string      // its address's, once known
	idle  bool        // waiting for a request: new, or between two
	since time.Time   // when it was accepted, or began to wait
	fresh *time.Timer // until its first request: closes it after FirstWait
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
				_ = c.Close()
				return
			}
		}
		if s.plain.fresh >= max(1, s.lim.Total/10) {
			s.shed(true) // the oldest without a request makes way
		}
		if len(s.plain.conns) >= s.lim.Total && !s.shed(true) && !s.shed(false) {
			s.unPlain(key, now)
			_ = c.Close()
			return
		}
		pc := &plainConn{key: key, idle: true, since: now}
		pc.fresh = time.AfterFunc(s.lim.FirstWait, func() { s.late(c, pc) })
		s.plain.conns[c] = pc
		s.plain.fresh++
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
			s.drop(c)
		}
	}
}

// drop uncounts plain connection c. Called with s.mu.
func (s *server) drop(c net.Conn) {
	pc := s.plain.conns[c]
	delete(s.plain.conns, c)
	s.unFresh(pc)
	s.unPlain(pc.key, time.Now())
}

func (s *server) unFresh(pc *plainConn) {
	if pc.fresh != nil {
		pc.fresh.Stop()
		pc.fresh = nil
		s.plain.fresh--
	}
}

// late closes c if it hasn't sent a request within FirstWait.
func (s *server) late(c net.Conn, pc *plainConn) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.plain.conns[c] == pc && pc.fresh != nil {
		s.drop(c)
		_ = c.Close()
	}
}

// served counts r's connection as one that has sent a request and, behind
// a proxy, under the header's address; it says no when that address is
// over its caps.
func (s *server) served(r *http.Request) bool {
	c, _ := r.Context().Value(connKey{}).(net.Conn)
	s.mu.Lock()
	defer s.mu.Unlock()
	pc := s.plain.conns[c]
	if pc == nil {
		return true
	}
	s.unFresh(pc)
	key := s.sourceKey(r)
	if s.lim.IPHeader == "" || pc.key == key {
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

// shed closes the oldest plain connection without a request yet (fresh),
// idle or still sending its headers, or else the one idle longest; it says
// whether there was one. Called with s.mu.
func (s *server) shed(fresh bool) bool {
	var oldest net.Conn
	for c, pc := range s.plain.conns {
		if (fresh && pc.fresh != nil || !fresh && pc.idle) && (oldest == nil || pc.since.Before(s.plain.conns[oldest].since)) {
			oldest = c
		}
	}
	if oldest == nil {
		return false
	}
	s.drop(oldest)
	_ = oldest.Close()
	return true
}

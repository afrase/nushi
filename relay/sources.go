package relay

import (
	"crypto/rand"
	"crypto/sha256"
	"net"
	"net/http"
	"net/netip"
	"strings"
	"time"
)

// source is what the relay holds about one client address, so one address
// can't take every connection: counters only, under a keyed hash of the
// address (never the address), dropped once nothing is counted.
type source struct {
	conns  int
	tokens float64 // new connections it may still open at once
	last   time.Time
}

// salt keys the hash, fresh each start.
var salt = func() []byte {
	b := make([]byte, 32)
	rand.Read(b)
	return b
}()

// sourceKey is the hash of the client's address: an IPv4 address, or an
// IPv6 address's /64 (one home or phone has a whole /64). Behind a reverse
// proxy the address comes from the header Limits.IPHeader names, when the
// request came through one of TrustedProxies. A proxy appends to a list
// header such as X-Forwarded-For, after whatever the client wrote there, so
// the address is the IPHops-th from the right.
func (s *server) sourceKey(r *http.Request) string {
	return keyOf(s.clientAddr(r), 64)
}

// netKey is the hash of the client's address as listeners, and all
// WebSockets together (PerNet), are counted: an IPv4 address, or an IPv6
// address's /48, which one home or one rented server often has whole, so
// a /56 of /64s can't take every listener or connection. It is the same
// address as sourceKey's, so a peer that isn't a trusted proxy can't
// spread its connections over made-up addresses.
func (s *server) netKey(r *http.Request) string {
	return keyOf(s.clientAddr(r), 48)
}

// clientAddr is the client's address, as sourceKey says: the header's
// only from a trusted proxy, else the TCP peer's.
func (s *server) clientAddr(r *http.Request) string {
	if !s.proxied(r.RemoteAddr) {
		return r.RemoteAddr
	}
	var addrs []string
	for _, v := range r.Header.Values(s.lim.IPHeader) {
		for a := range strings.SplitSeq(v, ",") {
			addrs = append(addrs, strings.TrimSpace(a))
		}
	}
	hops := max(1, s.lim.IPHops)
	if len(addrs) < hops {
		return "" // not through the proxies said
	}
	return addrs[len(addrs)-hops]
}

// proxied says whether a peer at addr is a proxy whose IPHeader the relay
// believes: one of TrustedProxies, or with none named a loopback address
// (a proxy on the same machine). Anyone else could write any address there.
func (s *server) proxied(addr string) bool {
	if s.lim.IPHeader == "" {
		return false
	}
	ap, err := netip.ParseAddrPort(addr)
	if err != nil {
		return false
	}
	ip := ap.Addr().Unmap()
	if s.lim.TrustedProxies == nil {
		return ip.IsLoopback()
	}
	for _, p := range s.lim.TrustedProxies {
		if p.Contains(ip) {
			return true
		}
	}
	return false
}

// keyOf is the hash of an address (with or without a port), an IPv6 one
// cut to its first v6bits.
func keyOf(addr string, v6bits int) string {
	if host, _, err := net.SplitHostPort(addr); err == nil {
		addr = host
	}
	ip := net.ParseIP(addr)
	if ip == nil {
		ip = net.IPv6zero // all unparseable addresses share one count
	}
	if v4 := ip.To4(); v4 != nil {
		ip = v4
	} else {
		ip = ip.Mask(net.CIDRMask(v6bits, 128))
	}
	h := sha256.Sum256(append(append([]byte(nil), salt...), ip...))
	return string(h[:16])
}

// sources is the relay's sources of one kind of connection (WebSockets,
// or plain ones), by key, each with its connections open and a bucket of
// new ones at lim's rate (ADR 0033).
type sources struct {
	lim   Limits
	by    map[string]*source
	swept time.Time
}

// newSources holds none yet, at lim's rate.
func newSources(lim Limits) sources { return sources{lim: lim, by: map[string]*source{}} }

// admit counts a new connection from key, or says why not: the address
// opens connections too fast (429), or holds limit already (503). Called
// with the server's mu.
func (ss *sources) admit(key string, now time.Time, limit int) int {
	if now.Sub(ss.swept) > time.Minute {
		ss.swept = now
		for k, src := range ss.by {
			if ss.refill(src, now); src.conns == 0 && src.tokens >= ss.lim.NewBurst {
				delete(ss.by, k)
			}
		}
	}
	src := ss.by[key]
	if src == nil {
		src = &source{tokens: ss.lim.NewBurst, last: now}
		ss.by[key] = src
	}
	ss.refill(src, now)
	switch {
	case src.tokens < 1:
		return http.StatusTooManyRequests
	case src.conns >= limit:
		return http.StatusServiceUnavailable
	}
	src.tokens--
	src.conns++
	return 0
}

// refill adds the tokens src earned since it was last looked at.
func (ss *sources) refill(src *source, now time.Time) {
	src.tokens = min(ss.lim.NewBurst, src.tokens+now.Sub(src.last).Seconds()*ss.lim.NewRate)
	src.last = now
}

// leave uncounts a connection from key, and forgets the address once
// nothing is counted. Called with the server's mu.
func (ss *sources) leave(key string, now time.Time) {
	src := ss.by[key]
	if src == nil {
		return
	}
	if src.conns--; src.conns == 0 {
		if ss.refill(src, now); src.tokens >= ss.lim.NewBurst {
			delete(ss.by, key)
		}
	}
}

// admitListener counts a new listener from key, or says it holds
// ListenPerIP already. Called with s.mu.
func (s *server) admitListener(key string) bool {
	if s.lim.ListenPerIP > 0 && s.listeners[key] >= s.lim.ListenPerIP {
		return false
	}
	s.listeners[key]++
	return true
}

// leaveListener uncounts a listener from key. Called with s.mu.
func (s *server) leaveListener(key string) {
	if s.listeners[key]--; s.listeners[key] <= 0 {
		delete(s.listeners, key)
	}
}

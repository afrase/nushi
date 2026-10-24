package relay

import (
	"crypto/rand"
	"crypto/sha256"
	"net"
	"net/http"
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
// proxy the address comes from the header Limits.IPHeader names. A proxy
// appends to a list header such as X-Forwarded-For, after whatever the
// client wrote there, so the address is the IPHops-th from the right.
func (s *server) sourceKey(r *http.Request) string {
	if s.lim.IPHeader == "" {
		return keyOf(r.RemoteAddr)
	}
	var addrs []string
	for _, v := range r.Header.Values(s.lim.IPHeader) {
		for a := range strings.SplitSeq(v, ",") {
			addrs = append(addrs, strings.TrimSpace(a))
		}
	}
	hops := max(1, s.lim.IPHops)
	if len(addrs) < hops {
		return keyOf("") // not through the proxies said
	}
	return keyOf(addrs[len(addrs)-hops])
}

// keyOf is the hash of an address (with or without a port).
func keyOf(addr string) string {
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
		ip = ip.Mask(net.CIDRMask(64, 128))
	}
	h := sha256.Sum256(append(append([]byte(nil), salt...), ip...))
	return string(h[:16])
}

// admitSource counts a new connection from key, or says why not: the
// address opens connections too fast, or holds too many. Called with s.mu.
func (s *server) admitSource(key string, now time.Time) int {
	if now.Sub(s.swept) > time.Minute {
		s.swept = now
		for k, src := range s.sources {
			if s.refill(src, now); src.conns == 0 && src.tokens >= s.lim.NewBurst {
				delete(s.sources, k)
			}
		}
	}
	src := s.sources[key]
	if src == nil {
		src = &source{tokens: s.lim.NewBurst, last: now}
		s.sources[key] = src
	}
	s.refill(src, now)
	switch {
	case src.tokens < 1:
		return http.StatusTooManyRequests
	case src.conns >= s.lim.PerIP:
		return http.StatusServiceUnavailable
	}
	src.tokens--
	src.conns++
	return 0
}

func (s *server) refill(src *source, now time.Time) {
	src.tokens = min(s.lim.NewBurst, src.tokens+now.Sub(src.last).Seconds()*s.lim.NewRate)
	src.last = now
}

// leaveSource uncounts a connection from key. Called with s.mu.
func (s *server) leaveSource(key string) {
	src := s.sources[key]
	if src == nil {
		return
	}
	if src.conns--; src.conns == 0 {
		if s.refill(src, time.Now()); src.tokens >= s.lim.NewBurst {
			delete(s.sources, key)
		}
	}
}

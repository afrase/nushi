package servers

import (
	"context"
	"fmt"
	"net/netip"
	"strconv"
	"strings"
)

// scan is how far past an entry's port autoPort looks for a free one, as
// Claude desktop does (docs/facts/claude.md).
const scan = 20

// pickPort finds the server its port and reserves it until the server
// answers or ends, so two starts never take one port. With autoPort true
// or unset, the entry's port or the first free one up to scan past it;
// with autoPort false, the entry's or none.
//
// A port is taken when a connection to 127.0.0.1 or ::1 on it is, not
// when a probe can't listen on it: Go's net.Listen sets SO_REUSEADDR, and
// macOS then lets it bind beside another process's listener that a
// connection to localhost reaches. Seen on macOS 27 (2026-11-06), a probe
// bound with the other process on 0.0.0.0:p and the probe on 127.0.0.1:p
// or ":p"; on 127.0.0.1:p and the probe on ":p" or 0.0.0.0:p; on a
// dual-stack [::]:p and the probe on 127.0.0.1:p or [::1]:p; on [::1]:p
// and the probe on ":p", whatever the other socket's own SO_REUSEADDR. A
// dial connected in each case. Linux refuses those binds, but dialing is
// right on both.
func (s *Service) pickPort(ctx context.Context, sv *server) (int, error) {
	// The probes outlive the call: a probe cut short by its caller going
	// would read as a free port.
	ctx = context.WithoutCancel(ctx)
	e := sv.entry
	last := e.Port
	if e.AutoPort == nil || *e.AutoPort {
		last = min(e.Port+scan, 65535)
	}
	for p := e.Port; p <= last; p++ {
		s.mu.Lock()
		_, held := s.reserved[p]
		if !held {
			s.reserved[p] = sv.id
		}
		s.mu.Unlock()
		if held {
			continue
		}
		if dialLoopback(ctx, p) == "" {
			return p, nil
		}
		s.mu.Lock()
		delete(s.reserved, p)
		s.mu.Unlock()
	}
	if last == e.Port {
		return 0, fmt.Errorf("port %d is in use, and autoPort is false", e.Port)
	}
	return 0, fmt.Errorf("no free port from %d to %d", e.Port, last)
}

// loopback is localhost's addresses: a server may listen on either.
var loopback = []netip.Addr{netip.AddrFrom4([4]byte{127, 0, 0, 1}), netip.IPv6Loopback()}

// dialLoopback is the first of 127.0.0.1 and ::1 on which a connection to
// localhost's port is taken, as host:port, or "" when neither is.
func dialLoopback(ctx context.Context, port int) string {
	for _, a := range loopback {
		at := netip.AddrPortFrom(a, uint16(port)).String() //nolint:gosec // a port, 1 to 65535
		if dials(ctx, at) {
			return at
		}
	}
	return ""
}

// unreserve lets the server's port go from the reservations: it answers
// on it now.
func (s *Service) unreserve(sv *server) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.unreserveLocked(sv)
}

// unreserveLocked lets the server's port go. Called with s.mu.
func (s *Service) unreserveLocked(sv *server) {
	for p, id := range s.reserved {
		if id == sv.id {
			delete(s.reserved, p)
		}
	}
}

// withPort is args with the port each of --port N, -p N, --port=N and
// -p=N names made port; PORT carries it to a command that has none.
func withPort(args []string, port int) []string {
	out := make([]string, len(args))
	copy(out, args)
	n := strconv.Itoa(port)
	for i := 0; i < len(out); i++ {
		switch a := out[i]; {
		case (a == "--port" || a == "-p") && i+1 < len(out) && number(out[i+1]):
			out[i+1] = n
			i++
		case strings.HasPrefix(a, "--port=") && number(a[len("--port="):]):
			out[i] = "--port=" + n
		case strings.HasPrefix(a, "-p=") && number(a[len("-p="):]):
			out[i] = "-p=" + n
		}
	}
	return out
}

// number says whether s is a port's digits.
func number(s string) bool {
	_, err := strconv.Atoi(s)
	return err == nil && s != "" && !strings.HasPrefix(s, "-") && !strings.HasPrefix(s, "+")
}

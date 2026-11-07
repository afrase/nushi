package servers

import (
	"context"
	"fmt"
	"net"
	"net/netip"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/listeners"
)

// scan is how far past an entry's port autoPort looks for a free one, as
// Claude desktop does (docs/facts/claude.md).
const scan = 20

// pickPort finds the server its port and reserves it until the server
// answers or ends, so two starts never take one port. With autoPort true
// or unset, the entry's port or the first free one up to scan past it;
// with autoPort false, the entry's or none, naming who holds it.
//
// A port is taken when a connection to 127.0.0.1 or ::1 on it is: a probe
// that listens can be let in beside another program's listener
// (internal/listeners).
func (s *Service) pickPort(ctx context.Context, sv *server) (int, error) {
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
		if !taken(ctx, p) {
			return p, nil
		}
		s.mu.Lock()
		delete(s.reserved, p)
		s.mu.Unlock()
	}
	if last == e.Port {
		return 0, fmt.Errorf("port %d is in use%s, and autoPort is false", e.Port, s.holder(e.Port))
	}
	return 0, fmt.Errorf("no free port from %d to %d", e.Port, last)
}

// taken says whether a connection to localhost's port p is taken.
func taken(ctx context.Context, p int) bool {
	for _, host := range []string{"127.0.0.1", "::1"} {
		if dials(ctx, net.JoinHostPort(host, strconv.Itoa(p))) {
			return true
		}
	}
	return false
}

// holder names the program a connection to localhost's port reaches, as
// " by <name> (pid N)", or "" when it can't be told.
func (s *Service) holder(port int) string {
	if s.Listeners == nil {
		return ""
	}
	ls, err := s.Listeners()
	if err != nil {
		return ""
	}
	for _, a := range []netip.Addr{netip.AddrFrom4([4]byte{127, 0, 0, 1}), netip.IPv6Loopback()} {
		reach := listeners.Reaching(ls, netip.AddrPortFrom(a, uint16(port))) //nolint:gosec // a port, 1 to 65535
		if len(reach) == 0 {
			continue
		}
		pid := reach[0].Pid
		if args := s.Procs.Args(pid); len(args) > 0 && args[0] != "" {
			return fmt.Sprintf(" by %s (pid %d)", filepath.Base(args[0]), pid)
		}
		return fmt.Sprintf(" by pid %d", pid)
	}
	return ""
}

// unreserve lets the server's port go from the reservations: it answers
// on it now.
func (s *Service) unreserve(sv *server) {
	s.mu.Lock()
	defer s.mu.Unlock()
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

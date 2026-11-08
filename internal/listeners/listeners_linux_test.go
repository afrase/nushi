package listeners

import (
	"errors"
	"net"
	"os"
	"strconv"
	"syscall"
	"testing"

	"golang.org/x/sys/unix"

	"github.com/afrase/nushi/internal/testcheck"
)

// init gives the helper SO_REUSEPORT on Linux; the shared tests declare
// helperControl, which only this OS sets.
func init() { //nolint:gochecknoinits // a per-OS setting of the shared tests, which build everywhere
	helperControl = func(_, _ string, c syscall.RawConn) error {
		var err error
		if errC := c.Control(func(fd uintptr) {
			err = unix.SetsockoptInt(int(fd), unix.SOL_SOCKET, unix.SO_REUSEPORT, 1)
		}); errC != nil {
			return errC
		}
		return err
	}
}

// listenKind opens a listener of kind in this process, on port (0 for a
// free one).
func listenKind(t *testing.T, kind string, port int) (net.Listener, error) {
	t.Helper()
	k := kinds[kind]
	host, _, err := net.SplitHostPort(k[1])
	testcheck.NoErr(t, err)
	return net.Listen(k[0], net.JoinHostPort(host, strconv.Itoa(port)))
}

// TestSecondBindRefused keeps the package doc's Linux finding checked:
// beside a listener a connection to localhost reaches, a second one on
// an address that overlaps it is refused, Go's SO_REUSEADDR or not, so
// there is nothing for Reaching to tell apart unless both set
// SO_REUSEPORT (TestReachingTwoProcesses).
func TestSecondBindRefused(t *testing.T) {
	for _, c := range []struct{ first, second string }{
		{"ipv4", "dual"}, {"any4", "ipv4"}, {"dual", "ipv4"}, {"dual", "ipv6"}, {"any4", "dual"},
	} {
		first, err := listenKind(t, c.first, 0)
		testcheck.NoErr(t, err)
		port := first.Addr().(*net.TCPAddr).Port
		second, err := listenKind(t, c.second, port)
		if err == nil {
			_ = second.Close()
			t.Errorf("%s beside %s on port %d: bound", c.second, c.first, port)
		} else if !errors.Is(err, syscall.EADDRINUSE) {
			t.Errorf("%s beside %s: %v, want EADDRINUSE", c.second, c.first, err)
		}
		_ = first.Close()
	}
}

// /proc/net/tcp and tcp6, the fallback, list what sock_diag does, but for
// IPV6_V6ONLY, which only sock_diag tells.
func TestProcNetAgreesWithDiag(t *testing.T) {
	ports := map[uint16]string{}
	for kind := range kinds {
		l, err := listenKind(t, kind, 0)
		testcheck.NoErr(t, err)
		defer func() { _ = l.Close() }()
		ports[uint16(l.Addr().(*net.TCPAddr).Port)] = kind //nolint:gosec // a port
	}
	diag, err := diagListening()
	testcheck.NoErr(t, err)
	procNet, err := procNetListening()
	testcheck.NoErr(t, err)
	byPort := func(socks []inodeSocket) map[uint16]inodeSocket {
		m := map[uint16]inodeSocket{}
		for _, s := range socks {
			if _, ok := ports[s.Addr.Port()]; ok {
				m[s.Addr.Port()] = s
			}
		}
		return m
	}
	d, p := byPort(diag), byPort(procNet)
	for port, kind := range ports {
		ds, ok := d[port]
		ps := p[port]
		switch {
		case !ok:
			t.Errorf("%s: sock_diag didn't list port %d", kind, port)
		case ds.Addr != ps.Addr || ds.Inode != ps.Inode:
			t.Errorf("%s: sock_diag %+v, /proc/net %+v", kind, ds, ps)
		case ds.V6Only != (kind == "ipv6" || kind == "any6"):
			t.Errorf("%s: sock_diag says IPV6_V6ONLY %v", kind, ds.V6Only)
		}
	}
}

// A socket at two descriptors of a process is listed once.
func TestListOncePerProcess(t *testing.T) {
	l, err := listenKind(t, "ipv4", 0)
	testcheck.NoErr(t, err)
	defer func() { _ = l.Close() }()
	f, err := l.(*net.TCPListener).File() // a dup of its descriptor
	testcheck.NoErr(t, err)
	defer func() { _ = f.Close() }()
	port := uint16(l.Addr().(*net.TCPAddr).Port) //nolint:gosec // a port
	if got := ofPid(OnPort(list(t), port), os.Getpid()); len(got) != 1 {
		t.Fatalf("listed %v", got)
	}
}

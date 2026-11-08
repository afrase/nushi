//go:build cgo

package listeners

import (
	"context"
	"net"
	"net/netip"
	"slices"
	"strconv"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

// These tests check what is libproc's and macOS's own; the rest are in
// listeners_test.go.

// TestListReadsManyPerProcess lists every listener of a process holding
// more than fit at the first read.
func TestListReadsManyPerProcess(t *testing.T) {
	many := slices.Repeat([]string{"ipv4"}, 2*socksAtFirst+1)
	pid, ports := listenElsewhere(t, many...)
	ls, err := List()
	testcheck.NoErr(t, err)
	if got := ofPid(ls, pid); len(got) != len(ports) {
		t.Fatalf("listed %d of the helper's %d listeners", len(got), len(ports))
	}
}

// TestSockListener reads socket records (family, vflag, the kernel's
// address bytes, port). The first six are as libproc gave them on a Mac
// on 2026-11-06, for Go's five kinds of listener and JetBrains Toolbox's
// Java socket; the rest are made up, for what must be left out and a
// v4-mapped record kept as IPv6, which no socket showed.
func TestSockListener(t *testing.T) {
	v4 := func(a, b, c, d byte) [16]byte { return [16]byte{12: a, 13: b, 14: c, 15: d} }
	mapped := func(a, b, c, d byte) [16]byte { return [16]byte{10: 0xff, 11: 0xff, 12: a, 13: b, 14: c, 15: d} }
	for _, c := range []struct {
		name string
		s    sock
		want string // "" for left out
		dual bool
	}{
		{"IPv4 loopback", sock{syscall.AF_INET, iniIPv4, v4(127, 0, 0, 1), 55756}, "127.0.0.1:55756", false},
		{"IPv6 loopback", sock{syscall.AF_INET6, iniIPv6, [16]byte{15: 1}, 55759}, "[::1]:55759", false},
		{"IPv4 wildcard", sock{syscall.AF_INET, iniIPv4, [16]byte{}, 55760}, "0.0.0.0:55760", false},
		{"IPv6 wildcard, v6 only", sock{syscall.AF_INET6, iniIPv6, [16]byte{}, 55761}, "[::]:55761", false},
		{"IPv6 wildcard, dual-stack", sock{syscall.AF_INET6, iniIPv4 | iniIPv6, [16]byte{}, 55762}, "[::]:55762", true},
		// Java's: an IPv6 socket on a v4-mapped address, kept as IPv4.
		{"v4-mapped, kept as IPv4", sock{syscall.AF_INET6, iniIPv4, v4(127, 0, 0, 1), 57644}, "127.0.0.1:57644", false},
		{"v4-mapped, kept as IPv6", sock{syscall.AF_INET6, iniIPv6, mapped(127, 0, 0, 1), 57645}, "127.0.0.1:57645", false},
		{"another loopback address", sock{syscall.AF_INET, iniIPv4, v4(127, 0, 0, 2), 8080}, "", false},
		{"another interface", sock{syscall.AF_INET, iniIPv4, v4(192, 168, 7, 20), 8080}, "", false},
		{"another IPv6 interface", sock{syscall.AF_INET6, iniIPv6, [16]byte{0: 0xfe, 1: 0x80, 15: 9}, 8080}, "", false},
		{"no port", sock{syscall.AF_INET, iniIPv4, v4(127, 0, 0, 1), 0}, "", false},
		{"not IP", sock{syscall.AF_UNIX, 0, [16]byte{}, 1}, "", false},
	} {
		l, ok := c.s.listener(42)
		switch {
		case c.want == "" && ok:
			t.Errorf("%s: listed as %v", c.name, l)
		case c.want == "":
		case !ok:
			t.Errorf("%s: left out", c.name)
		case l != Listener{Pid: 42, Addr: netip.MustParseAddrPort(c.want), DualStack: c.dual}:
			t.Errorf("%s: %+v, want %s dual %v", c.name, l, c.want, c.dual)
		}
	}
}

// TestListenProbeMissesListener keeps the package doc's finding checked:
// with another process listening where a connection to localhost reaches
// it, a dial on each family the listener takes connects. Whether Go's
// net.Listen probe still binds beside it is only logged: a macOS that
// refuses it some day changes nothing, since dialing first is right
// either way.
func TestListenProbeMissesListener(t *testing.T) {
	cases := []struct{ other, probe string }{
		{"any4", "127.0.0.1"},
		{"any4", ""},
		{"ipv4", ""},
		{"dual", "127.0.0.1"},
		{"dual", "::1"},
		{"any6", "::1"},
		{"ipv6", ""},
	}
	others := make([]string, len(cases))
	for i, c := range cases {
		others[i] = c.other
	}
	pid, ports := listenElsewhere(t, others...)
	ls, err := List()
	testcheck.NoErr(t, err)
	for i, c := range cases {
		p := strconv.Itoa(int(ports[i]))
		l, err := (&net.ListenConfig{}).Listen(context.Background(), "tcp", net.JoinHostPort(c.probe, p))
		if err != nil {
			t.Logf("other on %s: a listen on %q:%s was refused (%v)", c.other, c.probe, p, err)
		} else {
			t.Logf("other on %s: a listen on %q:%s bound beside it", c.other, c.probe, p)
			_ = l.Close()
		}
		other := ofPid(OnPort(ls, ports[i]), pid)
		if len(other) != 1 {
			t.Fatalf("other on %s: listed %v for the helper on port %s", c.other, other, p)
		}
		for _, host := range []string{"127.0.0.1", "::1"} {
			dst := netip.AddrPortFrom(netip.MustParseAddr(host), ports[i])
			if !other[0].Takes(dst) {
				continue
			}
			d, err := net.Dial("tcp", dst.String())
			if err != nil {
				t.Errorf("other on %s: a dial to %v failed: %v", c.other, dst, err)
				continue
			}
			_ = d.Close()
		}
	}
}

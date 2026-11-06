// Package listeners lists the TCP sockets listening for connections to
// this Mac's localhost (127.0.0.1 and ::1), with the process holding
// each, and tells which of them a connection reaches and whether they are
// in a process tree (proctree's processes): what a dev server's identity
// check and spotting need.
//
// It reads them through libproc (cgo: proc_listpids, then each process's
// descriptors with PROC_PIDLISTFDS and each socket's with
// PROC_PIDFDSOCKETINFO), not lsof. Measured on 2026-11-06 (macOS 27.0.1,
// an M3 Pro, about 820 processes, 550 of them the user's, 24 listeners):
// a List took 0.86–0.92 ms (1.1–1.3 ms asking of every process, not only
// the user's), `lsof -nP -iTCP -sTCP:LISTEN -Fpn` 27.7–28.2 ms, and the
// two listed the same sockets. lsof's -Fpn also writes an IPv4 and an
// IPv6 wildcard alike (`*:p`) and never says whether an IPv6 one takes
// IPv4; libproc's flags do.
//
// A free port is told by dialing it, not by listening on it: Go's
// net.Listen sets SO_REUSEADDR, and macOS then lets it bind beside another
// process's listener a connection to localhost reaches. Seen on the same
// Mac (TestListenProbeMissesListener keeps it checked), Go's probe called
// the port free with the other process on 0.0.0.0:p and a probe on
// 127.0.0.1:p or ":p"; on 127.0.0.1:p and a probe on ":p" or (tcp4)
// 0.0.0.0:p; on a dual-stack [::]:p and a probe on 127.0.0.1:p or
// [::1]:p; on an IPv6-only [::]:p and a probe on [::1]:p; on [::1]:p and
// a probe on ":p". The other socket's own SO_REUSEADDR made no difference.
// A dial to 127.0.0.1:p and to [::1]:p connected in each case the
// listener takes connections on that family.
package listeners

import (
	"net/netip"
	"slices"

	"github.com/afrase/nushi/internal/model"
)

// Listener is one listening TCP socket a connection to localhost can
// reach, and a process holding it (a socket a child inherited is listed
// once for each process holding it).
type Listener struct {
	Pid int
	// Addr is the local address: 127.0.0.1, ::1, or a wildcard (0.0.0.0
	// or ::), with the port.
	Addr netip.AddrPort
	// DualStack is an IPv6 wildcard that takes IPv4 connections too (no
	// IPV6_V6ONLY): Go's net.Listen("tcp", ":p"), Node's default.
	DualStack bool
}

// The addresses localhost resolves to.
var (
	loopback4 = netip.AddrFrom4([4]byte{127, 0, 0, 1})
	loopback6 = netip.IPv6Loopback()
)

// local is whether a connection to localhost can reach l: one on
// 127.0.0.1 or ::1, or a wildcard (another of 127.0.0.0/8, 127.0.0.2 say,
// isn't reached by one).
func (l Listener) local() bool {
	a := l.Addr.Addr()
	return a == loopback4 || a == loopback6 || a.IsUnspecified()
}

// Takes reports whether a connection to dst (127.0.0.1:p or [::1]:p,
// say) reaches l: same port, and l's address is dst's, or a wildcard of
// its family (an IPv6 one of both when it's dual-stack).
func (l Listener) Takes(dst netip.AddrPort) bool {
	if l.Addr.Port() != dst.Port() {
		return false
	}
	a, b := l.Addr.Addr(), dst.Addr().Unmap()
	switch {
	case a == b:
		return true
	case !a.IsUnspecified():
		return false
	case a.Is4():
		return b.Is4()
	default:
		return b.Is6() || l.DualStack
	}
}

// OnPort is those of ls on port, on any address.
func OnPort(ls []Listener, port uint16) []Listener {
	var out []Listener
	for _, l := range ls {
		if l.Addr.Port() == port {
			out = append(out, l)
		}
	}
	return out
}

// Reaching is those of ls a connection to dst (127.0.0.1:p or [::1]:p)
// can land on. macOS gives it to a listener bound to dst's own address
// before any wildcard, whichever bound first (seen with two processes on
// one port: beside 0.0.0.0:p or ":p", a dial to 127.0.0.1 reached
// 127.0.0.1:p; beside ":p", one to ::1 reached [::1]:p), so those alone
// when there are any; otherwise every wildcard that Takes dst, since
// which of two the kernel picks (0.0.0.0:p beside a dual-stack ":p")
// isn't told here. A dev server's identity check asks it for each family
// the browser tab dials: every listener it returns must be in the
// server's Procs, and an empty one means nothing answers there.
func Reaching(ls []Listener, dst netip.AddrPort) []Listener {
	var exact, wild []Listener
	for _, l := range ls {
		switch {
		case !l.Takes(dst):
		case l.Addr.Addr().IsUnspecified():
			wild = append(wild, l)
		default:
			exact = append(exact, l)
		}
	}
	if len(exact) > 0 {
		return exact
	}
	return wild
}

// Procs is a process and the processes below it, as proctree's Under
// reads them.
type Procs struct {
	Root  int
	Below []model.Process
}

// Has reports whether pid is the root or below it.
func (p Procs) Has(pid int) bool {
	return pid == p.Root || slices.ContainsFunc(p.Below, func(q model.Process) bool { return q.Pid == pid })
}

// Split parts ls into those a process of p holds and the rest: of what
// Reaching returns, a dev server's own listener, and a foreign one a
// connection to the server's port may land on instead.
func (p Procs) Split(ls []Listener) (in, out []Listener) {
	for _, l := range ls {
		if p.Has(l.Pid) {
			in = append(in, l)
		} else {
			out = append(out, l)
		}
	}
	return in, out
}

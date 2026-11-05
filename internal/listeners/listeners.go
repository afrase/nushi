// Package listeners lists the TCP sockets listening for connections to
// this Mac's localhost, with the process holding each, and tells whether
// a port's listener is in a process tree (proctree's processes): what a
// dev server's identity check and spotting need.
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

// local is whether a connection to localhost can reach l.
func (l Listener) local() bool {
	a := l.Addr.Addr()
	return a.IsLoopback() || a.IsUnspecified()
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

// Tree is a process and the processes below it, as proctree's Under reads
// them.
type Tree struct {
	Root  int
	Below []model.Process
}

// Has reports whether pid is the tree's root or below it.
func (t Tree) Has(pid int) bool {
	return pid == t.Root || slices.ContainsFunc(t.Below, func(p model.Process) bool { return p.Pid == pid })
}

// Split parts ls into those a process of the tree holds and the rest: on
// one port, a dev server's own listener, and a foreign one beside it (on
// the other family, say).
func (t Tree) Split(ls []Listener) (in, out []Listener) {
	for _, l := range ls {
		if t.Has(l.Pid) {
			in = append(in, l)
		} else {
			out = append(out, l)
		}
	}
	return in, out
}

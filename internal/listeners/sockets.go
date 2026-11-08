package listeners

import (
	"bytes"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"net/netip"
	"strconv"
	"strings"
	"syscall"
)

// Linux's listening TCP sockets as the kernel tells them, which
// listeners_linux.go reads from sock_diag or, where it can't be asked,
// from /proc/net/tcp and tcp6. The parsers build everywhere so their
// tests run on the Mac too, so the numbers are Linux's own (its AF_INET6
// is 10, the Mac's 30) and multi-byte fields are read in the host's order,
// as the kernel writes them.
const (
	linuxAFInet  = 2
	linuxAFInet6 = 10
	// tcpListen is TCP_LISTEN, /proc/net/tcp's state 0A.
	tcpListen = 10

	nlmsgHdrLen      = 16 // struct nlmsghdr
	nlmsgError       = 2  // NLMSG_ERROR
	nlmsgDone        = 3  // NLMSG_DONE
	sockDiagByFamily = 20 // SOCK_DIAG_BY_FAMILY
	diagMsgLen       = 72 // struct inet_diag_msg
	// inetDiagSKV6Only is INET_DIAG_SKV6ONLY, the attribute holding an
	// IPv6 socket's IPV6_V6ONLY, which the kernel adds to each listening
	// one unasked.
	inetDiagSKV6Only = 11
	nlaTypeMask      = 0x3fff // an attribute's type without NLA_F_NESTED and NLA_F_NET_BYTEORDER
)

// inodeSocket is one listening TCP socket and its inode, which ties it to
// the processes holding it (their /proc/<pid>/fd links,
// "socket:[inode]").
type inodeSocket struct {
	// Addr is the local address, a v4-mapped one as IPv4 (an IPv6 socket
	// bound to ::ffff:127.0.0.1 takes only IPv4 connections).
	Addr  netip.AddrPort
	Inode uint64
	// V6Only is an IPv6 socket that takes no IPv4 connections
	// (IPV6_V6ONLY).
	V6Only bool
}

// listener makes pid's Listener of s, false when a connection to
// localhost can't reach it (its address is another interface's).
func (s inodeSocket) listener(pid int) (Listener, bool) {
	a := s.Addr.Addr()
	l := Listener{Pid: pid, Addr: s.Addr, DualStack: a.Is6() && a.IsUnspecified() && !s.V6Only}
	return l, l.local()
}

// parseDiagDump reads what one read of a sock_diag socket gave: netlink
// messages, each an inet_diag_msg and its attributes, until NLMSG_DONE
// (done) or an NLMSG_ERROR. A message of another type, a socket not
// listening and one of another family are skipped. A dump the kernel
// couldn't make (no tcp_diag for inet_diag to hand it to) ends in an
// NLMSG_DONE carrying the negative errno, not an NLMSG_ERROR
// (netlink_dump_done), so a DONE's errno is an error too: its empty dump
// isn't "no listeners".
func parseDiagDump(b []byte) (socks []inodeSocket, done bool, err error) {
	ne := binary.NativeEndian
	for len(b) >= nlmsgHdrLen {
		n := int(ne.Uint32(b))
		if n < nlmsgHdrLen || n > len(b) {
			return socks, false, errors.New("sock_diag: a message's length is past what was read")
		}
		data := b[nlmsgHdrLen:n]
		switch ne.Uint16(b[4:]) {
		case nlmsgDone:
			if err := diagErrno(data); err != nil {
				return socks, false, err
			}
			return socks, true, nil
		case nlmsgError:
			if len(data) < 4 {
				return socks, false, errors.New("sock_diag: a short error")
			}
			if err := diagErrno(data); err != nil {
				return socks, false, err
			}
			// An error of 0 acknowledges a request, which a dump doesn't ask for.
		case sockDiagByFamily:
			if s, ok := parseDiagMsg(data); ok {
				socks = append(socks, s)
			}
		}
		b = b[min(align4(n), len(b)):]
	}
	return socks, false, nil
}

// diagErrno is the error a message's payload starts with, the kernel's
// int: nil when it is 0 or there is none (an old kernel's bare
// NLMSG_DONE).
func diagErrno(data []byte) error {
	if len(data) < 4 {
		return nil
	}
	if e := int32(binary.NativeEndian.Uint32(data)); e < 0 { //nolint:gosec // the kernel's int error, sent as its bits
		return syscall.Errno(-e)
	}
	return nil
}

// parseDiagMsg reads an inet_diag_msg (family, state, the socket's id:
// ports in network order, addresses as bytes; its inode) and, of its
// attributes, INET_DIAG_SKV6ONLY.
func parseDiagMsg(m []byte) (inodeSocket, bool) {
	if len(m) < diagMsgLen || m[1] != tcpListen {
		return inodeSocket{}, false
	}
	var a netip.Addr
	switch m[0] {
	case linuxAFInet:
		a = netip.AddrFrom4([4]byte(m[8:12]))
	case linuxAFInet6:
		a = netip.AddrFrom16([16]byte(m[8:24])).Unmap()
	default:
		return inodeSocket{}, false
	}
	s := inodeSocket{
		Addr:  netip.AddrPortFrom(a, binary.BigEndian.Uint16(m[4:6])),
		Inode: uint64(binary.NativeEndian.Uint32(m[68:72])),
	}
	for attrs := m[diagMsgLen:]; len(attrs) >= 4; {
		n := int(binary.NativeEndian.Uint16(attrs))
		if n < 4 || n > len(attrs) {
			break
		}
		if binary.NativeEndian.Uint16(attrs[2:])&nlaTypeMask == inetDiagSKV6Only && n > 4 {
			s.V6Only = attrs[4] != 0
		}
		attrs = attrs[min(align4(n), len(attrs)):]
	}
	return s, s.Inode != 0 && s.Addr.Port() != 0
}

// align4 rounds a netlink length up to its 4-byte alignment.
func align4(n int) int {
	return (n + 3) &^ 3
}

// parseProcNet reads /proc/net/tcp or tcp6 (proc_net_tcp(5)): the rows in
// state 0A (listening), their local address and inode. It can't tell an
// IPv6 socket's IPV6_V6ONLY, which a program sets as it likes (Go does for
// "tcp6" on [::]) whatever net.ipv6.bindv6only says, so each is taken as
// dual-stack: a wildcard then counts among those an IPv4 dial may reach,
// and a servers identity check that meets another program's refuses
// rather than misses it (the wrong guess costs a refusal, or a v6-only
// server taken as answering on 127.0.0.1, never another program let in).
// A row it can't read is skipped.
func parseProcNet(b []byte) []inodeSocket {
	var out []inodeSocket
	for i, line := range bytes.Split(b, []byte("\n")) {
		f := strings.Fields(string(line))
		if i == 0 || len(f) < 10 || f[3] != "0A" {
			continue
		}
		hexAddr, hexPort, _ := strings.Cut(f[1], ":")
		a, ok := procNetAddr(hexAddr)
		port, errPort := strconv.ParseUint(hexPort, 16, 16)
		inode, errInode := strconv.ParseUint(f[9], 10, 64)
		if !ok || errPort != nil || errInode != nil || port == 0 || inode == 0 {
			continue
		}
		out = append(out, inodeSocket{Addr: netip.AddrPortFrom(a, uint16(port)), Inode: inode})
	}
	return out
}

// procNetAddr reads an address as /proc/net/tcp writes it: each 32-bit
// word of the address, as it lies in memory in network order, printed as
// a host-order number in hex (8 digits for IPv4, 32 for IPv6). A
// v4-mapped one comes back as IPv4.
func procNetAddr(s string) (netip.Addr, bool) {
	printed, err := hex.DecodeString(s)
	if err != nil || len(printed) != 4 && len(printed) != 16 {
		return netip.Addr{}, false
	}
	raw := make([]byte, len(printed))
	for i := 0; i < len(raw); i += 4 {
		binary.NativeEndian.PutUint32(raw[i:], binary.BigEndian.Uint32(printed[i:]))
	}
	a, _ := netip.AddrFromSlice(raw)
	return a.Unmap(), true
}

// socketInode is the inode of a descriptor's link to a socket
// ("socket:[123]"), false for a link to anything else.
func socketInode(link string) (uint64, bool) {
	s, ok := strings.CutPrefix(link, "socket:[")
	if !ok {
		return 0, false
	}
	s, ok = strings.CutSuffix(s, "]")
	if !ok {
		return 0, false
	}
	n, err := strconv.ParseUint(s, 10, 64)
	return n, err == nil
}

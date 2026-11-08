package listeners

import (
	"encoding/binary"
	"errors"
	"fmt"
	"time"

	"golang.org/x/sys/unix"
)

// diagTimeout bounds each read of the sock_diag socket, so a kernel that
// never finishes a dump can't hold List.
const diagTimeout = 2 * time.Second

// diagListening asks the kernel's sock_diag (NETLINK_SOCK_DIAG, as ss
// does) for every listening TCP socket of this network namespace, IPv4
// then IPv6, each IPv6 one with its IPV6_V6ONLY, which /proc/net/tcp6
// doesn't show. Anyone may ask; it says nothing of which process holds a
// socket, only its inode.
func diagListening() ([]inodeSocket, error) {
	fd, err := unix.Socket(unix.AF_NETLINK, unix.SOCK_DGRAM|unix.SOCK_CLOEXEC, unix.NETLINK_SOCK_DIAG)
	if err != nil {
		return nil, fmt.Errorf("opening sock_diag: %w", err)
	}
	defer func() { _ = unix.Close(fd) }()
	tv := unix.NsecToTimeval(diagTimeout.Nanoseconds())
	if err := unix.SetsockoptTimeval(fd, unix.SOL_SOCKET, unix.SO_RCVTIMEO, &tv); err != nil {
		return nil, fmt.Errorf("sock_diag's timeout: %w", err)
	}
	// 32 KB is the most the kernel puts in one read of a dump.
	buf := make([]byte, 32<<10)
	var out []inodeSocket
	for i, family := range []uint8{unix.AF_INET, unix.AF_INET6} {
		if err := unix.Sendto(fd, diagRequest(family, uint32(i+1)), 0, &unix.SockaddrNetlink{Family: unix.AF_NETLINK}); err != nil {
			return nil, fmt.Errorf("asking sock_diag: %w", err)
		}
		for done := false; !done; {
			n, _, flags, from, err := unix.Recvmsg(fd, buf, nil, 0)
			switch {
			case errors.Is(err, unix.EINTR):
				continue
			case err != nil:
				return nil, fmt.Errorf("reading sock_diag: %w", err)
			case flags&unix.MSG_TRUNC != 0:
				return nil, errors.New("reading sock_diag: a message didn't fit")
			}
			if sa, ok := from.(*unix.SockaddrNetlink); !ok || sa.Pid != 0 {
				continue // only the kernel's answers count
			}
			var socks []inodeSocket
			socks, done, err = parseDiagDump(buf[:n])
			if err != nil {
				return nil, fmt.Errorf("reading sock_diag: %w", err)
			}
			out = append(out, socks...)
		}
	}
	return out, nil
}

// diagRequest is a netlink message asking a dump of family's listening
// TCP sockets: an nlmsghdr and an inet_diag_req_v2 that matches every
// address and port (its sockid all zero) and asks no extensions, since
// INET_DIAG_SKV6ONLY comes unasked.
func diagRequest(family uint8, seq uint32) []byte {
	const msgLen = nlmsgHdrLen + 56 // struct inet_diag_req_v2
	b := make([]byte, msgLen)
	ne := binary.NativeEndian
	ne.PutUint32(b[0:], msgLen)
	ne.PutUint16(b[4:], unix.SOCK_DIAG_BY_FAMILY)
	ne.PutUint16(b[6:], unix.NLM_F_REQUEST|unix.NLM_F_DUMP)
	ne.PutUint32(b[8:], seq)
	b[nlmsgHdrLen] = family
	b[nlmsgHdrLen+1] = unix.IPPROTO_TCP
	ne.PutUint32(b[nlmsgHdrLen+4:], 1<<tcpListen) // idiag_states
	return b
}

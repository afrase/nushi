package listeners

/*
#include <stdlib.h>
#include <string.h>
#include <libproc.h>
#include <sys/proc_info.h>
#include <sys/socket.h>
#include <netinet/in.h>

// sock is one listening TCP socket as libproc tells it: its family, its
// INI_IPV4 and INI_IPV6 flags, its local address as the kernel keeps it
// (an IPv4 one in the last four bytes) and its port in host order.
struct sock {
	int family;
	int vflag;
	unsigned char addr[16];
	int port;
};

// pid_socks writes up to max of pid's listening TCP sockets to out and
// returns how many it has, which can be more than max, or -1 when its
// descriptors can't be read (it ended, or it isn't the user's). A
// descriptor that closes while it is read is skipped.
static int pid_socks(int pid, struct sock *out, int max) {
	int size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
	if (size <= 0) return -1;
	struct proc_fdinfo *fds = malloc(size);
	if (fds == NULL) return -1;
	size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, fds, size);
	if (size <= 0) {
		free(fds);
		return -1;
	}
	int n = 0;
	for (int i = 0; i < size / (int)sizeof(struct proc_fdinfo); i++) {
		if (fds[i].proc_fdtype != PROX_FDTYPE_SOCKET) continue;
		struct socket_fdinfo si;
		if (proc_pidfdinfo(pid, fds[i].proc_fd, PROC_PIDFDSOCKETINFO, &si, sizeof si) != sizeof si) continue;
		if (si.psi.soi_kind != SOCKINFO_TCP || si.psi.soi_proto.pri_tcp.tcpsi_state != TSI_S_LISTEN) continue;
		if (n >= max) {
			n++;
			continue;
		}
		struct in_sockinfo *in = &si.psi.soi_proto.pri_tcp.tcpsi_ini;
		struct sock *s = &out[n++];
		memset(s, 0, sizeof *s);
		s->family = si.psi.soi_family;
		s->vflag = in->insi_vflag;
		memcpy(s->addr, &in->insi_laddr, 16);
		s->port = ntohs((uint16_t)in->insi_lport);
	}
	free(fds);
	return n;
}
*/
import "C"

import (
	"errors"
	"fmt"
	"net/netip"
	"syscall"
	"unsafe"
)

// socksAtFirst is room for the listening sockets of one process at the
// first read: a dev server has a few, and a process with more is read
// again with room for all.
const socksAtFirst = 16

// pids lists the user's processes (PROC_UID_ONLY: libproc can't read
// another user's descriptors, and asking costs a call each).
func pids() ([]int, error) {
	uid := C.uint32_t(syscall.Getuid())
	for range 3 { // the list can grow between the size and the read
		size := C.proc_listpids(C.PROC_UID_ONLY, uid, nil, 0)
		if size <= 0 {
			return nil, errors.New("proc_listpids failed")
		}
		buf := make([]C.int, int(size)/C.sizeof_int+32)
		n := C.proc_listpids(C.PROC_UID_ONLY, uid, unsafe.Pointer(&buf[0]), C.int(len(buf)*C.sizeof_int))
		if n <= 0 {
			return nil, errors.New("proc_listpids failed")
		}
		if int(n)/C.sizeof_int == len(buf) {
			continue
		}
		out := make([]int, 0, int(n)/C.sizeof_int)
		for _, p := range buf[:int(n)/C.sizeof_int] {
			if p > 0 {
				out = append(out, int(p))
			}
		}
		return out, nil
	}
	return nil, errors.New("proc_listpids: the process list kept growing")
}

// List reads the user's own processes' TCP listeners that a connection to
// localhost can reach (on a loopback address or a wildcard), through
// libproc. Another user's listener (root's, say) isn't seen: what tells a
// port taken is a dial, not this.
func List() ([]Listener, error) {
	ps, err := pids()
	if err != nil {
		return nil, fmt.Errorf("listing processes: %w", err)
	}
	var out []Listener
	socks := make([]C.struct_sock, socksAtFirst)
	for _, pid := range ps {
		for _, s := range pidSocks(pid, &socks) {
			k := sock{family: int(s.family), vflag: int(s.vflag), port: int(s.port)}
			for i, b := range s.addr {
				k.addr[i] = byte(b)
			}
			if l, ok := k.listener(pid); ok {
				out = append(out, l)
			}
		}
	}
	return out, nil
}

// pidSocks reads pid's listening TCP sockets into *buf, growing it when
// they don't fit (a few times at most: the process may open more between
// reads, and then the last read's first ones are kept).
func pidSocks(pid int, buf *[]C.struct_sock) []C.struct_sock {
	for try := 1; ; try++ {
		n := int(C.pid_socks(C.int(pid), &(*buf)[0], C.int(len(*buf))))
		if n <= len(*buf) || try == 3 {
			return (*buf)[:max(min(n, len(*buf)), 0)]
		}
		*buf = make([]C.struct_sock, n+socksAtFirst)
	}
}

// The socket's flags of its IP versions (INI_IPV4 and INI_IPV6 in
// sys/proc_info.h).
const (
	iniIPv4 = 0x1
	iniIPv6 = 0x2
)

// sock is a listening TCP socket as libproc tells it.
type sock struct {
	family int
	// vflag holds iniIPv4 and iniIPv6: an IPv4 socket has iniIPv4; an
	// IPv6 one iniIPv6, both when it is a wildcard taking IPv4 too, and
	// only iniIPv4 when it is bound to a v4-mapped address (Java's).
	vflag int
	// addr is the local address as the kernel keeps it: an IPv6 one, or
	// an IPv4 one in its last four bytes when vflag is iniIPv4 alone.
	addr [16]byte
	port int
}

// listener makes a Listener of s, false when a connection to localhost
// can't reach it (its address is another interface's) or it isn't IP.
func (s sock) listener(pid int) (Listener, bool) {
	if s.family != syscall.AF_INET && s.family != syscall.AF_INET6 || s.port <= 0 || s.port > 65535 {
		return Listener{}, false
	}
	a := netip.AddrFrom16(s.addr).Unmap()
	if s.vflag&(iniIPv4|iniIPv6) == iniIPv4 {
		a = netip.AddrFrom4([4]byte(s.addr[12:]))
	}
	l := Listener{
		Pid:       pid,
		Addr:      netip.AddrPortFrom(a, uint16(s.port)),
		DualStack: s.family == syscall.AF_INET6 && a.IsUnspecified() && s.vflag&iniIPv4 != 0,
	}
	return l, l.local()
}

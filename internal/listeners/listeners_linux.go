package listeners

import (
	"bytes"
	"errors"
	"fmt"
	"os"

	"github.com/afrase/nushi/internal/procfs"
)

// List reads the user's own processes' TCP listeners that a connection to
// localhost can reach (on a loopback address or a wildcard): the
// listening sockets from sock_diag, or from /proc/net/tcp and tcp6 where
// it can't be asked, each tied to the processes holding it through their
// descriptors' links (/proc/<pid>/fd, "socket:[inode]"). A process with
// one socket at two descriptors is listed once. A socket no process of
// the user's holds (root's, another user's) isn't listed, as on the Mac:
// what tells a port taken is a dial, not this.
func List() ([]Listener, error) {
	socks, err := diagListening()
	if err != nil {
		var errNet error
		if socks, errNet = procNetListening(); errNet != nil {
			return nil, fmt.Errorf("listing listening sockets: %w", errors.Join(err, errNet))
		}
	}
	byInode := make(map[uint64]inodeSocket, len(socks))
	for _, s := range socks {
		if _, ok := s.listener(0); ok {
			byInode[s.Inode] = s
		}
	}
	if len(byInode) == 0 {
		return nil, nil
	}
	var out []Listener
	for _, pid := range procfs.Pids() {
		var seen map[uint64]bool
		for _, link := range procfs.Links(pid) {
			inode, ok := socketInode(link)
			s, held := byInode[inode]
			if !ok || !held || seen[inode] {
				continue
			}
			if seen == nil {
				seen = make(map[uint64]bool)
			}
			seen[inode] = true
			l, _ := s.listener(pid)
			out = append(out, l)
		}
	}
	return out, nil
}

// procNetListening reads the listening sockets from /proc/net/tcp and
// tcp6, which tell no IPv6 socket's IPV6_V6ONLY: each takes the system's
// default (parseProcNet). A system without IPv6 has no tcp6, which is no
// error.
func procNetListening() ([]inodeSocket, error) {
	v6only := false
	if b, err := os.ReadFile("/proc/sys/net/ipv6/bindv6only"); err == nil {
		v6only = string(bytes.TrimSpace(b)) == "1"
	}
	b, err := os.ReadFile("/proc/net/tcp")
	if err != nil {
		return nil, fmt.Errorf("reading TCP sockets: %w", err)
	}
	socks := parseProcNet(b, v6only)
	b, err = os.ReadFile("/proc/net/tcp6")
	switch {
	case err == nil:
		socks = append(socks, parseProcNet(b, v6only)...)
	case !errors.Is(err, os.ErrNotExist):
		return nil, fmt.Errorf("reading TCP sockets: %w", err)
	}
	return socks, nil
}

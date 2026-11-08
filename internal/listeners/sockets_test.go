package listeners

import (
	"encoding/binary"
	"errors"
	"net/netip"
	"os"
	"path/filepath"
	"slices"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/testcheck"
)

func readTestdata(t *testing.T, name string) []byte {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("testdata", name))
	testcheck.NoErr(t, err)
	return b
}

func sockAt(addr string, inode uint64, v6only bool) inodeSocket {
	return inodeSocket{Addr: netip.MustParseAddrPort(addr), Inode: inode, V6Only: v6only}
}

// The dumps are as sock_diag gave them on 2026-11-08 (Linux 7.2, x86_64
// under Rosetta), for Go's five kinds of listener: 127.0.0.1:40001,
// [::1]:40002, 0.0.0.0:40003, [::]:40004 (IPV6_V6ONLY) and a dual-stack
// ":40005". Each message holds attributes besides INET_DIAG_SKV6ONLY,
// which must be stepped over.
func TestParseDiagDump(t *testing.T) {
	for _, c := range []struct {
		file string
		want []inodeSocket
	}{
		{"diag-inet", []inodeSocket{sockAt("0.0.0.0:40003", 543168, false), sockAt("127.0.0.1:40001", 543166, false)}},
		{"diag-inet6", []inodeSocket{sockAt("[::]:40005", 543170, false), sockAt("[::]:40004", 543169, true), sockAt("[::1]:40002", 543167, true)}},
	} {
		got, done, err := parseDiagDump(readTestdata(t, c.file))
		testcheck.NoErr(t, err)
		if !done || !slices.Equal(got, c.want) {
			t.Errorf("%s: %v (done %v), want %v", c.file, got, done, c.want)
		}
	}
}

// A dump split across reads is done only at NLMSG_DONE; a message cut
// short, an error and a socket not listening are told apart.
func TestParseDiagDumpEdges(t *testing.T) {
	dump := readTestdata(t, "diag-inet6")
	first := int(binary.NativeEndian.Uint32(dump))
	if got, done, err := parseDiagDump(dump[:first]); err != nil || done || len(got) != 1 {
		t.Errorf("one message of a dump: %v, done %v, %v", got, done, err)
	}
	if _, _, err := parseDiagDump(dump[:first-1]); err == nil {
		t.Error("a message cut short read without an error")
	}

	notListening := slices.Clone(dump[:first])
	notListening[nlmsgHdrLen+1] = 1 // TCP_ESTABLISHED
	if got, _, err := parseDiagDump(notListening); err != nil || len(got) != 0 {
		t.Errorf("an established socket: %v, %v", got, err)
	}

	if _, _, err := parseDiagDump(errnoMsg(nlmsgError, syscall.EPERM)); !errors.Is(err, syscall.EPERM) {
		t.Errorf("an error message read as %v", err)
	}
}

// A dump of a protocol inet_diag has no handler for (sctp_diag not loaded,
// or tcp_diag where it can't be) ends, on Linux 7.2, in a 20-byte
// NLMSG_DONE carrying -ENOENT and no NLMSG_ERROR; a good dump's DONE
// carries 0, and an old kernel's none.
func TestParseDiagDumpDoneErrno(t *testing.T) {
	if got, done, err := parseDiagDump(errnoMsg(nlmsgDone, syscall.ENOENT)); !errors.Is(err, syscall.ENOENT) || done || len(got) != 0 {
		t.Errorf("a DONE carrying -ENOENT: %v, done %v, %v", got, done, err)
	}
	if _, done, err := parseDiagDump(errnoMsg(nlmsgDone, 0)); err != nil || !done {
		t.Errorf("a DONE carrying 0: done %v, %v", done, err)
	}
	bare := errnoMsg(nlmsgDone, 0)[:nlmsgHdrLen]
	binary.NativeEndian.PutUint32(bare, nlmsgHdrLen)
	if _, done, err := parseDiagDump(bare); err != nil || !done {
		t.Errorf("a bare DONE: done %v, %v", done, err)
	}
}

// errnoMsg is a netlink message of type typ whose payload is -errno, as
// the kernel writes an NLMSG_ERROR's or a failed dump's NLMSG_DONE.
func errnoMsg(typ uint16, errno syscall.Errno) []byte {
	const msgLen = nlmsgHdrLen + 4
	b := make([]byte, msgLen)
	binary.NativeEndian.PutUint32(b, msgLen)
	binary.NativeEndian.PutUint16(b[4:], typ)
	binary.NativeEndian.PutUint32(b[nlmsgHdrLen:], uint32(-int32(errno))) //nolint:gosec // the kernel's int error, as its bits
	return b
}

// proc-net-tcp's and proc-net-tcp6's first rows are as Linux 7.2 wrote
// them for Go's five kinds of listener and a connection; the rest are
// made up: another interface, another loopback address, a v4-mapped
// address, link-local, and rows that can't be read.
func TestParseProcNet(t *testing.T) {
	v4 := []inodeSocket{
		sockAt("0.0.0.0:40003", 539184, false),
		sockAt("127.0.0.1:40001", 539182, false),
		sockAt("192.168.7.20:8080", 539190, false),
		sockAt("127.0.0.2:8081", 539191, false),
	}
	if got := parseProcNet(readTestdata(t, "proc-net-tcp")); !slices.Equal(got, v4) {
		t.Errorf("tcp: %v, want %v", got, v4)
	}
	// No IPv6 row is V6Only: /proc/net can't tell, so each is dual-stack.
	tcp6 := []inodeSocket{
		sockAt("[::]:40005", 539186, false),
		sockAt("[::]:40004", 539185, false),
		sockAt("[::1]:40002", 539183, false),
		sockAt("127.0.0.1:40006", 539193, false),
		sockAt("[fe80::9]:8080", 539195, false),
	}
	if got := parseProcNet(readTestdata(t, "proc-net-tcp6")); !slices.Equal(got, tcp6) {
		t.Errorf("tcp6: %v, want %v", got, tcp6)
	}
}

func TestInodeSocketListener(t *testing.T) {
	for _, c := range []struct {
		s    inodeSocket
		ok   bool
		dual bool
	}{
		{sockAt("127.0.0.1:3000", 1, false), true, false},
		{sockAt("[::1]:3000", 1, true), true, false},
		{sockAt("0.0.0.0:3000", 1, false), true, false},
		{sockAt("[::]:3000", 1, true), true, false},
		{sockAt("[::]:3000", 1, false), true, true},
		{sockAt("127.0.0.2:3000", 1, false), false, false},
		{sockAt("192.168.7.20:3000", 1, false), false, false},
		{sockAt("[fe80::9]:3000", 1, false), false, false},
	} {
		l, ok := c.s.listener(42)
		if ok != c.ok || l != (Listener{Pid: 42, Addr: c.s.Addr, DualStack: c.dual}) {
			t.Errorf("%v: %+v, %v; want local %v, dual %v", c.s, l, ok, c.ok, c.dual)
		}
	}
}

func TestSocketInode(t *testing.T) {
	for link, want := range map[string]uint64{
		"socket:[539184]":      539184,
		"socket:[0]":           0,
		"socket:[]":            0,
		"socket:[12":           0,
		"pipe:[539184]":        0,
		"/dev/pts/3":           0,
		"anon_inode:[eventfd]": 0,
	} {
		got, ok := socketInode(link)
		if got != want || ok != (link == "socket:[539184]" || link == "socket:[0]") {
			t.Errorf("%q: %d, %v", link, got, ok)
		}
	}
}

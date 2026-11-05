package listeners

import (
	"bufio"
	"net"
	"net/netip"
	"os"
	"os/exec"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"testing"

	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/testcheck"
)

// The address kinds a listener is opened on: the network and address
// net.Listen takes.
var kinds = map[string][2]string{
	"ipv4": {"tcp4", "127.0.0.1:0"},
	"ipv6": {"tcp6", "[::1]:0"},
	"any4": {"tcp4", "0.0.0.0:0"},
	"any6": {"tcp6", "[::]:0"}, // Go sets IPV6_V6ONLY on it
	"dual": {"tcp", ":0"},
}

// TestHelperProcess is the other process the tests listen from: it opens
// a listener of each kind NUSHI_LISTENERS_KINDS names (comma-separated),
// writes their ports on a line, and holds them until its input closes.
func TestHelperProcess(t *testing.T) {
	names := os.Getenv("NUSHI_LISTENERS_KINDS")
	if names == "" {
		t.Skip("run by the other tests")
	}
	var ports []string
	for kind := range strings.SplitSeq(names, ",") {
		k := kinds[kind]
		l, err := net.Listen(k[0], k[1])
		testcheck.NoErr(t, err)
		defer func() { _ = l.Close() }()
		ports = append(ports, strconv.Itoa(l.Addr().(*net.TCPAddr).Port))
	}
	_, _ = os.Stdout.WriteString(strings.Join(ports, ",") + "\n")
	_, _ = bufio.NewReader(os.Stdin).ReadString('\n')
}

// listenElsewhere starts the helper listening on each of kinds, and returns its pid and the
// ports in kinds' order; it ends with the test.
func listenElsewhere(t *testing.T, kinds ...string) (int, []uint16) {
	t.Helper()
	cmd := exec.Command(os.Args[0], "-test.run=^TestHelperProcess$")
	// GORACE: the race detector otherwise waits a second as it exits.
	cmd.Env = append(os.Environ(), "NUSHI_LISTENERS_KINDS="+strings.Join(kinds, ","), "GORACE=atexit_sleep_ms=0")
	in, err := cmd.StdinPipe()
	testcheck.NoErr(t, err)
	out, err := cmd.StdoutPipe()
	testcheck.NoErr(t, err)
	testcheck.NoErr(t, cmd.Start())
	t.Cleanup(func() {
		_ = in.Close()
		_ = cmd.Wait()
	})
	line, err := bufio.NewReader(out).ReadString('\n')
	testcheck.NoErr(t, err)
	var ports []uint16
	for f := range strings.SplitSeq(strings.TrimSpace(line), ",") {
		port, err := strconv.ParseUint(f, 10, 16)
		testcheck.NoErr(t, err)
		ports = append(ports, uint16(port))
	}
	return cmd.Process.Pid, ports
}

// ofPid is those of ls pid holds: a test's port may be another process's
// on the other family.
func ofPid(ls []Listener, pid int) []Listener {
	return slices.DeleteFunc(slices.Clone(ls), func(l Listener) bool { return l.Pid != pid })
}

func TestListSeesEachKind(t *testing.T) {
	want := map[string]struct {
		addr string
		dual bool
	}{
		"ipv4": {"127.0.0.1", false},
		"ipv6": {"::1", false},
		"any4": {"0.0.0.0", false},
		"any6": {"::", false},
		"dual": {"::", true},
	}
	for kind, w := range want {
		t.Run(kind, func(t *testing.T) {
			k := kinds[kind]
			l, err := net.Listen(k[0], k[1])
			testcheck.NoErr(t, err)
			defer func() { _ = l.Close() }()
			port := uint16(l.Addr().(*net.TCPAddr).Port) //nolint:gosec // a port
			ls, err := List()
			testcheck.NoErr(t, err)
			got := ofPid(OnPort(ls, port), os.Getpid())
			wantL := Listener{Pid: os.Getpid(), Addr: netip.AddrPortFrom(netip.MustParseAddr(w.addr), port), DualStack: w.dual}
			if len(got) != 1 || got[0] != wantL {
				t.Fatalf("listed %v, want only %v", got, wantL)
			}
		})
	}
}

func TestListLeavesOutOtherInterfaces(t *testing.T) {
	ifs, err := net.InterfaceAddrs()
	testcheck.NoErr(t, err)
	var other netip.Addr
	for _, a := range ifs {
		if p, err := netip.ParsePrefix(a.String()); err == nil && p.Addr().Is4() && !p.Addr().IsLoopback() {
			other = p.Addr()
			break
		}
	}
	if !other.IsValid() {
		t.Skip("no interface but loopback")
	}
	l, err := net.Listen("tcp4", net.JoinHostPort(other.String(), "0"))
	testcheck.NoErr(t, err)
	defer func() { _ = l.Close() }()
	ls, err := List()
	testcheck.NoErr(t, err)
	if got := ofPid(OnPort(ls, uint16(l.Addr().(*net.TCPAddr).Port)), os.Getpid()); len(got) != 0 { //nolint:gosec // a port
		t.Fatalf("listed %v, on %v, which localhost doesn't reach", got, other)
	}
}

// TestListInTree finds a child's listener with its pid, in the tree
// proctree reads below this process and not in another.
func TestListInTree(t *testing.T) {
	pid, ports := listenElsewhere(t, "ipv4")
	port := ports[0]
	ls, err := List()
	testcheck.NoErr(t, err)
	on := OnPort(ls, port) // another process may hold the port on [::1]
	helpers := ofPid(on, pid)
	if len(helpers) != 1 || helpers[0].Addr.Addr() != netip.MustParseAddr("127.0.0.1") {
		t.Fatalf("on port %d: %v, want the helper's %d on 127.0.0.1", port, on, pid)
	}
	below, err := proctree.Tree{}.Under(os.Getpid())
	testcheck.NoErr(t, err)
	if in, _ := (Tree{Root: os.Getpid(), Below: below}).Split(on); !slices.Equal(in, helpers) {
		t.Fatalf("in this tree: %v, want %v", in, helpers)
	}
	if in, _ := (Tree{Root: 1}).Split(on); len(in) != 0 {
		t.Fatalf("in a tree of launchd alone: %v", in)
	}
}

func TestTreeSplit(t *testing.T) {
	tree := Tree{Root: 100, Below: []model.Process{{Pid: 101, Pgid: 101}, {Pid: 102, Pgid: 101}}}
	at := func(pid int, addr string) Listener {
		return Listener{Pid: pid, Addr: netip.MustParseAddrPort(addr)}
	}
	ls := []Listener{at(100, "127.0.0.1:3000"), at(102, "[::1]:3000"), at(200, "[::1]:3000"), at(102, "127.0.0.1:5173"), at(201, "0.0.0.0:3000")}
	in, out := tree.Split(OnPort(ls, 3000))
	if want := []Listener{ls[0], ls[1]}; !slices.Equal(in, want) {
		t.Errorf("in: %v, want %v", in, want)
	}
	if want := []Listener{ls[2], ls[4]}; !slices.Equal(out, want) {
		t.Errorf("out: %v, want %v", out, want)
	}
	for pid, want := range map[int]bool{100: true, 101: true, 102: true, 103: false, 1: false} {
		if tree.Has(pid) != want {
			t.Errorf("Has(%d) = %v", pid, !want)
		}
	}
}

// TestSockListener reads socket records as libproc gave them on a Mac
// (family, vflag, the kernel's address bytes, port).
func TestSockListener(t *testing.T) {
	v4 := func(a, b, c, d byte) [16]byte { return [16]byte{12: a, 13: b, 14: c, 15: d} }
	mapped := func(a, b, c, d byte) [16]byte { return [16]byte{10: 0xff, 11: 0xff, 12: a, 13: b, 14: c, 15: d} }
	for _, c := range []struct {
		name string
		s    sock
		want string // "" for left out
		dual bool
	}{
		{"IPv4 loopback", sock{syscall.AF_INET, iniIPv4, v4(127, 0, 0, 1), 7790}, "127.0.0.1:7790", false},
		{"IPv4 wildcard", sock{syscall.AF_INET, iniIPv4, [16]byte{}, 7000}, "0.0.0.0:7000", false},
		{"IPv6 loopback", sock{syscall.AF_INET6, iniIPv6, [16]byte{15: 1}, 32222}, "[::1]:32222", false},
		{"IPv6 wildcard, v6 only", sock{syscall.AF_INET6, iniIPv6, [16]byte{}, 7000}, "[::]:7000", false},
		{"IPv6 wildcard, dual-stack", sock{syscall.AF_INET6, iniIPv4 | iniIPv6, [16]byte{}, 53647}, "[::]:53647", true},
		// Java's: an IPv6 socket on a v4-mapped address, kept as IPv4.
		{"v4-mapped, kept as IPv4", sock{syscall.AF_INET6, iniIPv4, v4(127, 0, 0, 1), 57644}, "127.0.0.1:57644", false},
		{"v4-mapped, kept as IPv6", sock{syscall.AF_INET6, iniIPv6, mapped(127, 0, 0, 1), 57645}, "127.0.0.1:57645", false},
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

func TestTakes(t *testing.T) {
	lo4, lo6 := netip.MustParseAddrPort("127.0.0.1:3000"), netip.MustParseAddrPort("[::1]:3000")
	for _, c := range []struct {
		l        Listener
		on4, on6 bool
	}{
		{Listener{Addr: lo4}, true, false},
		{Listener{Addr: lo6}, false, true},
		{Listener{Addr: netip.MustParseAddrPort("0.0.0.0:3000")}, true, false},
		{Listener{Addr: netip.MustParseAddrPort("[::]:3000")}, false, true},
		{Listener{Addr: netip.MustParseAddrPort("[::]:3000"), DualStack: true}, true, true},
		{Listener{Addr: netip.MustParseAddrPort("[::]:3001"), DualStack: true}, false, false},
	} {
		if c.l.Takes(lo4) != c.on4 || c.l.Takes(lo6) != c.on6 {
			t.Errorf("%+v takes 127.0.0.1: %v, ::1: %v; want %v, %v", c.l, c.l.Takes(lo4), c.l.Takes(lo6), c.on4, c.on6)
		}
	}
}

func BenchmarkList(b *testing.B) {
	for b.Loop() {
		if _, err := List(); err != nil {
			b.Fatal(err)
		}
	}
}

package listeners

import (
	"bufio"
	"context"
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
// a listener of each kind NUSHI_LISTENERS_KINDS names (comma-separated; a
// kind@port on that port, not a free one), writes their ports on a line,
// answers each connection with its pid, and holds them until its input
// closes.
func TestHelperProcess(t *testing.T) {
	names := os.Getenv("NUSHI_LISTENERS_KINDS")
	if names == "" {
		t.Skip("run by the other tests")
	}
	var ports []string
	for name := range strings.SplitSeq(names, ",") {
		kind, port, _ := strings.Cut(name, "@")
		k := kinds[kind]
		addr := k[1]
		if port != "" {
			host, _, err := net.SplitHostPort(addr)
			testcheck.NoErr(t, err)
			addr = net.JoinHostPort(host, port)
		}
		l, err := net.Listen(k[0], addr)
		testcheck.NoErr(t, err)
		defer func() { _ = l.Close() }()
		go answerPid(l)
		ports = append(ports, strconv.Itoa(l.Addr().(*net.TCPAddr).Port))
	}
	_, _ = os.Stdout.WriteString(strings.Join(ports, ",") + "\n")
	_, _ = bufio.NewReader(os.Stdin).ReadString('\n')
}

// answerPid writes this process's pid to each connection l takes, until
// l closes.
func answerPid(l net.Listener) {
	for {
		c, err := l.Accept()
		if err != nil {
			return
		}
		_, _ = c.Write([]byte(strconv.Itoa(os.Getpid()) + "\n"))
		_ = c.Close()
	}
}

// listenElsewhere starts a helper listening on each of kinds, and returns
// its pid and the ports in kinds' order; it ends with the test.
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

// TestListInTree finds a child's listener with its pid, in the processes
// proctree reads below this process and not in those of another.
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
	if in, _ := (Procs{Root: os.Getpid(), Below: below}).Split(on); !slices.Equal(in, helpers) {
		t.Fatalf("in this process's: %v, want %v", in, helpers)
	}
	other, _ := listenElsewhere(t, "ipv4")
	below, err = proctree.Tree{}.Under(other)
	testcheck.NoErr(t, err)
	if in, _ := (Procs{Root: other, Below: below}).Split(on); len(in) != 0 {
		t.Fatalf("in another helper's (%d): %v", other, in)
	}
}

func TestProcsSplit(t *testing.T) {
	tree := Procs{Root: 100, Below: []model.Process{{Pid: 101, Pgid: 101}, {Pid: 102, Pgid: 101}}}
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

func TestReaching(t *testing.T) {
	at := func(pid int, addr string, dual bool) Listener {
		return Listener{Pid: pid, Addr: netip.MustParseAddrPort(addr), DualStack: dual}
	}
	lo4, lo6 := netip.MustParseAddrPort("127.0.0.1:3000"), netip.MustParseAddrPort("[::1]:3000")
	any4, dual, exact4, exact6 := at(1, "0.0.0.0:3000", false), at(2, "[::]:3000", true), at(3, "127.0.0.1:3000", false), at(4, "[::1]:3000", false)
	for _, c := range []struct {
		name     string
		ls       []Listener
		on4, on6 []Listener
	}{
		{"a wildcard alone", []Listener{dual}, []Listener{dual}, []Listener{dual}},
		{"loopback beside a wildcard", []Listener{dual, exact4}, []Listener{exact4}, []Listener{dual}},
		{"both loopbacks beside a wildcard", []Listener{exact6, dual, exact4}, []Listener{exact4}, []Listener{exact6}},
		{"two wildcards", []Listener{any4, dual}, []Listener{any4, dual}, []Listener{dual}},
		{"another port", []Listener{at(5, "127.0.0.1:3001", false)}, nil, nil},
	} {
		if got := Reaching(c.ls, lo4); !slices.Equal(got, c.on4) {
			t.Errorf("%s: reaching 127.0.0.1: %v, want %v", c.name, got, c.on4)
		}
		if got := Reaching(c.ls, lo6); !slices.Equal(got, c.on6) {
			t.Errorf("%s: reaching ::1: %v, want %v", c.name, got, c.on6)
		}
	}
}

// TestReachingTwoProcesses checks Reaching against where macOS sends a
// dial, with two processes listening on one port: the first on a free
// one, the second beside it (Go's SO_REUSEADDR lets it bind). Reaching
// must name only the process the dial reached, but for two wildcards
// (either, the host whose dial may land on both).
func TestReachingTwoProcesses(t *testing.T) {
	for _, c := range []struct{ first, second, either string }{
		{"ipv4", "dual", ""}, // a dev server's ":p" beside another app's 127.0.0.1:p
		{"any4", "ipv4", ""},
		{"dual", "ipv4", ""},
		{"dual", "ipv6", ""},
		{"any4", "dual", "127.0.0.1"},
	} {
		t.Run(c.first+"+"+c.second, func(t *testing.T) {
			first, ports := listenElsewhere(t, c.first)
			second, _ := listenElsewhere(t, c.second+"@"+strconv.Itoa(int(ports[0])))
			ls, err := List()
			testcheck.NoErr(t, err)
			ls = slices.DeleteFunc(OnPort(ls, ports[0]), func(l Listener) bool { return l.Pid != first && l.Pid != second })
			for _, host := range []string{"127.0.0.1", "::1"} {
				dst := netip.AddrPortFrom(netip.MustParseAddr(host), ports[0])
				reach := Reaching(ls, dst)
				got, ok := answeringPid(t, dst)
				if !ok {
					if len(reach) != 0 {
						t.Errorf("a dial to %v failed, but Reaching says %v", dst, reach)
					}
					continue
				}
				others := slices.ContainsFunc(reach, func(l Listener) bool { return l.Pid != got })
				if !slices.ContainsFunc(reach, func(l Listener) bool { return l.Pid == got }) || others && host != c.either {
					t.Errorf("a dial to %v reached pid %d, but Reaching says %v (listed %v)", dst, got, reach, ls)
				}
			}
		})
	}
}

// answeringPid dials dst and reads the pid a helper answers with; false
// when the dial fails (another process holding the port's other family is
// no helper and fails the test).
func answeringPid(t *testing.T, dst netip.AddrPort) (int, bool) {
	t.Helper()
	c, err := net.Dial("tcp", dst.String())
	if err != nil {
		return 0, false
	}
	defer func() { _ = c.Close() }()
	line, err := bufio.NewReader(c).ReadString('\n')
	testcheck.NoErr(t, err)
	pid, err := strconv.Atoi(strings.TrimSpace(line))
	testcheck.NoErr(t, err)
	return pid, true
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

func BenchmarkList(b *testing.B) {
	for b.Loop() {
		if _, err := List(); err != nil {
			b.Fatal(err)
		}
	}
}

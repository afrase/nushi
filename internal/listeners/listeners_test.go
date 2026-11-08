package listeners

import (
	"bufio"
	"context"
	"errors"
	"net"
	"net/netip"
	"os"
	"os/exec"
	"runtime"
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

// helperControl is what the helper sets on each socket before it binds:
// nothing on the Mac, SO_REUSEPORT on Linux (listeners_linux_test.go),
// where a second listener on a port beside another's binds only when both
// set it.
var helperControl func(network, address string, c syscall.RawConn) error

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
		l, err := (&net.ListenConfig{Control: helperControl}).Listen(context.Background(), k[0], addr)
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

// list is List, skipped where this OS's listeners aren't read. On the Mac
// and Linux, which read them, an unsupported answer fails the test, so a
// lost build tag or a sandbox that hides both of Linux's sources can't
// pass as a skip.
func list(t *testing.T) []Listener {
	t.Helper()
	ls, err := List()
	if errors.Is(err, errors.ErrUnsupported) && runtime.GOOS != "darwin" && runtime.GOOS != "linux" {
		t.Skipf("%s's listeners aren't read", runtime.GOOS)
	}
	testcheck.NoErr(t, err)
	return ls
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
			ls := list(t)
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
	ls := list(t)
	if got := ofPid(OnPort(ls, uint16(l.Addr().(*net.TCPAddr).Port)), os.Getpid()); len(got) != 0 { //nolint:gosec // a port
		t.Fatalf("listed %v, on %v, which localhost doesn't reach", got, other)
	}
}

// TestListInTree finds a child's listener with its pid, in the processes
// proctree reads below this process and not in those of another.
func TestListInTree(t *testing.T) {
	pid, ports := listenElsewhere(t, "ipv4")
	port := ports[0]
	ls := list(t)
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

// TestReachingTwoProcesses checks Reaching against where the kernel sends
// a dial, with two processes listening on one port: the first on a free
// one, the second beside it (on the Mac, Go's SO_REUSEADDR lets it bind;
// on Linux, which refuses that bind (TestSecondBindRefused), both set
// SO_REUSEPORT). Reaching must name only the process the dial reached,
// but for two wildcards (either, the host whose dial may land on both).
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
			ls := list(t)
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

func BenchmarkList(b *testing.B) {
	for b.Loop() {
		if _, err := List(); err != nil {
			b.Fatal(err)
		}
	}
}

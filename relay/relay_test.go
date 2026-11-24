package relay

import (
	"bufio"
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"github.com/afrase/nushi/internal/testcheck"
)

func start(t *testing.T, lim Limits) string {
	t.Helper()
	srv := httptest.NewServer(New(lim))
	t.Cleanup(srv.Close)
	return "ws" + strings.TrimPrefix(srv.URL, "http")
}

func newID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

func newKey() ed25519.PrivateKey {
	_, k, _ := ed25519.GenerateKey(rand.Reader)
	return k
}

func idOf(k ed25519.PrivateKey) string { return ListenID(k.Public().(ed25519.PublicKey)) }

// pair connects a listener with key and a dialer on its id; the dialer
// speaks first.
func pair(t *testing.T, url string, key ed25519.PrivateKey) (l, d *Conn) {
	t.Helper()
	var dl Dialer
	l, err := dl.Listen(context.Background(), url, key)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = l.Close() })
	d, err = dl.Dial(context.Background(), url, idOf(key))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = d.Close() })
	return l, d
}

func send(t *testing.T, c *Conn, m string) {
	t.Helper()
	if err := c.WriteMessage([]byte(m)); err != nil {
		t.Fatal(err)
	}
}

func expect(t *testing.T, c *Conn, want string) {
	t.Helper()
	got, err := c.ReadMessage()
	if err != nil || string(got) != want {
		t.Fatalf("read %q, %v; want %q", got, err, want)
	}
}

// expectClosed checks the relay closes c within a few seconds.
func expectClosed(t *testing.T, c *Conn) {
	t.Helper()
	done := make(chan struct{}, 1)
	go func() {
		for {
			if _, err := c.ReadMessage(); err != nil {
				done <- struct{}{}
				return
			}
		}
	}()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("the relay kept the connection")
	}
}

func TestPeersMeetAndTalk(t *testing.T) {
	url := start(t, Defaults)
	l, d := pair(t, url, newKey())
	send(t, d, "hello")
	if err := l.Wait(); err != nil {
		t.Fatal(err)
	}
	expect(t, l, "hello")
	send(t, l, "back")
	expect(t, d, "back")
	testcheck.NoErr(t, d.Close())
	expectClosed(t, l)
}

func TestNoCrossTalk(t *testing.T) {
	url := start(t, Defaults)
	l1, d1 := pair(t, url, newKey())
	l2, d2 := pair(t, url, newKey())
	send(t, d1, "one")
	send(t, d2, "two")
	expect(t, l1, "one")
	expect(t, l2, "two")
	send(t, l2, "to two")
	send(t, l1, "to one")
	expect(t, d1, "to one")
	expect(t, d2, "to two")
}

// Two dialers on one id each get a listener of their own.
func TestEachDialerItsOwnListener(t *testing.T) {
	url := start(t, Defaults)
	key := newKey()
	l1, d1 := pair(t, url, key)
	send(t, d1, "a") // a dialer meets the listener waiting once it speaks
	expect(t, l1, "a")
	l2, d2 := pair(t, url, key)
	send(t, d2, "b")
	expect(t, l2, "b")
	send(t, l1, "to a")
	send(t, l2, "to b")
	expect(t, d1, "to a")
	expect(t, d2, "to b")
}

func TestDialerWithoutListener(t *testing.T) {
	lim := Defaults
	lim.DialWait = 100 * time.Millisecond
	url := start(t, lim)
	var dl Dialer
	d, err := dl.Dial(context.Background(), url, newID())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = d.Close() })
	send(t, d, "anyone?")
	expectClosed(t, d)
}

// A dialer that never speaks never takes the listener: one that speaks
// while it's still there meets the listener.
func TestSilentDialerTakesNothing(t *testing.T) {
	url := start(t, Defaults)
	key := newKey()
	l, _ := pair(t, url, key) // its dialer says nothing, and stays
	var dl Dialer
	d, err := dl.Dial(context.Background(), url, idOf(key))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = d.Close() })
	send(t, d, "me")
	expect(t, l, "me")
}

// A dialer has SpeakWait for its first message.
func TestSilentDialerIsClosed(t *testing.T) {
	lim := Defaults
	lim.SpeakWait = 100 * time.Millisecond
	var dl Dialer
	d, err := dl.Dial(context.Background(), start(t, lim), newID())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = d.Close() })
	expectClosed(t, d)
}

func TestListenerMayNotSpeakFirst(t *testing.T) {
	url := start(t, Defaults)
	var dl Dialer
	l, err := dl.Listen(context.Background(), url, newKey())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = l.Close() })
	send(t, l, "early")
	expectClosed(t, l)
}

func TestCaps(t *testing.T) {
	lim := Defaults
	lim.MaxMessage = 1000
	lim.PerID = 2
	lim.Total = 6
	lim.PerIP = 3
	lim.IPHeader = "X-Test-IP"
	s := New(lim).(*server)
	srv := httptest.NewServer(s)
	t.Cleanup(srv.Close)
	url := "ws" + strings.TrimPrefix(srv.URL, "http")

	t.Run("message size", func(t *testing.T) {
		l, d := pair(t, url, newKey())
		send(t, d, "hello")
		expect(t, l, "hello")
		send(t, d, strings.Repeat("x", 1001))
		expectClosed(t, d)
		expectClosed(t, l)
	})
	// The closed pair leaves the relay's count.
	if !testcheck.Eventually(func() bool { s.mu.Lock(); defer s.mu.Unlock(); return s.total == 0 }) {
		t.Fatal("the closed pair is still counted")
	}

	key := newKey()
	for _, addr := range []string{"192.0.2.1", "192.0.2.2"} {
		ws, code := from(url, "dial", idOf(key), addr)
		if ws == nil {
			t.Fatalf("refused (%d) under the caps", code)
		}
		t.Cleanup(func() { _ = ws.Close() })
	}
	if ws, code := from(url, "dial", idOf(key), "192.0.2.3"); ws != nil || code != http.StatusServiceUnavailable {
		t.Fatalf("a third dialer on one id: %d", code)
	}
	// Dialers don't keep the id's own listener out.
	var dl Dialer
	l, err := dl.Listen(context.Background(), url, key)
	if err != nil {
		t.Fatal("the key's listener was refused:", err)
	}
	t.Cleanup(func() { _ = l.Close() })
	for _, addr := range []string{"192.0.2.4", "192.0.2.5", "192.0.2.6"} {
		ws, code := from(url, "listen", newID(), addr)
		if ws == nil {
			t.Fatalf("refused (%d) under the caps", code)
		}
		t.Cleanup(func() { _ = ws.Close() })
	}
	// At Total the dialers without a listener make way
	// (TestUnpairedDialersMakeWay); with none left, a new one is refused.
	if !testcheck.Eventually(func() bool { s.mu.Lock(); defer s.mu.Unlock(); return len(s.unpaired) == 2 }) {
		t.Fatal("the dialers aren't counted as unpaired")
	}
	for _, addr := range []string{"192.0.2.7", "192.0.2.8"} {
		ws, code := from(url, "listen", newID(), addr)
		if ws == nil {
			t.Fatalf("refused (%d) with a dialer to make way", code)
		}
		t.Cleanup(func() { _ = ws.Close() })
	}
	if ws, code := from(url, "listen", newID(), "192.0.2.9"); ws != nil || code != http.StatusServiceUnavailable {
		t.Fatalf("a connection past Total with only listeners open: %d", code)
	}
	if _, code := from(url, "listen", "short", "192.0.2.10"); code != http.StatusNotFound {
		t.Fatalf("a malformed id: %d", code)
	}
}

func TestRate(t *testing.T) {
	lim := Defaults
	lim.Rate = 100_000
	lim.Burst = 10_000
	url := start(t, lim)
	l, d := pair(t, url, newKey())
	began := time.Now()
	for range 10 {
		send(t, d, strings.Repeat("x", 5000))
	}
	for range 10 {
		if _, err := l.ReadMessage(); err != nil {
			t.Fatal(err)
		}
	}
	// 50,000 bytes, 10,000 of them at once, at 100,000 a second.
	if took := time.Since(began); took < 350*time.Millisecond {
		t.Fatalf("50 kB went through in %v", took)
	}
}

func TestIdle(t *testing.T) {
	lim := Defaults
	lim.Idle = time.Second
	url := start(t, lim)

	// Pings keep a pair open. The relay rightly closes one whose pings a
	// stall of the runner held up for Idle, so a try that closed is tried
	// again; a relay that ignores pings closes every try.
	for try := 1; !pingsKeepOpen(t, url, lim.Idle); try++ {
		if try == 3 {
			t.Fatal("pings didn't keep a pair open")
		}
	}

	// Silence doesn't.
	l, d := pair(t, url, newKey())
	send(t, d, "hello")
	expect(t, l, "hello")
	expectClosed(t, d)
	expectClosed(t, l)
}

// pingsKeepOpen pairs, pings both ends a tenth of idle apart for 2.5
// idle, and says whether a message still crosses.
func pingsKeepOpen(t *testing.T, url string, idle time.Duration) bool {
	t.Helper()
	l, d := pair(t, url, newKey())
	pingEvery(t, l, idle/10)
	pingEvery(t, d, idle/10)
	got := make(chan string, 1)
	go func() { m, _ := l.ReadMessage(); got <- string(m) }() // a closed pair reads ""
	time.Sleep(5 * idle / 2)
	_ = d.WriteMessage([]byte("still here"))
	return <-got == "still here"
}

// pingEvery pings c's relay every d until the test ends, as a client
// does (KeepAlive). The test pings rather than the client, whose own
// pings come with a deadline: it gives up after three of them without a
// pong, a margin a loaded runner's stall breaks (TestIdle once read ""
// so on CI).
func pingEvery(t *testing.T, c *Conn, d time.Duration) {
	t.Helper()
	stop, done := make(chan struct{}), make(chan struct{})
	go func() {
		defer close(done)
		tick := time.NewTicker(d)
		defer tick.Stop()
		for {
			select {
			case <-stop:
				return
			case <-tick.C:
				_ = c.ws.WriteControl(websocket.PingMessage, nil, time.Now().Add(time.Second)) // a closed one fails: the test reads that
			}
		}
	}()
	t.Cleanup(func() { close(stop); <-done })
}

// The relay binary writes nothing to disk and logs only that it started:
// it runs in empty folders, carries a pair, refuses a few things and stops.
func TestNoDiskNoLogs(t *testing.T) {
	bin := filepath.Join(t.TempDir(), "nushi-relay")
	if out, err := exec.Command("go", "build", "-o", bin, "../cmd/nushi-relay").CombinedOutput(); err != nil {
		t.Fatalf("build: %v\n%s", err, out)
	}
	work, home, tmp := t.TempDir(), t.TempDir(), t.TempDir()
	cmd := exec.Command(bin, "-addr", "127.0.0.1:0", "-per-id", "2")
	cmd.Dir = work
	cmd.Env = []string{"HOME=" + home, "TMPDIR=" + tmp, "PATH=/usr/bin:/bin"}
	var stderr bytes.Buffer
	pr, pw, _ := os.Pipe()
	cmd.Stderr = pw
	cmd.Stdout = pw
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = cmd.Process.Kill() }) // a failure below doesn't leave it running
	testcheck.NoErr(t, pw.Close())
	r := bufio.NewReader(pr)
	first, err := r.ReadString('\n')
	if err != nil {
		t.Fatal(err)
	}
	stderr.WriteString(first)
	rest := make(chan struct{})
	go func() { _, _ = stderr.ReadFrom(r); close(rest) }()
	addr := first[strings.LastIndex(first, " ")+1 : len(first)-1]
	url := "ws://" + addr

	key := newKey()
	l, d := pair(t, url, key)
	send(t, d, "secret")
	expect(t, l, "secret")
	var dl Dialer
	for range 2 { // over the cap
		if c, err := dl.Dial(context.Background(), url, idOf(key)); err == nil {
			t.Cleanup(func() { _ = c.Close() })
		}
	}
	_, _ = dl.Dial(context.Background(), url, "bad")
	testcheck.NoErr(t, l.Close())
	testcheck.NoErr(t, d.Close())

	testcheck.NoErr(t, cmd.Process.Signal(syscall.SIGTERM))
	_ = cmd.Wait() // its exit after SIGTERM; what it logged is checked below
	<-rest
	if lines := strings.Split(strings.TrimSpace(stderr.String()), "\n"); len(lines) != 1 || !strings.Contains(lines[0], "listening on") {
		t.Fatalf("the relay logged:\n%s", stderr.String())
	}
	for _, dir := range []string{work, home, tmp} {
		if entries, _ := os.ReadDir(dir); len(entries) > 0 {
			t.Fatalf("the relay wrote into %s: %v", dir, entries)
		}
	}
}

// A hostile relay's oversized message ends the client's connection.
func TestClientTakesNoHugeMessage(t *testing.T) {
	var up websocket.Upgrader
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ws, err := up.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		defer func() { _ = ws.Close() }()
		_ = ws.WriteMessage(websocket.BinaryMessage, make([]byte, MaxMessage))   // the client checks what came
		_ = ws.WriteMessage(websocket.BinaryMessage, make([]byte, MaxMessage+1)) // as above
		time.Sleep(time.Second)
	}))
	defer srv.Close()
	var dl Dialer
	c, err := dl.Dial(context.Background(), "ws"+strings.TrimPrefix(srv.URL, "http"), newID())
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = c.Close() }()
	if m, err := c.ReadMessage(); err != nil || len(m) != MaxMessage {
		t.Fatalf("the largest message: %d bytes, %v", len(m), err)
	}
	if _, err := c.ReadMessage(); err == nil {
		t.Fatal("took a message over the limit")
	}
}

// from connects to the relay as if from addr (the relay reads X-Test-IP).
func from(url, side, id, addr string) (*websocket.Conn, int) {
	h := http.Header{"X-Test-Ip": {addr}}
	ws, resp, err := websocket.DefaultDialer.Dial(url+"/v1/"+side+"/"+id, h) //nolint:bodyclose // gorilla's Dial: the body of a failed handshake needn't be closed
	if err != nil {
		if resp != nil {
			return nil, resp.StatusCode
		}
		return nil, -1
	}
	return ws, 0
}

func TestPerAddressCaps(t *testing.T) {
	lim := Defaults
	lim.IPHeader = "X-Test-IP"
	lim.PerIP = 3
	lim.Total = 100
	lim.NewRate = 1e9 // the rate is back as soon as they leave
	h := New(lim).(*server)
	srv := httptest.NewServer(h)
	defer srv.Close()
	url := "ws" + strings.TrimPrefix(srv.URL, "http")

	var open []*websocket.Conn
	for range 3 {
		ws, code := from(url, "listen", newID(), "203.0.113.7")
		if ws == nil {
			t.Fatalf("refused (%d) under the cap", code)
		}
		open = append(open, ws)
	}
	if ws, code := from(url, "listen", newID(), "203.0.113.7"); ws != nil || code != http.StatusServiceUnavailable {
		t.Fatalf("a fourth connection from one address: %d", code)
	}
	// One IPv6 /64 counts as one address.
	for i, addr := range []string{"2001:db8::1", "2001:db8::2", "2001:db8::3"} {
		ws, code := from(url, "listen", newID(), addr)
		if i < 3 && ws == nil {
			t.Fatalf("refused (%d) under the cap", code)
		}
		open = append(open, ws)
	}
	if ws, code := from(url, "listen", newID(), "2001:db8::ffff"); ws != nil || code != http.StatusServiceUnavailable {
		t.Fatalf("a fourth connection from one /64: %d", code)
	}
	if ws, _ := from(url, "listen", newID(), "198.51.100.1"); ws == nil {
		t.Fatal("another address was refused")
	} else {
		open = append(open, ws)
	}
	for _, ws := range open {
		_ = ws.Close()
	}
	// Once the connections are gone (and the address's rate is back), the
	// relay holds nothing about the addresses.
	var n, total int
	if !testcheck.Eventually(func() bool {
		h.mu.Lock()
		defer h.mu.Unlock()
		n, total = len(h.ws.by), h.total
		return total == 0
	}) {
		t.Fatalf("%d connections still counted", total)
	}
	if n != 0 {
		t.Fatalf("%d addresses kept", n)
	}

	// One address never takes more than half of the total.
	if got := New(Limits{PerIP: 100, Total: 10}).(*server).lim.PerIP; got != 5 {
		t.Fatalf("PerIP %d of 10", got)
	}
}

func TestNewConnectionRate(t *testing.T) {
	lim := Defaults
	lim.IPHeader = "X-Test-IP"
	lim.NewBurst = 3
	lim.NewRate = 0.001
	srv := httptest.NewServer(New(lim))
	defer srv.Close()
	url := "ws" + strings.TrimPrefix(srv.URL, "http")
	for range 3 {
		ws, code := from(url, "listen", newID(), "203.0.113.9")
		if ws == nil {
			t.Fatalf("refused (%d) within the burst", code)
		}
		_ = ws.Close()
	}
	if ws, code := from(url, "listen", newID(), "203.0.113.9"); ws != nil || code != http.StatusTooManyRequests {
		t.Fatalf("a fourth new connection at once: %d", code)
	}
	if ws, _ := from(url, "listen", newID(), "203.0.113.10"); ws == nil {
		t.Fatal("another address was refused")
	} else {
		_ = ws.Close()
	}
}

// A listener waits only so long, pings or not; one with a peer stays.
func TestWaitingLifetime(t *testing.T) {
	lim := Defaults
	lim.MaxWait = time.Second
	url := start(t, lim)
	var dl Dialer
	began := time.Now() // before the relay starts its wait
	l, err := dl.Listen(context.Background(), url, newKey())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = l.Close() })
	pingEvery(t, l, 200*time.Millisecond)
	expectClosed(t, l)
	if time.Since(began) < lim.MaxWait {
		t.Fatal("closed too soon")
	}

	// One with a peer stays when its wait's time comes. That moment is run
	// here, not waited for: a MaxWait short enough to wait out could pass
	// before a slow machine has brought the two together.
	s := New(Defaults).(*server)
	srv := httptest.NewServer(s)
	t.Cleanup(srv.Close)
	key := newKey()
	l, d := pair(t, "ws"+strings.TrimPrefix(srv.URL, "http"), key)
	s.mu.Lock()
	waiting := s.rooms[idOf(key)].waiting // the dialer hasn't spoken yet
	s.mu.Unlock()
	send(t, d, "hello")
	expect(t, l, "hello")
	waiting.expire()
	send(t, d, "still here")
	expect(t, l, "still here")
}

// Only the holder of an id's key listens there: someone who knows the id
// (a revoked phone, anyone who saw a ws:// URL) can neither answer the
// challenge nor take the dials meant for the key's holder.
func TestListenNeedsTheKey(t *testing.T) {
	url := start(t, Defaults)
	key, other := newKey(), newKey()
	id := idOf(key)
	raw := func() (*websocket.Conn, []byte) {
		ws, _, err := websocket.DefaultDialer.Dial(url+"/v1/listen/"+id, nil) //nolint:bodyclose // gorilla's Dial: the body of a failed handshake needn't be closed
		if err != nil {
			t.Fatal(err)
		}
		testcheck.NoErr(t, ws.SetReadDeadline(time.Now().Add(30*time.Second)))
		_, m, err := ws.ReadMessage()
		if err != nil || !bytes.HasPrefix(m, []byte(challengeTag)) {
			t.Fatalf("no challenge: %q %v", m, err)
		}
		return ws, m[len(challengeTag):]
	}
	for name, answer := range map[string]func(challenge []byte) []byte{
		"another key": func(c []byte) []byte {
			return append(other.Public().(ed25519.PublicKey), ed25519.Sign(other, proven(id, c))...)
		},
		"an old signature": func([]byte) []byte {
			return append(key.Public().(ed25519.PublicKey), ed25519.Sign(key, proven(id, make([]byte, 32)))...)
		},
	} {
		ws, challenge := raw()
		testcheck.NoErr(t, ws.WriteMessage(websocket.BinaryMessage, answer(challenge)))
		if _, _, err := ws.ReadMessage(); err == nil {
			t.Errorf("%s listened", name)
		}
		_ = ws.Close()
	}

	squat, _ := raw() // never answers
	t.Cleanup(func() { _ = squat.Close() })
	l, d := pair(t, url, key)
	send(t, d, "for the key's holder")
	expect(t, l, "for the key's holder")
}

// A second listener with the key (the same daemon, back) replaces the one
// waiting.
func TestSecondListenerReplacesFirst(t *testing.T) {
	url := start(t, Defaults)
	key := newKey()
	var dl Dialer
	l1, err := dl.Listen(context.Background(), url, key)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = l1.Close() })
	l2, d := pair(t, url, key)
	expectClosed(t, l1)
	send(t, d, "to the newest")
	expect(t, l2, "to the newest")
}

// plainServer is the relay's server on a port of its own, until the test
// ends.
func plainServer(t *testing.T, lim Limits) string {
	t.Helper()
	srv := NewServer(lim)
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	go func() { _ = srv.Serve(ln) }()
	t.Cleanup(func() { _ = srv.Close() })
	return ln.Addr().String()
}

// healthz asks once on a new connection to addr, keeping it open until
// the test ends; it says whether the relay answered.
func healthz(t *testing.T, addr string) (net.Conn, bool) {
	t.Helper()
	c, err := net.Dial("tcp", addr)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = c.Close() })
	testcheck.NoErr(t, c.SetDeadline(time.Now().Add(30*time.Second)))
	_, _ = io.WriteString(c, "GET /healthz HTTP/1.1\r\nHost: relay\r\n\r\n") // a refused one may be closed already: the answer says
	resp, err := http.ReadResponse(bufio.NewReader(c), nil)
	if err == nil {
		_ = resp.Body.Close()
	}
	return c, err == nil
}

// Connections that aren't WebSockets count under the caps too: one address
// can't pile up keep-alive connections.
func TestPlainConnectionsAreCapped(t *testing.T) {
	lim := Defaults
	lim.PlainPerIP = 3
	lim.HTTPIdle, lim.FirstWait = time.Hour, time.Hour // none goes within the test
	addr := plainServer(t, lim)
	// A WebSocket counts as one only until it is one.
	l, d := pair(t, "ws://"+addr, newKey())
	for range 3 {
		if _, ok := healthz(t, addr); !ok {
			t.Fatal("refused under the cap")
		}
	}
	if _, ok := healthz(t, addr); ok {
		t.Fatal("a fourth idle connection from one address")
	}
	send(t, d, "still")
	expect(t, l, "still")
}

// An idle plain connection goes after HTTPIdle, and its place is free
// again.
func TestIdleHTTPConnections(t *testing.T) {
	lim := Defaults
	lim.PlainPerIP = 1
	lim.HTTPIdle = 300 * time.Millisecond
	lim.FirstWait = time.Hour // only idleness closes one here
	addr := plainServer(t, lim)
	c, ok := healthz(t, addr)
	if !ok {
		t.Fatal("refused under the cap")
	}
	if _, err := c.Read(make([]byte, 1)); !errors.Is(err, io.EOF) {
		t.Fatalf("an idle connection stayed: %v", err)
	}
	// The server uncounts a connection just after it closes it.
	if !testcheck.Eventually(func() bool { _, ok := healthz(t, addr); return ok }) {
		t.Fatal("refused once the idle one went")
	}
}

// Behind a proxy that appends to X-Forwarded-For, what the client wrote
// there doesn't count: the address is the one the proxies added.
func TestForwardedForFromTheRight(t *testing.T) {
	for _, hops := range []int{1, 2} {
		lim := Defaults
		lim.IPHeader = "X-Forwarded-For"
		lim.IPHops = hops
		lim.PerIP = 2
		url := start(t, lim)
		var open []*websocket.Conn
		for i := range 3 {
			h := fmt.Sprintf("198.51.100.%d, 203.0.113.7", i) // a new made-up address each time, then the proxy's entry
			if hops == 2 {
				h += ", 192.0.2.99" // and the next proxy's
			}
			ws, resp, err := websocket.DefaultDialer.Dial(url+"/v1/dial/"+newID(), http.Header{"X-Forwarded-For": {h}}) //nolint:bodyclose // gorilla's Dial: the body of a failed handshake needn't be closed
			if i < 2 && err != nil {
				t.Fatalf("hops %d: refused under the cap: %v", hops, err)
			}
			if i == 2 && (err == nil || resp.StatusCode != http.StatusServiceUnavailable) {
				t.Fatalf("hops %d: made-up addresses got past the cap", hops)
			}
			if ws != nil {
				open = append(open, ws)
			}
		}
		for _, ws := range open {
			_ = ws.Close()
		}
	}
}

// counted counts a listener's accepted connections.
type counted struct {
	net.Listener
	n atomic.Int64
}

func (a *counted) Accept() (net.Conn, error) {
	c, err := a.Listener.Accept()
	if err == nil {
		a.n.Add(1)
	}
	return c, err
}

// A flood of idle sockets from many addresses (behind a proxy, which only
// the header tells apart) doesn't keep a daemon and a phone from meeting:
// the ones idle longest make way. The flood is twice Total, dialled no
// faster than the relay accepts (macOS's backlog is 128, and a loaded
// machine accepts slowly), and all of it in before the pair comes, so the
// pair is the newest and nothing still queued sheds it.
func TestIdleFloodDoesntStarve(t *testing.T) {
	lim := Defaults
	lim.IPHeader = "X-Test-IP"
	lim.Total = 50
	srv := NewServer(lim)
	inner, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	ln := &counted{Listener: inner}
	go func() { _ = srv.Serve(ln) }()
	defer func() { _ = srv.Close() }()
	const flood = 100
	for i := range flood {
		if !testcheck.Eventually(func() bool { return int64(i)-ln.n.Load() < 32 }) {
			t.Fatal("the relay stopped accepting")
		}
		c, err := net.Dial("tcp", ln.Addr().String())
		if err != nil {
			t.Fatal(err)
		}
		defer func() { _ = c.Close() }()
		if i%2 == 0 { // half of them asked once, from an address each, and wait
			_, _ = fmt.Fprintf(c, "GET /healthz HTTP/1.1\r\nHost: relay\r\nX-Test-IP: 198.51.%d.%d\r\n\r\n", i/256, i%256) // one the relay dropped already is part of the flood
		}
	}
	if !testcheck.Eventually(func() bool { return ln.n.Load() >= flood }) {
		t.Fatal("the flood wasn't all accepted")
	}
	l, d := pair(t, "ws://"+ln.Addr().String(), newKey())
	send(t, d, "through")
	expect(t, l, "through")
}

// Behind a proxy the per-address cap on plain connections counts the
// header's address.
func TestPlainCapBehindAProxy(t *testing.T) {
	lim := Defaults
	lim.IPHeader = "X-Test-IP"
	lim.PlainPerIP = 2
	srv := NewServer(lim)
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	go func() { _ = srv.Serve(ln) }()
	defer func() { _ = srv.Close() }()
	ask := func(addr string) int {
		c, err := net.Dial("tcp", ln.Addr().String())
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { _ = c.Close() })
		_, _ = fmt.Fprintf(c, "GET /healthz HTTP/1.1\r\nHost: relay\r\nX-Test-IP: %s\r\n\r\n", addr) // a refusal may close it first: the status says
		resp, err := http.ReadResponse(bufio.NewReader(c), nil)
		if err != nil {
			t.Fatal(err)
		}
		_ = resp.Body.Close()
		return resp.StatusCode
	}
	for range 2 {
		if code := ask("203.0.113.5"); code != http.StatusOK {
			t.Fatalf("under the cap: %d", code)
		}
	}
	if code := ask("203.0.113.5"); code != http.StatusServiceUnavailable {
		t.Fatalf("a third plain connection from one address: %d", code)
	}
	if code := ask("203.0.113.6"); code != http.StatusOK {
		t.Fatalf("another address: %d", code)
	}
}

// Behind a proxy, a flood of connections that send their headers slowly
// (no address known yet, never idle) doesn't keep a daemon and a phone
// from meeting either, and each goes after FirstWait.
func TestSlowHeadersFloodDoesntStarve(t *testing.T) {
	lim := Defaults
	lim.IPHeader = "X-Test-IP"
	lim.Total = 50
	lim.FirstWait = 500 * time.Millisecond
	srv := NewServer(lim)
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	go func() { _ = srv.Serve(ln) }()
	defer func() { _ = srv.Close() }()
	// Twice Total, and under the listen backlog (macOS's somaxconn is 128):
	// a connect the backlog has no room for is reset by the kernel before
	// the relay sees it, and the pair's dials come after the flood's.
	const flood = 100
	var slow []net.Conn
	for range flood {
		c, err := net.Dial("tcp", ln.Addr().String())
		if err != nil {
			t.Fatal(err)
		}
		defer func() { _ = c.Close() }()
		_, _ = io.WriteString(c, "GET /healthz HTTP/1.1\r\nHost: rel") // and no more; one the relay dropped already is part of the flood
		slow = append(slow, c)
	}
	l, d := pair(t, "ws://"+ln.Addr().String(), newKey())
	send(t, d, "through")
	expect(t, l, "through")
	// Closed, not timed out: an end or a reset, which is the end when the
	// relay closed it before its server had read the headers' start (the
	// kernel resets a connection closed with input unread; under load,
	// FirstWait can pass before that read).
	last := slow[len(slow)-1]
	testcheck.NoErr(t, last.SetReadDeadline(time.Now().Add(30*time.Second)))
	if _, err := last.Read(make([]byte, 1)); !errors.Is(err, io.EOF) && !errors.Is(err, syscall.ECONNRESET) {
		t.Fatalf("a connection without its headers stayed past FirstWait: %v", err)
	}
}

// Listening needs only a key of one's own, so listeners from one address,
// an IPv6 /48 (a /56 of /64s included), are capped far below PerIP: a
// few addresses can't hold every connection (security review 2026-11-04,
// L4). Dialers aren't listeners, and a listener that left frees its place.
func TestListenersPerAddress(t *testing.T) {
	lim := Defaults
	lim.IPHeader = "X-Test-IP"
	lim.ListenPerIP = 2
	lim.NewRate = 1e9
	h := New(lim).(*server)
	srv := httptest.NewServer(h)
	defer srv.Close()
	url := "ws" + strings.TrimPrefix(srv.URL, "http")
	var open []*websocket.Conn
	defer func() {
		for _, ws := range open {
			_ = ws.Close()
		}
	}()
	listen := func(addr string) int {
		ws, code := from(url, "listen", newID(), addr)
		if ws != nil {
			open = append(open, ws)
		}
		return code
	}
	for _, addr := range []string{"203.0.113.7", "203.0.113.7", "2001:db8:1:100::1", "2001:db8:1:200::1"} {
		if code := listen(addr); code != 0 {
			t.Fatalf("%s refused (%d) under the cap", addr, code)
		}
	}
	for _, addr := range []string{"203.0.113.7", "2001:db8:1:ff00::1"} {
		if code := listen(addr); code != http.StatusServiceUnavailable {
			t.Errorf("a third listener from %s: %d", addr, code)
		}
	}
	if code := listen("198.51.100.1"); code != 0 {
		t.Errorf("another address was refused: %d", code)
	}
	if ws, code := from(url, "dial", newID(), "203.0.113.7"); ws == nil {
		t.Errorf("a dialer from a full address was refused: %d", code)
	} else {
		_ = ws.Close()
	}
	_ = open[0].Close()
	if !testcheck.Eventually(func() bool { return listen("203.0.113.7") == 0 }) {
		t.Error("a listener that left still counts")
	}
}

// The address header is believed only from a trusted proxy: a client that
// reaches the relay directly can't pick a new address for each request
// and so slip the per-address caps.
func TestHeaderOnlyFromTrustedProxies(t *testing.T) {
	lim := Defaults
	lim.IPHeader = "X-Test-IP"
	lim.PerIP = 2
	lim.Total = 100
	lim.NewRate = 1e9
	lim.TrustedProxies = []netip.Prefix{netip.MustParsePrefix("192.0.2.0/24")} // not this test's loopback
	url := start(t, lim)
	for i := range 2 {
		ws, code := from(url, "listen", newID(), fmt.Sprintf("203.0.113.%d", i))
		if ws == nil {
			t.Fatalf("refused (%d) under the cap", code)
		}
		t.Cleanup(func() { _ = ws.Close() })
	}
	if ws, code := from(url, "listen", newID(), "203.0.113.99"); ws != nil || code != http.StatusServiceUnavailable {
		if ws != nil {
			_ = ws.Close()
		}
		t.Fatalf("a direct client's header was believed: %d", code)
	}

	// Loopback is trusted when none are named: a proxy on the same machine.
	lim.TrustedProxies = nil
	url = start(t, lim)
	for i := range 3 {
		ws, code := from(url, "listen", newID(), fmt.Sprintf("203.0.113.%d", i))
		if ws == nil {
			t.Fatalf("a local proxy's header wasn't believed: %d", code)
		}
		t.Cleanup(func() { _ = ws.Close() })
	}
}

// Behind a proxy, a plain connection from a peer that isn't one is counted
// under its own address at once.
func TestPlainCapForADirectPeer(t *testing.T) {
	lim := Defaults
	lim.IPHeader = "X-Test-IP"
	lim.PlainPerIP = 2
	lim.TrustedProxies = []netip.Prefix{netip.MustParsePrefix("192.0.2.0/24")}
	srv := NewServer(lim)
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	go func() { _ = srv.Serve(ln) }()
	defer func() { _ = srv.Close() }()
	var codes strings.Builder
	for i := range 3 {
		c, err := net.Dial("tcp", ln.Addr().String())
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { _ = c.Close() })
		_, _ = fmt.Fprintf(c, "GET /healthz HTTP/1.1\r\nHost: relay\r\nX-Test-IP: 198.51.100.%d\r\n\r\n", i)
		resp, err := http.ReadResponse(bufio.NewReader(c), nil)
		if err != nil {
			codes.WriteString("closed ")
			continue
		}
		_ = resp.Body.Close()
		codes.WriteString(strconv.Itoa(resp.StatusCode) + " ")
	}
	if codes.String() != "200 200 closed " {
		t.Fatalf("three plain connections from one direct peer: %s", codes.String())
	}
}

// Listeners are capped under the address the relay believes: from a peer
// that isn't a trusted proxy, its own, whatever address its header names,
// so a direct client can't spread its listeners over made-up addresses;
// from a trusted proxy, the header's, so its clients don't share the
// proxy's one cap.
func TestListenerCapUnderTheBelievedAddress(t *testing.T) {
	lim := Defaults
	lim.IPHeader = "X-Test-IP"
	lim.ListenPerIP = 2
	lim.NewRate = 1e9
	listen := func(url, addr string) int {
		ws, code := from(url, "listen", newID(), addr)
		if ws != nil {
			t.Cleanup(func() { _ = ws.Close() })
		}
		return code
	}

	lim.TrustedProxies = []netip.Prefix{netip.MustParsePrefix("192.0.2.0/24")} // not this test's loopback
	url := start(t, lim)
	for i := range 2 {
		if code := listen(url, fmt.Sprintf("203.0.113.%d", i)); code != 0 {
			t.Fatalf("a direct peer's listener %d refused (%d) under the cap", i, code)
		}
	}
	if code := listen(url, "198.51.100.1"); code != http.StatusServiceUnavailable {
		t.Errorf("a direct peer's third listener, under another header address: %d", code)
	}
	if ws, code := from(url, "dial", newID(), "198.51.100.2"); ws == nil {
		t.Errorf("a dialer from a peer with every listener was refused: %d", code)
	} else {
		_ = ws.Close()
	}

	lim.TrustedProxies = []netip.Prefix{netip.MustParsePrefix("127.0.0.0/8")}
	url = start(t, lim)
	for _, addr := range []string{"203.0.113.7", "203.0.113.7", "198.51.100.1", "2001:db8:1::1"} {
		if code := listen(url, addr); code != 0 {
			t.Fatalf("a trusted proxy's client %s refused (%d) under its own cap", addr, code)
		}
	}
	if code := listen(url, "203.0.113.7"); code != http.StatusServiceUnavailable {
		t.Errorf("a third listener from one client behind a trusted proxy: %d", code)
	}
}

// Dialers need no key, and an IPv6 /48 holds 65,536 /64s: what one /48
// opens is counted together, under half of Total, so silent dialers from
// its /64s can't fill the relay and keep a daemon's wait out.
func TestOne48CantFillTheRelay(t *testing.T) {
	lim := Defaults
	lim.IPHeader = "X-Test-IP"
	lim.Total = 40 // and so PerIP 20
	lim.NewRate = 1e9
	url := start(t, lim)
	var open []*websocket.Conn
	defer func() {
		for _, ws := range open {
			_ = ws.Close()
		}
	}()
	for n := range 10 {
		for range 3 {
			if ws, _ := from(url, "dial", newID(), fmt.Sprintf("2001:db8:42:%x::1", n)); ws != nil {
				open = append(open, ws)
			}
		}
	}
	if len(open) > lim.Total/2 {
		t.Fatalf("one /48 holds %d of %d", len(open), lim.Total)
	}
	ws, code := from(url, "dial", newID(), "2001:db8:43::1")
	if ws == nil {
		t.Fatalf("another /48 refused: %d", code)
	}
	open = append(open, ws)
}

// When Total are open, a dialer without a listener makes way for a new
// connection: the oldest silent one, then the one waiting longest for a
// listener. Each holds its place 20 s at most anyway, but a few networks'
// worth renewed could otherwise hold every place (security review
// 2026-11-18, finding 2). Listeners and paired dialers stay, and with
// only those open a new connection is refused.
func TestUnpairedDialersMakeWay(t *testing.T) {
	lim := Defaults
	lim.IPHeader = "X-Test-IP"
	lim.Total = 4
	lim.NewRate = 1e9
	lim.SpeakWait, lim.DialWait = time.Hour, time.Hour // only making way ends one here
	s := New(lim).(*server)
	srv := httptest.NewServer(s)
	t.Cleanup(srv.Close)
	url := "ws" + strings.TrimPrefix(srv.URL, "http")
	open := func(side, addr string) *websocket.Conn {
		t.Helper()
		ws, code := from(url, side, newID(), addr)
		if ws == nil {
			t.Fatalf("a %s from %s refused: %d", side, addr, code)
		}
		t.Cleanup(func() { _ = ws.Close() })
		return ws
	}
	unpaired := func(want, spoke int) bool {
		s.mu.Lock()
		defer s.mu.Unlock()
		n := 0
		for _, u := range s.unpaired {
			if u.spoke {
				n++
			}
		}
		return len(s.unpaired) == want && n == spoke
	}
	waiting := open("dial", "192.0.2.1") // the oldest: it speaks, and waits for a listener that never comes
	testcheck.NoErr(t, waiting.WriteMessage(websocket.BinaryMessage, []byte("hello")))
	if !testcheck.Eventually(func() bool { return unpaired(1, 1) }) {
		t.Fatal("the dialer isn't waiting")
	}
	silent := open("dial", "192.0.2.2")
	l, d := pair(t, url, newKey())
	send(t, d, "paired")
	expect(t, l, "paired")
	if !testcheck.Eventually(func() bool { return unpaired(2, 1) }) {
		t.Fatal("the paired dialer still counts as unpaired, or the silent one doesn't")
	}
	gone := func(ws *websocket.Conn, what string) {
		t.Helper()
		testcheck.NoErr(t, ws.SetReadDeadline(time.Now().Add(30*time.Second)))
		if _, _, err := ws.ReadMessage(); err == nil || errors.Is(err, os.ErrDeadlineExceeded) {
			t.Fatalf("the %s dialer stayed: %v", what, err)
		}
	}
	open("listen", "192.0.2.3")
	gone(silent, "silent")
	open("listen", "192.0.2.4")
	gone(waiting, "waiting")
	if !testcheck.Eventually(func() bool { s.mu.Lock(); defer s.mu.Unlock(); return s.total == lim.Total }) {
		t.Fatal("the dialers that made way still count")
	}
	if ws, code := from(url, "listen", newID(), "192.0.2.5"); ws != nil || code != http.StatusServiceUnavailable {
		t.Fatalf("a connection past Total with only listeners and a pair open: %d", code)
	}
	send(t, d, "still")
	expect(t, l, "still")
}

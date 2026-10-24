package relay

import (
	"bufio"
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/gorilla/websocket"
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
	t.Cleanup(func() { l.Close() })
	d, err = dl.Dial(context.Background(), url, idOf(key))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { d.Close() })
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
	done := make(chan error, 1)
	go func() {
		for {
			if _, err := c.ReadMessage(); err != nil {
				done <- err
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
	d.Close()
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
	defer d.Close()
	send(t, d, "anyone?")
	expectClosed(t, d)
}

// A dialer that never speaks never takes the listener.
func TestSilentDialerTakesNothing(t *testing.T) {
	lim := Defaults
	lim.DialWait = 200 * time.Millisecond
	url := start(t, lim)
	key := newKey()
	l, _ := pair(t, url, key)
	time.Sleep(300 * time.Millisecond) // the silent dialer is gone
	var dl Dialer
	d, err := dl.Dial(context.Background(), url, idOf(key))
	if err != nil {
		t.Fatal(err)
	}
	defer d.Close()
	send(t, d, "me")
	expect(t, l, "me")
}

func TestListenerMayNotSpeakFirst(t *testing.T) {
	url := start(t, Defaults)
	var dl Dialer
	l, err := dl.Listen(context.Background(), url, newKey())
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
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
	url := start(t, lim)

	t.Run("message size", func(t *testing.T) {
		l, d := pair(t, url, newKey())
		send(t, d, "hello")
		expect(t, l, "hello")
		send(t, d, strings.Repeat("x", 1001))
		expectClosed(t, d)
		expectClosed(t, l)
	})
	time.Sleep(100 * time.Millisecond) // the closed pair leaves

	key := newKey()
	for _, addr := range []string{"192.0.2.1", "192.0.2.2"} {
		ws, code := from(url, "dial", idOf(key), addr)
		if ws == nil {
			t.Fatalf("refused (%d) under the caps", code)
		}
		defer ws.Close()
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
	defer l.Close()
	for _, addr := range []string{"192.0.2.4", "192.0.2.5", "192.0.2.6"} {
		ws, code := from(url, "listen", newID(), addr)
		if ws == nil {
			t.Fatalf("refused (%d) under the caps", code)
		}
		defer ws.Close()
	}
	if ws, code := from(url, "listen", newID(), "192.0.2.7"); ws != nil || code != http.StatusServiceUnavailable {
		t.Fatalf("a seventh connection in all: %d", code)
	}
	if _, code := from(url, "listen", "short", "192.0.2.8"); code != http.StatusNotFound {
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
	lim.Idle = 300 * time.Millisecond
	url := start(t, lim)

	// Pings keep a connection open.
	old := KeepAlive
	KeepAlive = 50 * time.Millisecond
	l, d := pair(t, url, newKey())
	KeepAlive = old
	got := make(chan string, 1)
	go func() { m, _ := l.ReadMessage(); got <- string(m) }() // reading takes the pongs in
	time.Sleep(time.Second)
	send(t, d, "still here")
	if m := <-got; m != "still here" {
		t.Fatalf("read %q", m)
	}

	// Silence doesn't.
	l, d = pair(t, url, newKey())
	send(t, d, "hello")
	expect(t, l, "hello")
	expectClosed(t, d)
	expectClosed(t, l)
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
	pw.Close()
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
			defer c.Close()
		}
	}
	_, _ = dl.Dial(context.Background(), url, "bad")
	l.Close()
	d.Close()

	cmd.Process.Signal(syscall.SIGTERM)
	cmd.Wait()
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
		defer ws.Close()
		ws.WriteMessage(websocket.BinaryMessage, make([]byte, MaxMessage))
		ws.WriteMessage(websocket.BinaryMessage, make([]byte, MaxMessage+1))
		time.Sleep(time.Second)
	}))
	defer srv.Close()
	var dl Dialer
	c, err := dl.Dial(context.Background(), "ws"+strings.TrimPrefix(srv.URL, "http"), newID())
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
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
	ws, resp, err := websocket.DefaultDialer.Dial(url+"/v1/"+side+"/"+id, h)
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
		ws.Close()
	}
	// Once the connections are gone (and the address's rate is back), the
	// relay holds nothing about the addresses.
	deadline := time.Now().Add(5 * time.Second)
	for {
		h.mu.Lock()
		n, total := len(h.sources), h.total
		h.mu.Unlock()
		if total == 0 {
			if n != 0 {
				t.Fatalf("%d addresses kept", n)
			}
			break
		}
		if time.Now().After(deadline) {
			t.Fatalf("%d connections still counted", total)
		}
		time.Sleep(20 * time.Millisecond)
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
		ws.Close()
	}
	if ws, code := from(url, "listen", newID(), "203.0.113.9"); ws != nil || code != http.StatusTooManyRequests {
		t.Fatalf("a fourth new connection at once: %d", code)
	}
	if ws, _ := from(url, "listen", newID(), "203.0.113.10"); ws == nil {
		t.Fatal("another address was refused")
	} else {
		ws.Close()
	}
}

// A listener waits only so long, pings or not; one with a peer stays.
func TestWaitingLifetime(t *testing.T) {
	lim := Defaults
	lim.MaxWait = 300 * time.Millisecond
	url := start(t, lim)
	old := KeepAlive
	KeepAlive = 50 * time.Millisecond
	defer func() { KeepAlive = old }()
	var dl Dialer
	l, err := dl.Listen(context.Background(), url, newKey())
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	began := time.Now()
	expectClosed(t, l)
	if time.Since(began) < 250*time.Millisecond {
		t.Fatal("closed too soon")
	}

	l, d := pair(t, url, newKey())
	send(t, d, "hello")
	expect(t, l, "hello")
	got := make(chan string, 1)
	go func() { m, _ := l.ReadMessage(); got <- string(m) }()
	time.Sleep(500 * time.Millisecond)
	send(t, d, "still here")
	if m := <-got; m != "still here" {
		t.Fatalf("read %q", m)
	}
}

// Only the holder of an id's key listens there: someone who knows the id
// (a revoked phone, anyone who saw a ws:// URL) can neither answer the
// challenge nor take the dials meant for the key's holder.
func TestListenNeedsTheKey(t *testing.T) {
	url := start(t, Defaults)
	key, other := newKey(), newKey()
	id := idOf(key)
	raw := func() (*websocket.Conn, []byte) {
		ws, _, err := websocket.DefaultDialer.Dial(url+"/v1/listen/"+id, nil)
		if err != nil {
			t.Fatal(err)
		}
		ws.SetReadDeadline(time.Now().Add(2 * time.Second))
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
		ws.WriteMessage(websocket.BinaryMessage, answer(challenge))
		if _, _, err := ws.ReadMessage(); err == nil {
			t.Errorf("%s listened", name)
		}
		ws.Close()
	}

	squat, _ := raw() // never answers
	defer squat.Close()
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
	defer l1.Close()
	l2, d := pair(t, url, key)
	expectClosed(t, l1)
	send(t, d, "to the newest")
	expect(t, l2, "to the newest")
}

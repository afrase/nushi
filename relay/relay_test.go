package relay

import (
	"bufio"
	"bytes"
	"context"
	"crypto/rand"
	"encoding/base64"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
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

// pair connects a listener and a dialer on id; the dialer speaks first.
func pair(t *testing.T, url, id string) (l, d *Conn) {
	t.Helper()
	var dl Dialer
	l, err := dl.Listen(context.Background(), url, id)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close() })
	d, err = dl.Dial(context.Background(), url, id)
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
	l, d := pair(t, url, newID())
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
	l1, d1 := pair(t, url, newID())
	l2, d2 := pair(t, url, newID())
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
	id := newID()
	l1, d1 := pair(t, url, id)
	l2, d2 := pair(t, url, id)
	send(t, d1, "a")
	send(t, d2, "b")
	expect(t, l1, "a")
	expect(t, l2, "b")
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
	id := newID()
	l, _ := pair(t, url, id)
	time.Sleep(300 * time.Millisecond) // the silent dialer is gone
	var dl Dialer
	d, err := dl.Dial(context.Background(), url, id)
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
	l, err := dl.Listen(context.Background(), url, newID())
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
	lim.Total = 3
	url := start(t, lim)
	var dl Dialer
	ctx := context.Background()

	t.Run("message size", func(t *testing.T) {
		l, d := pair(t, url, newID())
		send(t, d, "hello")
		expect(t, l, "hello")
		send(t, d, strings.Repeat("x", 1001))
		expectClosed(t, d)
		expectClosed(t, l)
	})
	time.Sleep(100 * time.Millisecond) // the closed pair leaves

	id := newID()
	a, err := dl.Listen(ctx, url, id)
	if err != nil {
		t.Fatal(err)
	}
	defer a.Close()
	b, err := dl.Listen(ctx, url, id)
	if err != nil {
		t.Fatal(err)
	}
	defer b.Close()
	if c, err := dl.Listen(ctx, url, id); err == nil || !strings.Contains(err.Error(), "503") {
		c.Close()
		t.Fatalf("a third connection on one id: %v", err)
	}
	c, err := dl.Listen(ctx, url, newID())
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	if d, err := dl.Listen(ctx, url, newID()); err == nil || !strings.Contains(err.Error(), "503") {
		d.Close()
		t.Fatalf("a fourth connection in all: %v", err)
	}
	if _, err := dl.Listen(ctx, url, "short"); err == nil {
		t.Fatal("a malformed id was taken")
	}
}

func TestRate(t *testing.T) {
	lim := Defaults
	lim.Rate = 100_000
	lim.Burst = 10_000
	url := start(t, lim)
	l, d := pair(t, url, newID())
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
	l, d := pair(t, url, newID())
	KeepAlive = old
	got := make(chan string, 1)
	go func() { m, _ := l.ReadMessage(); got <- string(m) }() // reading takes the pongs in
	time.Sleep(time.Second)
	send(t, d, "still here")
	if m := <-got; m != "still here" {
		t.Fatalf("read %q", m)
	}

	// Silence doesn't.
	l, d = pair(t, url, newID())
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

	id := newID()
	l, d := pair(t, url, id)
	send(t, d, "secret")
	expect(t, l, "secret")
	var dl Dialer
	if c, err := dl.Listen(context.Background(), url, id); err == nil { // over the cap
		c.Close()
	}
	_, _ = dl.Listen(context.Background(), url, "bad")
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

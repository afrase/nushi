package sysproxy

import (
	"bufio"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/afrase/nushi/relay"
)

// A slow lookup holds up only the lookups for its own URL.
func TestLookupsDontWaitForEachOther(t *testing.T) {
	t.Setenv("HTTPS_PROXY", "")
	t.Setenv("https_proxy", "")
	t.Setenv("HTTP_PROXY", "")
	t.Setenv("http_proxy", "")
	release := make(chan struct{})
	calls := 0
	var mu sync.Mutex
	old := lookup
	lookup = func(u *url.URL, _ bool) ([]*url.URL, time.Duration) {
		mu.Lock()
		calls++
		mu.Unlock()
		if u.Host == "slow.example" {
			<-release
		}
		return []*url.URL{nil}, time.Minute
	}
	defer func() { lookup = old }()
	slow, _ := url.Parse("wss://slow.example/v1/listen/a")
	fast, _ := url.Parse("wss://fast.example/v1/listen/b")
	done := make(chan struct{}, 2)
	go func() { _, _ = For(slow); done <- struct{}{} }() // what matters is that fast doesn't wait for it
	go func() { _, _ = For(slow); done <- struct{}{} }()
	time.Sleep(50 * time.Millisecond)
	if _, err := For(fast); err != nil {
		t.Fatal(err)
	}
	close(release)
	<-done
	<-done
	if calls != 2 {
		t.Fatalf("%d lookups for two URLs", calls)
	}
}

// connectProxy is an HTTP CONNECT proxy that sends every host to
// 127.0.0.1 (the port kept), wanting user:pass when auth is set.
func connectProxy(t *testing.T, auth string) (string, func() []string) {
	t.Helper()
	var mu sync.Mutex
	var seen []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodConnect {
			http.Error(w, "CONNECT only", http.StatusMethodNotAllowed)
			return
		}
		if auth != "" && r.Header.Get("Proxy-Authorization") != "Basic "+base64.StdEncoding.EncodeToString([]byte(auth)) {
			w.WriteHeader(http.StatusProxyAuthRequired)
			return
		}
		mu.Lock()
		seen = append(seen, r.Host)
		mu.Unlock()
		_, port, _ := net.SplitHostPort(r.Host)
		target, err := net.Dial("tcp", "127.0.0.1:"+port)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		conn, buf, _ := w.(http.Hijacker).Hijack()
		// A tunnel: either side's end or failure ends it, which the test
		// sees from the client.
		_, _ = conn.Write([]byte("HTTP/1.1 200 OK\r\n\r\n"))
		go func() { _, _ = io.Copy(target, bufio.NewReader(io.MultiReader(buf, conn))) }()
		_, _ = io.Copy(conn, target)
		_ = conn.Close()
		_ = target.Close()
	}))
	t.Cleanup(srv.Close)
	return srv.URL, func() []string { mu.Lock(); defer mu.Unlock(); return append([]string(nil), seen...) }
}

// The daemon and the phone reach the relay through a CONNECT proxy named
// by the environment, with a password.
func TestThroughAProxy(t *testing.T) {
	rel := httptest.NewServer(relay.New(relay.Defaults))
	defer rel.Close()
	_, port, _ := net.SplitHostPort(strings.TrimPrefix(rel.URL, "http://"))
	relayURL := "ws://relay.test:" + port // a name, so the environment's proxy applies

	proxyURL, seen := connectProxy(t, "me:secret")
	t.Setenv("HTTP_PROXY", strings.Replace(proxyURL, "http://", "http://me:secret@", 1))
	dl := relay.Dialer{Proxies: For}
	_, key, _ := ed25519.GenerateKey(rand.Reader)
	id := relay.ListenID(key.Public().(ed25519.PublicKey))
	l, err := dl.Listen(context.Background(), relayURL, key)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = l.Close() }()
	d, err := dl.Dial(context.Background(), relayURL, id)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = d.Close() }()
	if err := d.WriteMessage([]byte("hello")); err != nil {
		t.Fatal(err)
	}
	if m, err := l.ReadMessage(); err != nil || string(m) != "hello" {
		t.Fatalf("read %q, %v", m, err)
	}
	if s := seen(); len(s) != 2 || s[0] != "relay.test:"+port {
		t.Fatalf("the proxy saw %v", s)
	}
}

// A proxy that wants a password, given none or a wrong one, fails the dial
// saying so; the error, which shows in Remote and the log, never holds the
// password given.
func TestProxyWantsAPassword(t *testing.T) {
	proxyURL, _ := connectProxy(t, "me:secret")
	for _, user := range []*url.Userinfo{nil, url.UserPassword("me", "wrong")} {
		u, _ := url.Parse(proxyURL)
		u.User = user
		dl := relay.Dialer{Proxies: func(*url.URL) ([]*url.URL, error) { return []*url.URL{u}, nil }}
		_, err := dl.Dial(context.Background(), "ws://relay.test:1", "AAAAAAAAAAAAAAAAAAAAAA")
		if err == nil || !strings.Contains(err.Error(), "Proxy Authentication Required") {
			t.Fatalf("as %v: got %v", user, err)
		}
		if strings.Contains(err.Error(), "wrong") {
			t.Errorf("the error holds the password: %v", err)
		}
	}
}

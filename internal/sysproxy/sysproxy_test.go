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
	// An earlier run's answers (-count) would be taken without a lookup.
	cache.Lock()
	cache.m = map[string]*cached{}
	cache.Unlock()
	release, entered := make(chan struct{}), make(chan struct{}, 2)
	calls := 0
	var mu sync.Mutex
	old := lookup
	lookup = func(u *url.URL, _ bool) ([]*url.URL, time.Duration) {
		mu.Lock()
		calls++
		mu.Unlock()
		if u.Host == "slow.example" {
			entered <- struct{}{}
			<-release
		}
		return []*url.URL{nil}, time.Minute
	}
	t.Cleanup(func() { lookup = old })
	slow, _ := url.Parse("wss://slow.example/v1/listen/a")
	fast, _ := url.Parse("wss://fast.example/v1/listen/b")
	done := make(chan struct{}, 2)
	go func() { _, _ = For(slow); done <- struct{}{} }() // what matters is that fast doesn't wait for it
	go func() { _, _ = For(slow); done <- struct{}{} }()
	<-entered // the slow lookup holds its URL
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

// fakeEnviron makes env the environment proxies are read from, for the
// test, as main makes it the login shell's.
func fakeEnviron(t *testing.T, env ...string) {
	t.Helper()
	old := Environ
	Environ = func() []string { return env }
	t.Cleanup(func() { Environ = old })
}

// Proxies come from Environ (the login shell's, in the daemon), not from
// what started the daemon: a proxy only the daemon's own environment
// names isn't used, and one only Environ names is.
func TestProxiesComeFromEnviron(t *testing.T) {
	t.Setenv("HTTPS_PROXY", "http://daemons.corp:1")
	t.Setenv("HTTP_PROXY", "http://daemons.corp:1")
	cache.Lock()
	cache.m = map[string]*cached{}
	cache.Unlock()
	old := lookup
	lookup = func(*url.URL, bool) ([]*url.URL, time.Duration) { return []*url.URL{nil}, time.Minute }
	t.Cleanup(func() { lookup = old })
	proxyOf := func(raw string) string {
		t.Helper()
		u, _ := url.Parse(raw)
		ps, err := For(u)
		if err != nil || len(ps) != 1 {
			t.Fatalf("%s: %v %v", raw, ps, err)
		}
		if ps[0] == nil {
			return ""
		}
		return ps[0].String()
	}

	fakeEnviron(t, "PATH=/bin")
	if got := proxyOf("wss://relay.example.com/"); got != "" {
		t.Errorf("the daemon's own HTTPS_PROXY was used: %s", got)
	}
	fakeEnviron(t, "https_proxy=http://shells.corp:3128", "no_proxy=jira.internal.corp")
	for raw, want := range map[string]string{
		"wss://relay.example.com/":    "http://shells.corp:3128",
		"https://api.github.com/":     "http://shells.corp:3128",
		"https://jira.internal.corp/": "",
		"ws://relay.example.com/":     "", // no http_proxy of its own (nor ALL_PROXY)
	} {
		if got := proxyOf(raw); got != want {
			t.Errorf("%s: %q, want %q", raw, got, want)
		}
	}
	// A name's capital one goes first, as httpproxy reads the process's.
	fakeEnviron(t, "https_proxy=http://lower.corp:1", "HTTPS_PROXY=http://upper.corp:2")
	if got := proxyOf("https://api.github.com/"); got != "http://upper.corp:2" {
		t.Errorf("HTTPS_PROXY over https_proxy: %s", got)
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

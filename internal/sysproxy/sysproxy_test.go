package sysproxy

import (
	"bufio"
	"context"
	"encoding/base64"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"

	"github.com/afrase/nushi/relay"
)

const sample = `<dictionary> {
  ExceptionsList : <array> {
    0 : *.local
    1 : 169.254/16
    2 : intranet.corp
  }
  ExcludeSimpleHostnames : 1
  HTTPEnable : 1
  HTTPPort : 3128
  HTTPProxy : web.corp
  HTTPSEnable : 1
  HTTPSPort : 8443
  HTTPSProxy : secure.corp
  ProxyAutoConfigEnable : 0
  SOCKSEnable : 0
}
`

func TestSettings(t *testing.T) {
	s := parse([]byte(sample))
	cases := map[string]string{
		"wss://relay.example.com/v1": "http://secure.corp:8443",
		"ws://relay.example.com/v1":  "http://web.corp:3128",
		"wss://printer.local/":       "",
		"wss://169.254.3.4/":         "",
		"wss://intranet.corp/":       "",
		"wss://relay/":               "", // a simple name
	}
	for raw, want := range cases {
		u, _ := url.Parse(raw)
		got := fromSettings(s, u, u.Scheme == "wss")
		if len(got) != 1 || (got[0] == nil) != (want == "") || got[0] != nil && got[0].String() != want {
			t.Errorf("%s: %v, want %q", raw, got, want)
		}
	}
	socks := parse([]byte("<dictionary> {\n  SOCKSEnable : 1\n  SOCKSPort : 1080\n  SOCKSProxy : socks.corp\n}\n"))
	u, _ := url.Parse("wss://relay.example.com/")
	if got := fromSettings(socks, u, true); got[0] == nil || got[0].String() != "socks5://socks.corp:1080" {
		t.Errorf("SOCKS: %v", got)
	}
}

// A PAC file is evaluated by macOS itself.
func TestPAC(t *testing.T) {
	file := filepath.Join(t.TempDir(), "proxy.pac")
	os.WriteFile(file, []byte(`function FindProxyForURL(url, host) {
  if (dnsDomainIs(host, ".example.com") && url.indexOf("https:") == 0) return "PROXY p.corp:8080; SOCKS s.corp:1080; DIRECT";
  return "DIRECT";
}`), 0o600)
	s := settings{values: map[string]string{"ProxyAutoConfigEnable": "1", "ProxyAutoConfigURLString": "file://" + file}}
	u, _ := url.Parse("wss://relay.example.com/v1/listen/x")
	got := fromSettings(s, u, true)
	if len(got) != 3 || got[0].String() != "http://p.corp:8080" || got[1].String() != "socks5://s.corp:1080" || got[2] != nil {
		t.Fatalf("PAC: %v", got)
	}
	u, _ = url.Parse("wss://relay.other.org/")
	if got := fromSettings(s, u, true); len(got) != 1 || got[0] != nil {
		t.Fatalf("PAC, direct: %v", got)
	}
	s.values["ProxyAutoConfigURLString"] = "file:///nowhere.pac"
	if got := fromSettings(s, u, true); len(got) != 1 || got[0] != nil {
		t.Fatalf("a missing PAC file: %v", got)
	}
}

// connectProxy is an HTTP CONNECT proxy that sends every host to
// 127.0.0.1 (the port kept), wanting user:pass when auth is set.
func connectProxy(t *testing.T, auth string) (string, func() []string) {
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
		conn.Write([]byte("HTTP/1.1 200 OK\r\n\r\n"))
		go func() { io.Copy(target, bufio.NewReader(io.MultiReader(buf, conn))) }()
		io.Copy(conn, target)
		conn.Close()
		target.Close()
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
	id := "AAAAAAAAAAAAAAAAAAAAAA"
	l, err := dl.Listen(context.Background(), relayURL, id)
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	d, err := dl.Dial(context.Background(), relayURL, id)
	if err != nil {
		t.Fatal(err)
	}
	defer d.Close()
	d.WriteMessage([]byte("hello"))
	if m, err := l.ReadMessage(); err != nil || string(m) != "hello" {
		t.Fatalf("read %q, %v", m, err)
	}
	if s := seen(); len(s) != 2 || s[0] != "relay.test:"+port {
		t.Fatalf("the proxy saw %v", s)
	}
}

func TestProxyWantsAPassword(t *testing.T) {
	proxyURL, _ := connectProxy(t, "me:secret")
	u, _ := url.Parse(proxyURL)
	dl := relay.Dialer{Proxies: func(*url.URL) ([]*url.URL, error) { return []*url.URL{u}, nil }}
	_, err := dl.Dial(context.Background(), "ws://relay.test:1", "AAAAAAAAAAAAAAAAAAAAAA")
	if err == nil || !strings.Contains(err.Error(), "Proxy Authentication Required") {
		t.Fatalf("got %v", err)
	}
}

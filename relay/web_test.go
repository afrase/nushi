package relay

import (
	"bytes"
	"compress/gzip"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gorilla/websocket"
)

// webDir is a built app's folder: a page, its loader, a hashed script, an
// asset, and a link out of the folder that must not be served.
func webDir(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	for name, body := range map[string]string{
		"index.html":                  "<!doctype html><script src=flutter_bootstrap.js></script>",
		"flutter_bootstrap.js":        "load()",
		"sw.js":                       "self.onpush = () => {}",
		"main.0123456789abcdef.js":    strings.Repeat("var x = 1;\n", 500),
		"assets/fonts/x.ttf":          "font",
		"manifest.json":               `{"name": "Nushi"}`,
		"canvaskit/canvaskit.wasm":    "\x00asm",
		"icons/Icon-192.png":          "\x89PNG",
		"assets/AssetManifest.bin.js": "x",
	} {
		p := filepath.Join(dir, name)
		check(t, os.MkdirAll(filepath.Dir(p), 0o755))
		check(t, os.WriteFile(p, []byte(body), 0o600))
	}
	secret := filepath.Join(t.TempDir(), "secret")
	check(t, os.WriteFile(secret, []byte("secret"), 0o600))
	check(t, os.Symlink(secret, filepath.Join(dir, "secret.txt")))
	return dir
}

func webRelay(t *testing.T, origin string) *httptest.Server {
	t.Helper()
	site, err := LoadSite(webDir(t), origin)
	check(t, err)
	lim := Defaults
	lim.Site = site
	srv := httptest.NewServer(New(lim))
	t.Cleanup(srv.Close)
	return srv
}

// answer is a response read whole.
type answer struct {
	StatusCode int
	Header     http.Header
}

func get(t *testing.T, url string, h http.Header) (answer, []byte) {
	t.Helper()
	req, err := http.NewRequestWithContext(t.Context(), http.MethodGet, url, http.NoBody)
	check(t, err)
	if h != nil {
		req.Header = h
	}
	tr := &http.Transport{DisableCompression: true}
	resp, err := tr.RoundTrip(req)
	check(t, err)
	defer resp.Body.Close() //nolint:errcheck // read-only
	body, err := io.ReadAll(resp.Body)
	check(t, err)
	return answer{resp.StatusCode, resp.Header}, body
}

func TestOrigins(t *testing.T) {
	for in, want := range map[string]string{
		"https://Relay.example.com":      "https://relay.example.com",
		"https://relay.example.com:443/": "https://relay.example.com",
		"https://relay.example.com:8443": "https://relay.example.com:8443",
		"http://127.0.0.1:80":            "http://127.0.0.1",
		"http://127.0.0.1:8090":          "http://127.0.0.1:8090",
	} {
		if got, err := Origin(in); err != nil || got != want {
			t.Errorf("Origin(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	for _, bad := range []string{"", "relay.example.com", "wss://relay.example.com", "https://relay.example.com/app", "https://u@relay.example.com", "https://relay.example.com/?a", "null"} {
		if _, err := Origin(bad); err == nil {
			t.Errorf("Origin(%q) passed", bad)
		}
	}
}

// With a web app, a WebSocket may come from its own origin only: not from
// another, not from "null" (a sandboxed or file page), not from the same
// host on another port, and with no web app from none at all.
func TestWebSocketOrigin(t *testing.T) {
	const own = "https://relay.example.com"
	srv := webRelay(t, own)
	plain := httptest.NewServer(New(Defaults))
	t.Cleanup(plain.Close)
	dial := func(base, origin string) bool {
		h := http.Header{}
		if origin != "" {
			h.Set("Origin", origin)
		}
		ws, resp, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(base, "http")+"/v1/dial/"+newID(), h) //nolint:bodyclose // gorilla's Dial: a failed handshake's body needn't be closed
		if err != nil {
			if resp == nil || resp.StatusCode != http.StatusForbidden {
				t.Fatalf("dial from %q: %v", origin, err)
			}
			return false
		}
		_ = ws.Close()
		return true
	}
	for origin, want := range map[string]bool{
		"":                               true, // the daemon, a native app
		own:                              true,
		"https://evil.example.com":       false,
		"null":                           false,
		"https://relay.example.com:8443": false,
		"http://relay.example.com":       false,
		"https://relay.example.com.evil": false,
		"HTTPS://RELAY.EXAMPLE.COM":      false, // browsers send it lowercase
	} {
		if got := dial(srv.URL, origin); got != want {
			t.Errorf("origin %q: connected %v, want %v", origin, got, want)
		}
	}
	if dial(plain.URL, own) {
		t.Error("a relay without the web app took a page's WebSocket")
	}
}

func TestWebHeaders(t *testing.T) {
	srv := webRelay(t, "https://relay.example.com")
	resp, body := get(t, srv.URL+"/", nil)
	if resp.StatusCode != http.StatusOK || !strings.Contains(string(body), "flutter_bootstrap.js") {
		t.Fatalf("the page: %d %q", resp.StatusCode, body)
	}
	want := map[string]string{
		"Content-Type":           "text/html; charset=utf-8",
		"X-Content-Type-Options": "nosniff",
		"Cache-Control":          "no-cache",
		"X-Frame-Options":        "DENY",
		"Referrer-Policy":        "no-referrer",
	}
	for k, v := range want {
		if got := resp.Header.Get(k); got != v {
			t.Errorf("%s: %q, want %q", k, got, v)
		}
	}
	csp := resp.Header.Get("Content-Security-Policy")
	for _, part := range []string{"default-src 'self'", "script-src 'self' 'wasm-unsafe-eval';", "connect-src 'self' wss://relay.example.com;", "frame-ancestors 'none'", "object-src 'none'"} {
		if !strings.Contains(csp, part) {
			t.Errorf("the CSP lacks %q: %s", part, csp)
		}
	}
	if strings.Contains(csp, "unsafe-eval'") && !strings.Contains(csp, "wasm-unsafe-eval") || strings.Contains(csp, "script-src 'self' 'unsafe-inline'") {
		t.Errorf("the CSP lets scripts in: %s", csp)
	}
	for name, cache := range map[string]string{
		"sw.js":                    "no-cache",
		"flutter_bootstrap.js":     "no-cache",
		"manifest.json":            "no-cache",
		"assets/fonts/x.ttf":       "no-cache",
		"main.0123456789abcdef.js": "public, max-age=31536000, immutable",
	} {
		resp, _ := get(t, srv.URL+"/"+name, nil)
		if resp.StatusCode != http.StatusOK || resp.Header.Get("Cache-Control") != cache {
			t.Errorf("%s: %d, Cache-Control %q, want %q", name, resp.StatusCode, resp.Header.Get("Cache-Control"), cache)
		}
		if resp.Header.Get("Content-Security-Policy") == "" || resp.Header.Get("X-Content-Type-Options") != "nosniff" {
			t.Errorf("%s: without the strict headers", name)
		}
	}
	if resp, _ := get(t, srv.URL+"/sw.js", nil); resp.Header.Get("Content-Type") != "text/javascript; charset=utf-8" {
		t.Errorf("sw.js: %q", resp.Header.Get("Content-Type"))
	}
	for _, name := range []string{"secret.txt", "nothing.js", "../relay.go", "v1/dial"} {
		if resp, body := get(t, srv.URL+"/"+name, nil); resp.StatusCode == http.StatusOK || bytes.Contains(body, []byte("secret")) {
			t.Errorf("%s: %d %q", name, resp.StatusCode, body)
		}
	}
}

func TestWebCompressionAndETags(t *testing.T) {
	srv := webRelay(t, "https://relay.example.com")
	url := srv.URL + "/main.0123456789abcdef.js"
	resp, body := get(t, url, http.Header{"Accept-Encoding": {"gzip, br"}})
	if resp.Header.Get("Content-Encoding") != "gzip" {
		t.Fatal("not compressed")
	}
	z, err := gzip.NewReader(bytes.NewReader(body))
	check(t, err)
	plain, err := io.ReadAll(z)
	check(t, err)
	if string(plain) != strings.Repeat("var x = 1;\n", 500) {
		t.Fatal("compressed wrongly")
	}
	tag := resp.Header.Get("ETag")
	if resp, _ := get(t, url, http.Header{"Accept-Encoding": {"gzip"}, "If-None-Match": {tag}}); resp.StatusCode != http.StatusNotModified {
		t.Errorf("an unchanged file: %d", resp.StatusCode)
	}
	resp, body = get(t, url, http.Header{"If-None-Match": {tag}}) // the other encoding's tag
	if resp.StatusCode != http.StatusOK || resp.Header.Get("Content-Encoding") != "" || len(body) != len(plain) || resp.Header.Get("ETag") == tag {
		t.Errorf("uncompressed: %d %q %d", resp.StatusCode, resp.Header.Get("Content-Encoding"), len(body))
	}
	if resp, _ := get(t, url, http.Header{"Accept-Encoding": {"gzip;q=0"}}); resp.Header.Get("Content-Encoding") != "" {
		t.Error("compressed for a client that refused it")
	}
}

func TestLoadSiteRefuses(t *testing.T) {
	if _, err := LoadSite(t.TempDir(), "https://relay.example.com"); err == nil {
		t.Error("a folder without index.html")
	}
	if _, err := LoadSite(webDir(t), "relay.example.com"); err == nil {
		t.Error("an origin without a scheme")
	}
}

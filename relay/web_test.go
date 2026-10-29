package relay

import (
	"bytes"
	"compress/gzip"
	"crypto/rand"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"github.com/afrase/nushi/internal/testcheck"
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
		"main.0123456789abcdef.js.br": "brotli's copy",
		"orphan.js.br":                "a copy of nothing",
		"assets/fonts/x.ttf":          "font",
		"manifest.json":               `{"name": "Nushi"}`,
		"frame.html":                  "<script>addEventListener(\"message\", () => {})</script>",
		mermaidScript:                 "globalThis.mermaid = {}",
		"canvaskit/canvaskit.wasm":    "\x00asm",
		"ck-0123456789abcdef/ck.wasm": "\x00asm",
		"icons/Icon-192.png":          "\x89PNG",
		"assets/AssetManifest.bin.js": "x",
		".DS_Store":                   "secret",
		".git/config":                 "secret",
	} {
		p := filepath.Join(dir, name)
		testcheck.NoErr(t, os.MkdirAll(filepath.Dir(p), 0o755))
		testcheck.NoErr(t, os.WriteFile(p, []byte(body), 0o600))
	}
	secret := filepath.Join(t.TempDir(), "secret")
	testcheck.NoErr(t, os.WriteFile(secret, []byte("secret"), 0o600))
	testcheck.NoErr(t, os.Symlink(secret, filepath.Join(dir, "secret.txt")))
	return dir
}

func webRelay(t *testing.T, origin string) *httptest.Server {
	t.Helper()
	site, err := LoadSite(webDir(t), origin)
	testcheck.NoErr(t, err)
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
	testcheck.NoErr(t, err)
	if h != nil {
		req.Header = h
	}
	tr := &http.Transport{DisableCompression: true}
	resp, err := tr.RoundTrip(req)
	testcheck.NoErr(t, err)
	defer resp.Body.Close() //nolint:errcheck // read-only
	body, err := io.ReadAll(resp.Body)
	testcheck.NoErr(t, err)
	return answer{resp.StatusCode, resp.Header}, body
}

func TestOrigins(t *testing.T) {
	for in, want := range map[string]string{
		"https://Relay.example.com":      "https://relay.example.com",
		"https://relay.example.com:443/": "https://relay.example.com",
		"https://relay.example.com:8443": "https://relay.example.com:8443",
		"http://127.0.0.1:80":            "http://127.0.0.1",
		"http://127.0.0.1:8090":          "http://127.0.0.1:8090",
		"http://localhost:8099":          "http://localhost:8099",
		"http://[::1]:8090":              "http://[::1]:8090",
		"https://[2001:db8::1]":          "https://[2001:db8::1]",
		"https://xn--bcher-kva.example":  "https://xn--bcher-kva.example",
	} {
		if got, err := Origin(in); err != nil || got != want {
			t.Errorf("Origin(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	for _, bad := range []string{"", "relay.example.com", "wss://relay.example.com", "https://relay.example.com/app", "https://u@relay.example.com", "https://relay.example.com/?a", "null",
		"http://pi.lan:8080", "http://10.0.0.2", // plain http off this machine
		"https://relay.example.com.", "https://bücher.example"} {
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
	// Two Origins, or an empty one: refused.
	for _, h := range []http.Header{{"Origin": {own, own}}, {"Origin": {""}}} {
		ws, resp, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(srv.URL, "http")+"/v1/dial/"+newID(), h) //nolint:bodyclose // as above
		if err == nil {
			_ = ws.Close()
			t.Errorf("connected with %v", h)
		} else if resp == nil || resp.StatusCode != http.StatusForbidden {
			t.Errorf("%v: %v", h, err)
		}
	}
}

func TestWebHeaders(t *testing.T) {
	srv := webRelay(t, "https://relay.example.com")
	resp, body := get(t, srv.URL+"/", nil)
	if resp.StatusCode != http.StatusOK || !strings.Contains(string(body), "flutter_bootstrap.js") {
		t.Fatalf("the page: %d %q", resp.StatusCode, body)
	}
	want := map[string]string{
		"Content-Type":                 "text/html; charset=utf-8",
		"X-Content-Type-Options":       "nosniff",
		"Cache-Control":                "no-store",
		"X-Frame-Options":              "DENY",
		"Referrer-Policy":              "no-referrer",
		"Strict-Transport-Security":    "max-age=31536000",
		"Cross-Origin-Resource-Policy": "same-origin",
		"Permissions-Policy":           "camera=(self), microphone=(), geolocation=(), payment=(), usb=()",
	}
	for k, v := range want {
		if got := resp.Header.Get(k); got != v {
			t.Errorf("%s: %q, want %q", k, got, v)
		}
	}
	csp := resp.Header.Get("Content-Security-Policy")
	for _, part := range []string{"default-src 'none'", "script-src 'self' 'wasm-unsafe-eval';", "connect-src 'self' wss://relay.example.com;", "frame-ancestors 'none'", "object-src 'none'", "require-trusted-types-for 'script'"} {
		if !strings.Contains(csp, part) {
			t.Errorf("the CSP lacks %q: %s", part, csp)
		}
	}
	if strings.Contains(csp, "unsafe-eval'") && !strings.Contains(csp, "wasm-unsafe-eval") || strings.Contains(csp, "script-src 'self' 'unsafe-inline'") {
		t.Errorf("the CSP lets scripts in: %s", csp)
	}
	for name, cache := range map[string]string{
		"sw.js":                       "no-store",
		"flutter_bootstrap.js":        "no-store",
		"manifest.json":               "no-store",
		"assets/fonts/x.ttf":          "no-cache",
		"main.0123456789abcdef.js":    "public, max-age=31536000, immutable",
		"ck-0123456789abcdef/ck.wasm": "public, max-age=31536000, immutable",
		"canvaskit/canvaskit.wasm":    "no-cache",
	} {
		resp, _ := get(t, srv.URL+"/"+name, nil)
		if resp.StatusCode != http.StatusOK || resp.Header.Get("Cache-Control") != cache {
			t.Errorf("%s: %d, Cache-Control %q, want %q", name, resp.StatusCode, resp.Header.Get("Cache-Control"), cache)
		}
		if resp.Header.Get("Content-Security-Policy") == "" || resp.Header.Get("X-Content-Type-Options") != "nosniff" {
			t.Errorf("%s: without the strict headers", name)
		}
	}
	// The phone's frame for agents' pages: sandboxed, its own CSP, framed
	// only by the app.
	if resp, _ := get(t, srv.URL+"/frame.html", nil); resp.StatusCode != http.StatusOK ||
		!strings.HasPrefix(resp.Header.Get("Content-Security-Policy"), "sandbox allow-scripts;") ||
		!strings.Contains(resp.Header.Get("Content-Security-Policy"), "frame-ancestors 'self'") ||
		resp.Header.Get("X-Frame-Options") != "SAMEORIGIN" || resp.Header.Get("Permissions-Policy") != "camera=(), microphone=(), geolocation=(), payment=(), usb=()" {
		t.Errorf("frame.html: %d %q", resp.StatusCode, resp.Header)
	}
	if !strings.Contains(csp, "frame-src 'self'") {
		t.Errorf("the CSP: %s", csp)
	}
	// Mermaid's script, for the frame's opaque origin; the app's other
	// files stay its own.
	if resp, _ := get(t, srv.URL+"/"+mermaidScript, nil); resp.StatusCode != http.StatusOK ||
		resp.Header.Get("Cross-Origin-Resource-Policy") != "cross-origin" {
		t.Errorf("mermaid: %d %q", resp.StatusCode, resp.Header)
	}
	if resp, _ := get(t, srv.URL+"/flutter_bootstrap.js", nil); resp.Header.Get("Cross-Origin-Resource-Policy") != "same-origin" {
		t.Errorf("flutter_bootstrap.js: %q", resp.Header)
	}
	if resp, _ := get(t, srv.URL+"/sw.js", nil); resp.Header.Get("Content-Type") != "text/javascript; charset=utf-8" || resp.Header.Get("Service-Worker-Allowed") != "" {
		t.Errorf("sw.js: %q", resp.Header)
	}
	for _, name := range []string{"secret.txt", "nothing.js", "../relay.go", "v1/dial", ".DS_Store", ".git/config",
		"main.0123456789abcdef.js.br", "orphan.js.br"} {
		if resp, body := get(t, srv.URL+"/"+name, nil); resp.StatusCode == http.StatusOK || bytes.Contains(body, []byte("secret")) {
			t.Errorf("%s: %d %q", name, resp.StatusCode, body)
		}
	}
}

func TestWebCompressionAndETags(t *testing.T) {
	srv := webRelay(t, "https://relay.example.com")
	url := srv.URL + "/main.0123456789abcdef.js"
	// The build's Brotli copy, to a browser that takes it.
	resp, body := get(t, url, http.Header{"Accept-Encoding": {"gzip, deflate, br"}})
	if resp.Header.Get("Content-Encoding") != "br" || string(body) != "brotli's copy" || !strings.HasSuffix(resp.Header.Get("ETag"), `-br"`) {
		t.Fatalf("br: %q %q", resp.Header.Get("Content-Encoding"), body)
	}
	if resp, _ := get(t, url, http.Header{"Accept-Encoding": {"gzip, br;q=0"}}); resp.Header.Get("Content-Encoding") != "gzip" {
		t.Error("br for a client that refused it")
	}
	resp, body = get(t, url, http.Header{"Accept-Encoding": {"gzip"}})
	if resp.Header.Get("Content-Encoding") != "gzip" {
		t.Fatal("not compressed")
	}
	z, err := gzip.NewReader(bytes.NewReader(body))
	testcheck.NoErr(t, err)
	plain, err := io.ReadAll(z)
	testcheck.NoErr(t, err)
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

// A client that asks for a big file and never reads it loses the
// connection once its time is up.
func TestSlowReaderLetGo(t *testing.T) {
	wait, rate := writeWait, writeRate
	writeWait, writeRate = 200*time.Millisecond, 1<<30
	t.Cleanup(func() { writeWait, writeRate = wait, rate })
	dir := webDir(t)
	big := make([]byte, 32<<20)
	_, _ = rand.Read(big) // incompressible
	testcheck.NoErr(t, os.WriteFile(filepath.Join(dir, "big.0123456789abcdef.wasm"), big, 0o600))
	site, err := LoadSite(dir, "http://127.0.0.1")
	testcheck.NoErr(t, err)
	lim := Defaults
	lim.Site = site
	srv := httptest.NewServer(NewServer(lim).Handler)
	t.Cleanup(srv.Close)
	c, err := net.Dial("tcp", strings.TrimPrefix(srv.URL, "http://"))
	testcheck.NoErr(t, err)
	defer c.Close() //nolint:errcheck // a test's connection
	_, err = io.WriteString(c, "GET /big.0123456789abcdef.wasm HTTP/1.1\r\nHost: x\r\n\r\n")
	testcheck.NoErr(t, err)
	time.Sleep(time.Second) // reading nothing, past its time
	testcheck.NoErr(t, c.SetReadDeadline(time.Now().Add(10*time.Second)))
	n, err := io.Copy(io.Discard, c)
	if err != nil || n >= int64(len(big)) {
		t.Fatalf("read %d of %d: %v", n, len(big), err)
	}
}

// The engine's fallback fonts are read from the folder when asked for, not
// held in memory: as they are (woff2 is compressed), kept for good (their
// paths are versioned), and only those there when the site was loaded.
func TestFallbackFontsFromDisk(t *testing.T) {
	dir := webDir(t)
	font := "assets/fonts/fallback/notosansjp/v53/abc-_XYZ.0.woff2"
	for name, body := range map[string]string{
		font:                            "wOF2 font",
		"assets/fonts/fallback/OFL.txt": "SIL Open Font License",
		"assets/fonts/fallback/Roboto-Regular.ttf": "roboto",
	} {
		p := filepath.Join(dir, filepath.FromSlash(name))
		testcheck.NoErr(t, os.MkdirAll(filepath.Dir(p), 0o755))
		testcheck.NoErr(t, os.WriteFile(p, []byte(body), 0o600))
	}
	secret := filepath.Join(t.TempDir(), "secret")
	testcheck.NoErr(t, os.WriteFile(secret, []byte("secret"), 0o600))
	testcheck.NoErr(t, os.Symlink(secret, filepath.Join(dir, filepath.FromSlash("assets/fonts/fallback/notosansjp/v53/link.woff2"))))
	site, err := LoadSite(dir, "https://relay.example.com")
	testcheck.NoErr(t, err)
	if site.files[font] != nil || site.files["assets/fonts/fallback/OFL.txt"] != nil || site.files["assets/fonts/fallback/Roboto-Regular.ttf"] == nil {
		t.Fatal("the fallback fonts in memory, or Roboto (loaded at start) not")
	}
	lim := Defaults
	lim.Site = site
	srv := httptest.NewServer(New(lim))
	t.Cleanup(srv.Close)

	resp, body := get(t, srv.URL+"/"+font, http.Header{"Accept-Encoding": {"gzip, br"}})
	if resp.StatusCode != http.StatusOK || string(body) != "wOF2 font" || resp.Header.Get("Content-Encoding") != "" ||
		resp.Header.Get("Content-Type") != "font/woff2" || resp.Header.Get("Cache-Control") != "public, max-age=31536000, immutable" ||
		resp.Header.Get("Content-Security-Policy") == "" || resp.Header.Get("X-Content-Type-Options") != "nosniff" {
		t.Errorf("the font: %d %q %v", resp.StatusCode, body, resp.Header)
	}
	if resp, body := get(t, srv.URL+"/assets/fonts/fallback/OFL.txt", nil); resp.StatusCode != http.StatusOK || string(body) != "SIL Open Font License" ||
		resp.Header.Get("Content-Type") != "text/plain; charset=utf-8" || resp.Header.Get("Cache-Control") != "no-cache" {
		t.Errorf("the licence: %d %q %v", resp.StatusCode, body, resp.Header)
	}
	late := "assets/fonts/fallback/notosansjp/v53/late.woff2"
	testcheck.NoErr(t, os.WriteFile(filepath.Join(dir, filepath.FromSlash(late)), []byte("late"), 0o600))
	for _, name := range []string{late, "assets/fonts/fallback/notosansjp/v53/link.woff2", "assets/fonts/fallback/notosansjp/v53/../../../../../index.html"} {
		if resp, body := get(t, srv.URL+"/"+name, nil); resp.StatusCode == http.StatusOK && !bytes.Contains(body, []byte("doctype")) || bytes.Contains(body, []byte("secret")) {
			t.Errorf("%s: %d %q", name, resp.StatusCode, body)
		}
	}
	// Gone from the folder since: not found, as any other missing file.
	testcheck.NoErr(t, os.Remove(filepath.Join(dir, filepath.FromSlash(font))))
	if resp, _ := get(t, srv.URL+"/"+font, nil); resp.StatusCode != http.StatusNotFound {
		t.Errorf("a removed font: %d", resp.StatusCode)
	}
}

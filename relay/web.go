package relay

import (
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"mime"
	"net/http"
	"net/url"
	"os"
	"path"
	"regexp"
	"strconv"
	"strings"
)

// maxWeb caps what the relay holds in memory of the app.
const maxWeb = 64 << 20

// Origin checks an origin given as a flag and gives it as a browser sends
// it: lowercase, without a default port or anything after the host.
func Origin(s string) (string, error) {
	u, err := url.Parse(s)
	if err != nil || u.Scheme != "https" && u.Scheme != "http" || u.Host == "" || u.User != nil ||
		strings.Trim(u.Path, "/") != "" || u.RawQuery != "" || u.Fragment != "" {
		return "", fmt.Errorf("the origin must be scheme://host[:port], not %q", s)
	}
	host := strings.ToLower(u.Hostname())
	if p := u.Port(); p != "" && p != map[string]string{"https": "443", "http": "80"}[u.Scheme] {
		host += ":" + p
	}
	return u.Scheme + "://" + host, nil
}

// file is one of the app's files, ready to serve.
type file struct {
	body, gz []byte // gz is nil when compressing doesn't pay
	ctype    string
	etag     string // of body; gz's has "-gz" before the closing quote
	cache    string
}

// Site is the web app a relay may serve beside its WebSockets (ADR 0054):
// its built files, held in memory and served with strict headers, and the
// origin a browser sees them at, the only one whose pages may open a
// WebSocket here.
type Site struct {
	files  map[string]*file
	origin string
	csp    string
}

// hashed names a file whose name carries its content's hash, which may be
// kept for good.
var hashed = regexp.MustCompile(`\.[0-9a-f]{16,}\.`)

// fresh names the files a browser must ask for again each time: the page,
// its loader, the service worker and the manifest.
var fresh = map[string]bool{"index.html": true, "flutter_bootstrap.js": true, "sw.js": true, "manifest.json": true}

// LoadSite reads the built app in dir, to be served at origin
// (scheme://host[:port]).
func LoadSite(dir, origin string) (*Site, error) {
	origin, err := Origin(origin)
	if err != nil {
		return nil, err
	}
	root, err := os.OpenRoot(dir)
	if err != nil {
		return nil, err
	}
	defer root.Close() //nolint:errcheck // read-only
	s := &Site{files: map[string]*file{}, origin: origin, csp: csp(origin)}
	total := 0
	err = fs.WalkDir(root.FS(), ".", func(name string, d fs.DirEntry, err error) error {
		if err != nil || !d.Type().IsRegular() { // links and special files are left out
			return err
		}
		body, err := fs.ReadFile(root.FS(), name)
		if err != nil {
			return err
		}
		if total += len(body); total > maxWeb {
			return errors.New("the web app is over 64 MB")
		}
		s.files[name] = newFile(name, body)
		return nil
	})
	if err != nil {
		return nil, err
	}
	if s.files["index.html"] == nil {
		return nil, errors.New("no index.html in the web app's folder")
	}
	return s, nil
}

func newFile(name string, body []byte) *file {
	sum := sha256.Sum256(body)
	f := &file{body: body, etag: `"` + hex.EncodeToString(sum[:16]) + `"`, cache: "no-cache"}
	if f.ctype = mime.TypeByExtension(path.Ext(name)); f.ctype == "" {
		f.ctype = "application/octet-stream"
	}
	switch path.Ext(name) {
	case ".js", ".wasm", ".json", ".html", ".css", ".svg", ".otf", ".ttf", ".frag":
		var b bytes.Buffer
		z, _ := gzip.NewWriterLevel(&b, gzip.BestCompression)
		_, _ = z.Write(body)
		_ = z.Close()
		if b.Len() < len(body)*9/10 {
			f.gz = b.Bytes()
		}
	}
	if !fresh[name] && hashed.MatchString(path.Base(name)) {
		f.cache = "public, max-age=31536000, immutable"
	}
	return f
}

// csp is the pages' Content-Security-Policy: everything from the app's own
// origin, and WebSockets to it. CanvasKit needs WebAssembly, and Flutter
// sets styles on the elements it makes.
func csp(origin string) string {
	ws := "wss://" + strings.TrimPrefix(origin, "https://")
	if host, ok := strings.CutPrefix(origin, "http://"); ok {
		ws = "ws://" + host
	}
	return "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; " +
		"img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' " + ws + "; " +
		"worker-src 'self'; manifest-src 'self'; object-src 'none'; base-uri 'self'; form-action 'none'; frame-ancestors 'none'"
}

func (s *Site) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h := w.Header()
	h.Set("Content-Security-Policy", s.csp)
	h.Set("X-Content-Type-Options", "nosniff")
	h.Set("Referrer-Policy", "no-referrer")
	h.Set("X-Frame-Options", "DENY")
	h.Set("Cross-Origin-Opener-Policy", "same-origin")
	h.Set("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=(), usb=()")
	name := strings.TrimPrefix(r.URL.Path, "/")
	if name == "" {
		name = "index.html"
	}
	f := s.files[name]
	if f == nil {
		http.NotFound(w, r)
		return
	}
	h.Set("Content-Type", f.ctype)
	h.Set("Cache-Control", f.cache)
	h.Set("Vary", "Accept-Encoding")
	if name == "sw.js" {
		h.Set("Service-Worker-Allowed", "/")
	}
	body, etag := f.body, f.etag
	if f.gz != nil && acceptsGzip(r) {
		h.Set("Content-Encoding", "gzip")
		body, etag = f.gz, strings.TrimSuffix(f.etag, `"`)+`-gz"`
	}
	h.Set("ETag", etag)
	if r.Header.Get("If-None-Match") == etag {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	h.Set("Content-Length", strconv.Itoa(len(body)))
	if r.Method == http.MethodHead {
		return
	}
	_, _ = w.Write(body) //nolint:gosec // the app's own files, typed by their names, with nosniff and the CSP
}

func acceptsGzip(r *http.Request) bool {
	for v := range strings.SplitSeq(r.Header.Get("Accept-Encoding"), ",") {
		if enc, q, _ := strings.Cut(strings.TrimSpace(v), ";"); strings.EqualFold(enc, "gzip") && strings.ReplaceAll(q, " ", "") != "q=0" {
			return true
		}
	}
	return false
}

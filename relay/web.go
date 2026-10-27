package relay

import (
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"mime"
	"net"
	"net/http"
	"net/url"
	"os"
	"path"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// maxWeb caps what the relay holds in memory of the app.
const maxWeb = 64 << 20

// A file's answer may take writeWait, and a second more per writeRate
// bytes of it.
var (
	writeWait = 15 * time.Second
	writeRate = 16 << 10 // a phone on a slow link still gets the 1.4 MB script (Funnel gave about 60 KB/s)
)

// Origin checks an origin given as a flag and gives it as a browser sends
// it: lowercase, without a default port or anything after the host. A
// host is ASCII (an international name as punycode) with no trailing dot;
// http only for this machine (over plain http anyone on the way could
// change the app, and so take its key).
func Origin(s string) (string, error) {
	u, err := url.Parse(s)
	if err != nil || u.Scheme != "https" && u.Scheme != "http" || u.Host == "" || u.User != nil ||
		strings.Trim(u.Path, "/") != "" || u.RawQuery != "" || u.Fragment != "" {
		return "", fmt.Errorf("the origin must be scheme://host[:port], not %q", s)
	}
	host := strings.ToLower(u.Hostname())
	for _, r := range host {
		if r > 0x7f {
			return "", fmt.Errorf("the origin's host must be ASCII (punycode), not %q", host)
		}
	}
	if strings.HasSuffix(host, ".") {
		return "", fmt.Errorf("the origin's host has a trailing dot: %q", host)
	}
	if ip := net.ParseIP(host); u.Scheme == "http" && host != "localhost" && (ip == nil || !ip.IsLoopback()) {
		return "", errors.New("the origin must be https, except on this machine (localhost)")
	}
	if p := u.Port(); p != "" && p != map[string]string{"https": "443", "http": "80"}[u.Scheme] {
		return u.Scheme + "://" + net.JoinHostPort(host, p), nil
	}
	if strings.Contains(host, ":") {
		host = "[" + host + "]"
	}
	return u.Scheme + "://" + host, nil
}

// file is one of the app's files, ready to serve.
type file struct {
	body, gz []byte // gz is nil when compressing doesn't pay
	br       []byte // the build's Brotli copy (name.br), if it made one
	ctype    string
	etag     string // of body; gz's has "-gz" before the closing quote, br's "-br"
	cache    string
}

// Site is the web app a relay may serve beside its WebSockets (ADR 0054):
// its built files, held in memory and served with strict headers, and the
// origin a browser sees them at, the only one whose pages may open a
// WebSocket here. The engine's fallback fonts (about 21 MB, of which a
// phone fetches a few) are read from the folder when asked for.
type Site struct {
	files  map[string]*file
	fonts  map[string]bool // the fallback fonts' names, in root
	root   *os.Root
	origin string
	csp    string
}

// fallbackDir is where the engine asks for its fallback fonts (Noto for
// CJK, emoji and other scripts; flutter_bootstrap.js's
// fontFallbackBaseUrl), in folders by family and version
// (notosansjp/v53/…woff2): their paths are versioned.
const fallbackDir = "assets/fonts/fallback/"

// onDisk says whether name is one of the fallback fonts or their licence,
// served from the folder (tools/webbuild has the same rule).
func onDisk(name string) bool {
	rest, ok := strings.CutPrefix(name, fallbackDir)
	return ok && (strings.Contains(rest, "/") || rest == "OFL.txt")
}

// types are the types of files whose type the system's table may not know.
var types = map[string]string{".woff2": "font/woff2", ".ttf": "font/ttf", ".otf": "font/otf", ".txt": "text/plain; charset=utf-8"}

// hashed names a file whose name, or folder's, carries its content's hash
// (main.<hash>.dart.js, canvaskit-<hash>/): it may be kept for good.
var hashed = regexp.MustCompile(`[.-][0-9a-f]{16,}[./]`)

// fresh names the files a browser must ask for again each time: the page,
// the service worker and the manifest (the loader's name has its hash).
// They're no-store: a CDN in front (Cloudflare's Browser Cache TTL) turns
// no-cache on a script into hours of caching, but leaves no-store alone.
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
	s := &Site{files: map[string]*file{}, fonts: map[string]bool{}, root: root, origin: origin, csp: csp(origin)}
	total := 0
	err = fs.WalkDir(root.FS(), ".", func(name string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if strings.HasPrefix(d.Name(), ".") && name != "." { // .DS_Store and the like
			if d.IsDir() {
				return fs.SkipDir
			}
			return nil
		}
		if !d.Type().IsRegular() { // links and special files are left out
			return nil
		}
		if onDisk(name) {
			s.fonts[name] = true
			return nil
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
	if err == nil && s.files["index.html"] == nil {
		err = errors.New("no index.html in the web app's folder")
	}
	if err != nil {
		_ = root.Close()
		return nil, err
	}
	if len(s.fonts) == 0 { // the folder is needed only for them
		_ = root.Close()
	}
	// name.br is name's Brotli copy, served in its place, never by itself.
	for name, f := range s.files {
		if base, ok := strings.CutSuffix(name, ".br"); ok {
			if b := s.files[base]; b != nil {
				b.br = f.body
			}
			delete(s.files, name)
		}
	}
	return s, nil
}

func newFile(name string, body []byte) *file {
	sum := sha256.Sum256(body)
	f := &file{body: body, etag: `"` + hex.EncodeToString(sum[:16]) + `"`, cache: "no-cache", ctype: typeOf(name)}
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
	if fresh[name] {
		f.cache = "no-store"
	} else if hashed.MatchString(name) {
		f.cache = "public, max-age=31536000, immutable"
	}
	return f
}

func typeOf(name string) string {
	ext := path.Ext(name)
	if t := types[ext]; t != "" {
		return t
	}
	if t := mime.TypeByExtension(ext); t != "" {
		return t
	}
	return "application/octet-stream"
}

// csp is the pages' Content-Security-Policy: everything from the app's own
// origin, and WebSockets to it. CanvasKit needs WebAssembly, and Flutter
// sets styles on the elements it makes.
func csp(origin string) string {
	ws := "wss://" + strings.TrimPrefix(origin, "https://")
	if host, ok := strings.CutPrefix(origin, "http://"); ok {
		ws = "ws://" + host
	}
	return "default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; " +
		"img-src 'self' blob:; font-src 'self'; connect-src 'self' " + ws + "; " +
		"worker-src 'self'; manifest-src 'self'; object-src 'none'; base-uri 'self'; form-action 'none'; frame-ancestors 'none'; " +
		"require-trusted-types-for 'script'; trusted-types flutter-js flutter-engine nushi"
}

func (s *Site) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h := w.Header()
	h.Set("Content-Security-Policy", s.csp)
	h.Set("X-Content-Type-Options", "nosniff")
	h.Set("Referrer-Policy", "no-referrer")
	h.Set("X-Frame-Options", "DENY")
	h.Set("Cross-Origin-Opener-Policy", "same-origin")
	h.Set("Permissions-Policy", "camera=(self), microphone=(), geolocation=(), payment=(), usb=()") // the camera for Scan only
	h.Set("Cross-Origin-Resource-Policy", "same-origin")
	if strings.HasPrefix(s.origin, "https://") {
		h.Set("Strict-Transport-Security", "max-age=31536000")
	}
	name := strings.TrimPrefix(r.URL.Path, "/")
	if name == "" {
		name = "index.html"
	}
	if s.fonts[name] {
		s.serveFont(w, r, name)
		return
	}
	f := s.files[name]
	if f == nil {
		http.NotFound(w, r)
		return
	}
	h.Set("Content-Type", f.ctype)
	h.Set("Cache-Control", f.cache)
	h.Set("Vary", "Accept-Encoding")
	body, etag := f.body, f.etag
	if f.br != nil && accepts(r, "br") {
		h.Set("Content-Encoding", "br")
		body, etag = f.br, strings.TrimSuffix(f.etag, `"`)+`-br"`
	} else if f.gz != nil && accepts(r, "gzip") {
		h.Set("Content-Encoding", "gzip")
		body, etag = f.gz, strings.TrimSuffix(f.etag, `"`)+`-gz"`
	}
	h.Set("ETag", etag)
	if r.Header.Get("If-None-Match") == etag {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	// A client reading slowly can't hold the connection (and a place among
	// the plain connections) for long.
	_ = http.NewResponseController(w).SetWriteDeadline(time.Now().Add(writeWait + time.Duration(len(body)/writeRate)*time.Second))
	h.Set("Content-Length", strconv.Itoa(len(body)))
	if r.Method == http.MethodHead {
		return
	}
	_, _ = w.Write(body) //nolint:gosec // the app's own files, typed by their names, with nosniff and the CSP
}

// serveFont serves a fallback font (or their licence) from the folder:
// woff2 is compressed already, and its path is versioned.
func (s *Site) serveFont(w http.ResponseWriter, r *http.Request, name string) {
	f, err := s.root.Open(name)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer f.Close() //nolint:errcheck // read-only
	info, err := f.Stat()
	if err != nil || !info.Mode().IsRegular() {
		http.NotFound(w, r)
		return
	}
	h := w.Header()
	h.Set("Content-Type", typeOf(name))
	cache := "public, max-age=31536000, immutable"
	if path.Ext(name) != ".woff2" {
		cache = "no-cache"
	}
	h.Set("Cache-Control", cache)
	_ = http.NewResponseController(w).SetWriteDeadline(time.Now().Add(writeWait + time.Duration(info.Size()/int64(writeRate))*time.Second))
	h.Set("Content-Length", strconv.FormatInt(info.Size(), 10))
	if r.Method == http.MethodHead {
		return
	}
	_, _ = io.Copy(w, f)
}

// accepts says whether r takes the encoding enc ("gzip", "br").
func accepts(r *http.Request, enc string) bool {
	for v := range strings.SplitSeq(r.Header.Get("Accept-Encoding"), ",") {
		if e, q, _ := strings.Cut(strings.TrimSpace(v), ";"); strings.EqualFold(e, enc) && strings.ReplaceAll(q, " ", "") != "q=0" {
			return true
		}
	}
	return false
}

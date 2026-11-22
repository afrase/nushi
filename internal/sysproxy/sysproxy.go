// Package sysproxy says which proxies to use for a URL, as the system
// would, without cgo: the environment's (HTTPS_PROXY, HTTP_PROXY, NO_PROXY)
// when it names any, else the system's own. The environment is Environ:
// on Linux the login shell's, as agents get it (main gives it to
// UseShellEnviron; ADR 0048, 0101); on the Mac and Windows the daemon's
// own, so a variable only the login shell sets never beats the system's
// settings there. On the Mac the system's is the network
// settings `scutil --proxy` prints: a PAC file (evaluated by macOS's own
// CFNetwork, through osascript), else the HTTPS, HTTP or SOCKS proxy with
// the exceptions list (sysproxy_darwin.go, pac_darwin.go). On Linux it is
// the environment alone: ALL_PROXY also serves a scheme whose own
// variable is unset, as curl's all_proxy does; no gsettings or desktop
// settings (sysproxy_linux.go). Another OS goes direct
// (sysproxy_other.go, ADR 0097). A proxy URL is http, https or socks5
// (socks5h is the same to Go: names resolved at the proxy); the relay's
// websocket takes http, socks5 and socks5h, not https (relay.Dialer).
//
// Not supported: proxy auto-discovery (WPAD), proxies that want a password
// from the settings (the Keychain's), NTLM and Kerberos. A password in an
// environment URL (http://user:pass@host:port) is sent as Basic auth.
package sysproxy

import (
	"net/http"
	"net/url"
	"os"
	"sync"
	"time"

	"golang.org/x/net/http/httpproxy"

	"github.com/afrase/nushi/internal/shellenv"
)

// Environ is the environment proxies are read from, afresh for each URL:
// the daemon's own, unless UseShellEnviron replaced it (on Linux only).
var Environ = os.Environ

// Proxy is the proxy for an HTTP request (an http.Transport's Proxy): the
// first For names, nil for a direct connection.
func Proxy(r *http.Request) (*url.URL, error) {
	ps, err := For(r.URL)
	if err != nil || len(ps) == 0 {
		return nil, err
	}
	return ps[0], nil
}

// For returns the proxies to try for u (a ws://, wss://, http:// or
// https:// URL), in order;
// a nil entry is a direct connection. Only u's scheme, host and port count:
// a PAC file never sees its path (which holds the rendezvous id).
func For(u *url.URL) ([]*url.URL, error) {
	secure := u.Scheme == "wss" || u.Scheme == "https"
	if env := Environ(); envSet(env) {
		p, err := fromEnvironment(env, u, secure)
		return []*url.URL{p}, err
	}
	bare := &url.URL{Scheme: u.Scheme, Host: u.Host, Path: "/"}
	key := bare.String()
	// One lookup per URL at a time; others wait for it, not for each other.
	cache.Lock()
	c := cache.m[key]
	if c == nil || c.done() && time.Since(c.at) > c.keep {
		c = &cached{ready: make(chan struct{})}
		cache.m[key] = c
		cache.Unlock()
		c.proxies, c.keep = lookup(bare, secure)
		c.at = time.Now()
		close(c.ready)
	} else {
		cache.Unlock()
		<-c.ready
	}
	return c.proxies, nil
}

// lookup reads the settings for u, and how long the answer holds: a PAC
// file that couldn't be read or run is tried again sooner.
var lookup = systemLookup

// done says the lookup has finished. Called with cache's lock.
func (c *cached) done() bool {
	select {
	case <-c.ready:
		return true
	default:
		return false
	}
}

var cache = struct {
	sync.Mutex
	m map[string]*cached
}{m: map[string]*cached{}}

type cached struct {
	ready   chan struct{} // closed once proxies is set
	proxies []*url.URL
	at      time.Time
	keep    time.Duration
}

// fromEnvironment is env's proxy for u, NO_PROXY's exceptions counted
// (net/http's rules), or nil for a direct connection. Read afresh each
// time, unlike http.ProxyFromEnvironment, which keeps its first.
func fromEnvironment(env []string, u *url.URL, secure bool) (*url.URL, error) {
	cfg := envConfig(env)
	asked := &url.URL{Scheme: map[bool]string{true: "https", false: "http"}[secure], Host: u.Host}
	return cfg.ProxyFunc()(asked)
}

// baseConfig is env's proxies as httpproxy.FromEnvironment reads the
// process's: HTTPS_PROXY, HTTP_PROXY, NO_PROXY, each name before its
// lower-case one, and HTTP_PROXY ignored under CGI (REQUEST_METHOD).
func baseConfig(env []string) *httpproxy.Config {
	return &httpproxy.Config{
		HTTPProxy:  getenv(env, "HTTP_PROXY", "http_proxy"),
		HTTPSProxy: getenv(env, "HTTPS_PROXY", "https_proxy"),
		NoProxy:    getenv(env, "NO_PROXY", "no_proxy"),
		CGI:        getenv(env, "REQUEST_METHOD") != "",
	}
}

// envSet says env names a proxy for a scheme of its own (HTTPS_PROXY,
// HTTP_PROXY): For then reads only the environment.
func envSet(env []string) bool {
	return getenv(env, "HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy") != ""
}

// getenv is the value of the first of names set non-empty in env, "" when
// none is: every proxy variable is read through it. A name is the same
// one as the OS takes it (shellenv.Get: on Windows, whatever its case).
func getenv(env []string, names ...string) string {
	for _, n := range names {
		if v := shellenv.Get(env, n); v != "" {
			return v
		}
	}
	return ""
}

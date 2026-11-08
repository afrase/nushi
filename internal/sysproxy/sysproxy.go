// Package sysproxy says which proxies to use for a URL, as the system
// would, without cgo: the environment's (HTTPS_PROXY, HTTP_PROXY, NO_PROXY)
// when it names any, else the system's own. On the Mac that is the network
// settings `scutil --proxy` prints: a PAC file (evaluated by macOS's own
// CFNetwork, through osascript), else the HTTPS, HTTP or SOCKS proxy with
// the exceptions list (sysproxy_darwin.go, pac_darwin.go). On Linux it is
// the environment alone, as the login shell gives it: ALL_PROXY (an http,
// https or socks5 URL) unless NO_PROXY sends the host direct; no gsettings
// or desktop settings (sysproxy_linux.go). Another OS goes direct
// (sysproxy_other.go, ADR 0097).
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
)

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
	if envSet() {
		req := &http.Request{URL: &url.URL{Scheme: map[bool]string{true: "https", false: "http"}[secure], Host: u.Host}}
		p, err := http.ProxyFromEnvironment(req)
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

func envSet() bool {
	for _, v := range []string{"HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy"} {
		if os.Getenv(v) != "" {
			return true
		}
	}
	return false
}

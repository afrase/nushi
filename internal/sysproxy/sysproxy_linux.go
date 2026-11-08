package sysproxy

import (
	"cmp"
	"log/slog"
	"net/url"
	"os"
	"time"

	"golang.org/x/net/http/httpproxy"
)

// systemLookup is the environment's ALL_PROXY (or all_proxy: an http,
// https or socks5 URL; a bare host:port is http) unless NO_PROXY (or
// no_proxy) sends u's host direct, Go's way (net/http's own NO_PROXY
// rules). HTTPS_PROXY and HTTP_PROXY are For's. Linux has no system
// setting the daemon reads: gsettings and the desktops' are left out.
func systemLookup(u *url.URL, secure bool) ([]*url.URL, time.Duration) {
	all := cmp.Or(os.Getenv("ALL_PROXY"), os.Getenv("all_proxy"))
	if all == "" {
		return []*url.URL{nil}, 5 * time.Minute
	}
	cfg := httpproxy.Config{HTTPProxy: all, HTTPSProxy: all, NoProxy: cmp.Or(os.Getenv("NO_PROXY"), os.Getenv("no_proxy"))}
	asked := &url.URL{Scheme: map[bool]string{true: "https", false: "http"}[secure], Host: u.Host}
	p, err := cfg.ProxyFunc()(asked)
	if err != nil {
		slog.Warn("ALL_PROXY isn't a proxy URL; going direct", "err", err)
		return []*url.URL{nil}, 5 * time.Minute
	}
	return []*url.URL{p}, 5 * time.Minute
}

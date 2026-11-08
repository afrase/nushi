package sysproxy

import (
	"cmp"
	"log/slog"
	"net/url"
	"os"
	"time"

	"golang.org/x/net/http/httpproxy"
)

// envConfig is the environment's proxies with ALL_PROXY (or all_proxy)
// filling in for HTTPS_PROXY or HTTP_PROXY when that one is unset, as
// curl's all_proxy does.
func envConfig() *httpproxy.Config {
	cfg := httpproxy.FromEnvironment()
	all := cmp.Or(os.Getenv("ALL_PROXY"), os.Getenv("all_proxy"))
	cfg.HTTPSProxy = cmp.Or(cfg.HTTPSProxy, all)
	cfg.HTTPProxy = cmp.Or(cfg.HTTPProxy, all)
	return cfg
}

// systemLookup is For's lookup when neither HTTPS_PROXY nor HTTP_PROXY is
// set: ALL_PROXY (a bare host:port is http) unless NO_PROXY (or no_proxy)
// sends u's host direct, Go's way (net/http's own NO_PROXY rules). Linux
// has no system setting the daemon reads: gsettings and the desktops' are
// left out.
func systemLookup(u *url.URL, secure bool) ([]*url.URL, time.Duration) {
	p, err := fromEnvironment(u, secure)
	if err != nil {
		slog.Warn("ALL_PROXY isn't a proxy URL; going direct", "err", err)
		return []*url.URL{nil}, 5 * time.Minute
	}
	return []*url.URL{p}, 5 * time.Minute
}

//go:build !darwin && !linux

package sysproxy

import (
	"net/url"
	"time"

	"golang.org/x/net/http/httpproxy"
)

// envConfig is env's proxies: HTTPS_PROXY, HTTP_PROXY, NO_PROXY.
func envConfig(env []string) *httpproxy.Config { return baseConfig(env) }

// systemLookup reads no settings on this OS: a direct connection.
func systemLookup(*url.URL, bool) ([]*url.URL, time.Duration) {
	return []*url.URL{nil}, 5 * time.Minute
}

package sysproxy

import (
	"net/url"
	"testing"
)

// On Linux, ALL_PROXY names the proxy for what HTTPS_PROXY and HTTP_PROXY
// don't, unless NO_PROXY sends the host direct.
func TestAllProxy(t *testing.T) {
	for _, v := range []string{"ALL_PROXY", "all_proxy", "NO_PROXY", "no_proxy"} {
		t.Setenv(v, "")
	}
	lookupOf := func(raw string) string {
		t.Helper()
		u, _ := url.Parse(raw)
		got, keep := systemLookup(u, u.Scheme == "wss" || u.Scheme == "https")
		if len(got) != 1 || keep <= 0 {
			t.Fatalf("%s: %v %v", raw, got, keep)
		}
		if got[0] == nil {
			return ""
		}
		return got[0].String()
	}
	if got := lookupOf("wss://relay.example.com/"); got != "" {
		t.Errorf("no ALL_PROXY: %s", got)
	}
	t.Setenv("all_proxy", "socks5://socks.corp:1080")
	if got := lookupOf("wss://relay.example.com/"); got != "socks5://socks.corp:1080" {
		t.Errorf("all_proxy: %s", got)
	}
	t.Setenv("ALL_PROXY", "proxy.corp:3128") // a bare host:port is http; the capital one first
	t.Setenv("no_proxy", ".internal.corp,10.0.0.0/8,printer")
	for raw, want := range map[string]string{
		"wss://relay.example.com/":     "http://proxy.corp:3128",
		"ws://relay.example.com:8080/": "http://proxy.corp:3128",
		"https://api.github.com/":      "http://proxy.corp:3128",
		"wss://jira.internal.corp/":    "",
		"https://10.1.2.3/":            "",
		"wss://printer/":               "",
		"ws://localhost:9/":            "", // never proxied
	} {
		if got := lookupOf(raw); got != want {
			t.Errorf("%s: %q, want %q", raw, got, want)
		}
	}
	t.Setenv("ALL_PROXY", "%zz")
	if got := lookupOf("wss://relay.example.com/"); got != "" {
		t.Errorf("a bad ALL_PROXY: %s", got)
	}
}

package sysproxy

import (
	"net/url"
	"testing"
)

// clearProxyEnv unsets every proxy variable for the test.
func clearProxyEnv(t *testing.T) {
	t.Helper()
	for _, v := range []string{"ALL_PROXY", "all_proxy", "NO_PROXY", "no_proxy", "HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy"} {
		t.Setenv(v, "")
	}
}

// On Linux, with neither HTTPS_PROXY nor HTTP_PROXY set, ALL_PROXY names
// the proxy unless NO_PROXY sends the host direct.
func TestAllProxy(t *testing.T) {
	clearProxyEnv(t)
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
	t.Setenv("ALL_PROXY", "socks5h://localhost:1080") // curl's and ssh -D's
	if got := lookupOf("wss://relay.example.com/"); got != "socks5h://localhost:1080" {
		t.Errorf("socks5h: %s", got)
	}
	t.Setenv("ALL_PROXY", "%zz")
	if got := lookupOf("wss://relay.example.com/"); got != "" {
		t.Errorf("a bad ALL_PROXY: %s", got)
	}
}

// ALL_PROXY serves the scheme whose own variable is unset, as curl's
// all_proxy does, with NO_PROXY still counted.
func TestAllProxyFillsIn(t *testing.T) {
	clearProxyEnv(t)
	t.Setenv("HTTPS_PROXY", "http://p.corp:3128")
	t.Setenv("ALL_PROXY", "socks5://s.corp:1080")
	t.Setenv("NO_PROXY", "jira.internal.corp")
	for raw, want := range map[string]string{
		"wss://relay.example.com/":   "http://p.corp:3128",
		"https://api.github.com/":    "http://p.corp:3128",
		"ws://relay.example.com/":    "socks5://s.corp:1080",
		"http://jira.example.com/":   "socks5://s.corp:1080",
		"http://jira.internal.corp/": "",
	} {
		u, _ := url.Parse(raw)
		ps, err := For(u)
		if err != nil || len(ps) != 1 {
			t.Fatalf("%s: %v %v", raw, ps, err)
		}
		got := ""
		if ps[0] != nil {
			got = ps[0].String()
		}
		if got != want {
			t.Errorf("%s: %q, want %q", raw, got, want)
		}
	}
}

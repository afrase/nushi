package sysproxy

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"testing"
	"time"
)

const sample = `<dictionary> {
  ExceptionsList : <array> {
    0 : *.local
    1 : 169.254/16
    2 : intranet.corp
  }
  ExcludeSimpleHostnames : 1
  HTTPEnable : 1
  HTTPPort : 3128
  HTTPProxy : web.corp
  HTTPSEnable : 1
  HTTPSPort : 8443
  HTTPSProxy : secure.corp
  ProxyAutoConfigEnable : 0
  SOCKSEnable : 0
}
`

func TestSettings(t *testing.T) {
	s := parse([]byte(sample))
	cases := map[string]string{
		"wss://relay.example.com/v1": "http://secure.corp:8443",
		"ws://relay.example.com/v1":  "http://web.corp:3128",
		"wss://printer.local/":       "",
		"wss://169.254.3.4/":         "",
		"wss://intranet.corp/":       "",
		"wss://relay/":               "", // a simple name
	}
	for raw, want := range cases {
		u, _ := url.Parse(raw)
		got, _ := fromSettings(s, u, u.Scheme == "wss")
		if len(got) != 1 || (got[0] == nil) != (want == "") || got[0] != nil && got[0].String() != want {
			t.Errorf("%s: %v, want %q", raw, got, want)
		}
	}
	socks := parse([]byte("<dictionary> {\n  SOCKSEnable : 1\n  SOCKSPort : 1080\n  SOCKSProxy : socks.corp\n}\n"))
	u, _ := url.Parse("wss://relay.example.com/")
	if got, _ := fromSettings(socks, u, true); got[0] == nil || got[0].String() != "socks5://socks.corp:1080" {
		t.Errorf("SOCKS: %v", got)
	}
}

// A PAC file is evaluated by macOS itself, and sees only the scheme, the
// host and the port.
func TestPAC(t *testing.T) {
	file := filepath.Join(t.TempDir(), "proxy.pac")
	if err := os.WriteFile(file, []byte(`function FindProxyForURL(url, host) {
  if (url != "https://relay.example.com:8443/" && url != "https://relay.other.org/") return "PROXY leaked.corp:1";
  if (dnsDomainIs(host, ".example.com")) return "PROXY p.corp:8080; SOCKS s.corp:1080; DIRECT";
  return "DIRECT";
}`), 0o600); err != nil {
		t.Fatal(err)
	}
	s := settings{values: map[string]string{"ProxyAutoConfigEnable": "1", "ProxyAutoConfigURLString": "file://" + file}}
	u, _ := url.Parse("wss://relay.example.com:8443/v1/listen/SECRETIDSECRETID?x=1#y")
	got, ok := fromSettings(s, &url.URL{Scheme: u.Scheme, Host: u.Host, Path: "/"}, true)
	if !ok || len(got) != 3 || got[0].String() != "http://p.corp:8080" || got[1].String() != "socks5://s.corp:1080" || got[2] != nil {
		t.Fatalf("PAC: %v", got)
	}
	// An https URL (Web Push, Jira, GitHub) is asked as itself.
	u, _ = url.Parse("https://relay.example.com:8443/")
	if got, ok := fromSettings(s, u, true); !ok || len(got) != 3 || got[0].String() != "http://p.corp:8080" {
		t.Fatalf("PAC, https: %v", got)
	}
	u, _ = url.Parse("wss://relay.other.org/")
	if got, _ := fromSettings(s, u, true); len(got) != 1 || got[0] != nil {
		t.Fatalf("PAC, direct: %v", got)
	}
	// A PAC file that can't be had leaves the static settings.
	s.values["ProxyAutoConfigURLString"] = "file:///nowhere.pac"
	s.values["HTTPSEnable"], s.values["HTTPSProxy"], s.values["HTTPSPort"] = "1", "static.corp", "3128"
	if got, ok := fromSettings(s, u, true); ok || len(got) != 1 || got[0].String() != "http://static.corp:3128" {
		t.Fatalf("a missing PAC file: %v %v", got, ok)
	}
}

// A PAC server that never answers is given up on.
func TestPACTimeout(t *testing.T) {
	hang := make(chan struct{})
	srv := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { <-hang }))
	defer srv.Close()
	defer close(hang)
	old := Timeout
	Timeout = 200 * time.Millisecond
	defer func() { Timeout = old }()
	s := settings{values: map[string]string{"ProxyAutoConfigEnable": "1", "ProxyAutoConfigURLString": srv.URL + "/proxy.pac"}}
	u, _ := url.Parse("wss://relay.example.com/")
	began := time.Now()
	if got, ok := fromSettings(s, u, true); ok || got[0] != nil {
		t.Fatalf("got %v %v", got, ok)
	}
	if time.Since(began) > 2*time.Second {
		t.Fatal("waited too long")
	}
}

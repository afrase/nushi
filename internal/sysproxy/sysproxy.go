// Package sysproxy says which proxies to use for a URL, as macOS would,
// without cgo: the environment's (HTTPS_PROXY, HTTP_PROXY, NO_PROXY) when
// it names any, else the network settings `scutil --proxy` prints: a PAC
// file (evaluated by macOS's own CFNetwork, through osascript), else the
// HTTPS, HTTP or SOCKS proxy with the exceptions list.
//
// Not supported: proxy auto-discovery (WPAD), proxies that want a password
// from the settings (the Keychain's), NTLM and Kerberos. A password in an
// environment URL (http://user:pass@host:port) is sent as Basic auth.
package sysproxy

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path"
	"strings"
	"sync"
	"time"
)

// For returns the proxies to try for u (a ws:// or wss:// URL), in order;
// a nil entry is a direct connection.
func For(u *url.URL) ([]*url.URL, error) {
	secure := u.Scheme == "wss" || u.Scheme == "https"
	if envSet() {
		req := &http.Request{URL: &url.URL{Scheme: map[bool]string{true: "https", false: "http"}[secure], Host: u.Host}}
		p, err := http.ProxyFromEnvironment(req)
		return []*url.URL{p}, err
	}
	key := u.Scheme + "://" + u.Host
	cache.Lock()
	defer cache.Unlock()
	if c, ok := cache.m[key]; ok && time.Since(c.at) < 5*time.Minute {
		return c.proxies, nil
	}
	out, err := exec.Command("/usr/sbin/scutil", "--proxy").Output()
	if err != nil {
		return []*url.URL{nil}, nil
	}
	proxies := fromSettings(parse(out), u, secure)
	cache.m[key] = cached{proxies, time.Now()}
	return proxies, nil
}

var cache = struct {
	sync.Mutex
	m map[string]cached
}{m: map[string]cached{}}

type cached struct {
	proxies []*url.URL
	at      time.Time
}

func envSet() bool {
	for _, v := range []string{"HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy"} {
		if os.Getenv(v) != "" {
			return true
		}
	}
	return false
}

// settings is scutil's proxy dictionary: its values, and the exceptions.
type settings struct {
	values     map[string]string
	exceptions []string
}

// parse reads `scutil --proxy`: "Key : value" lines, and the exceptions
// list as an array of "N : value" lines.
func parse(out []byte) settings {
	s := settings{values: map[string]string{}}
	inList := false
	sc := bufio.NewScanner(bytes.NewReader(out))
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		k, v, ok := strings.Cut(line, " : ")
		switch {
		case line == "}":
			inList = false
		case !ok:
		case inList:
			s.exceptions = append(s.exceptions, v)
		case k == "ExceptionsList":
			inList = true
		default:
			s.values[k] = v
		}
	}
	return s
}

func fromSettings(s settings, u *url.URL, secure bool) []*url.URL {
	v := s.values
	if v["ProxyAutoConfigEnable"] == "1" && v["ProxyAutoConfigURLString"] != "" {
		if proxies, err := pac(v["ProxyAutoConfigURLString"], u); err == nil {
			return proxies
		}
		// As macOS does, a PAC file that can't be had means no proxy.
		return []*url.URL{nil}
	}
	host := u.Hostname()
	if s.excepted(host) {
		return []*url.URL{nil}
	}
	kind := "HTTP"
	if secure {
		kind = "HTTPS"
	}
	switch {
	case v[kind+"Enable"] == "1" && v[kind+"Proxy"] != "":
		return []*url.URL{{Scheme: "http", Host: net.JoinHostPort(v[kind+"Proxy"], v[kind+"Port"])}}
	case v["SOCKSEnable"] == "1" && v["SOCKSProxy"] != "":
		return []*url.URL{{Scheme: "socks5", Host: net.JoinHostPort(v["SOCKSProxy"], v["SOCKSPort"])}}
	}
	return []*url.URL{nil}
}

// excepted says whether the settings send host direct: a name without dots
// when simple names are excluded, or an exceptions entry (a name, a
// pattern such as *.local, or an address range such as 169.254/16).
func (s settings) excepted(host string) bool {
	if s.values["ExcludeSimpleHostnames"] == "1" && !strings.Contains(host, ".") {
		return true
	}
	host = strings.ToLower(host)
	ip := net.ParseIP(host)
	for _, e := range s.exceptions {
		e = strings.ToLower(strings.TrimSpace(e))
		if base, bits, ok := strings.Cut(e, "/"); ok && ip != nil {
			parts := strings.Split(base, ".")
			for len(parts) < 4 {
				parts = append(parts, "0")
			}
			if _, n, err := net.ParseCIDR(strings.Join(parts, ".") + "/" + bits); err == nil && n.Contains(ip) {
				return true
			}
			continue
		}
		if m, _ := path.Match(e, host); m || e == host || strings.HasPrefix(e, "*.") && host == e[2:] {
			return true
		}
	}
	return false
}

// pacScript evaluates a PAC file (on stdin) for a URL (its argument) with
// CFNetwork, and prints the proxies it names as JSON.
const pacScript = `ObjC.import('Foundation'); ObjC.import('CoreServices');
function run(argv) {
  const data = $.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile;
  const script = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding);
  const res = $.CFNetworkCopyProxiesForAutoConfigurationScript(script, $.NSURL.URLWithString(argv[0]), Ref());
  const list = ObjC.castRefToObject(res), out = [];
  for (let i = 0; i < list.count; i++) out.push(ObjC.deepUnwrap(list.objectAtIndex(i)));
  return JSON.stringify(out);
}`

// pac fetches the PAC file at pacURL (directly) and asks macOS what it says
// for u.
func pac(pacURL string, u *url.URL) ([]*url.URL, error) {
	script, err := fetch(pacURL)
	if err != nil {
		return nil, err
	}
	// CFNetwork knows http and https; a WebSocket URL is asked as either.
	asked := *u
	asked.Scheme = strings.Replace(strings.Replace(u.Scheme, "wss", "https", 1), "ws", "http", 1)
	cmd := exec.Command("/usr/bin/osascript", "-l", "JavaScript", "-e", pacScript, asked.String())
	cmd.Stdin = bytes.NewReader(script)
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("evaluating the PAC file: %w", err)
	}
	var entries []map[string]any
	if err := json.Unmarshal(out, &entries); err != nil {
		return nil, err
	}
	var proxies []*url.URL
	for _, e := range entries {
		host, _ := e["kCFProxyHostNameKey"].(string)
		port, _ := e["kCFProxyPortNumberKey"].(float64)
		addr := net.JoinHostPort(host, fmt.Sprint(int(port)))
		switch e["kCFProxyTypeKey"] {
		case "kCFProxyTypeNone":
			proxies = append(proxies, nil)
		case "kCFProxyTypeHTTP", "kCFProxyTypeHTTPS":
			proxies = append(proxies, &url.URL{Scheme: "http", Host: addr})
		case "kCFProxyTypeSOCKS":
			proxies = append(proxies, &url.URL{Scheme: "socks5", Host: addr})
		}
	}
	if len(proxies) == 0 {
		return nil, errors.New("the PAC file named no proxy Nushi can use")
	}
	return proxies, nil
}

// fetch reads a PAC file: http(s), directly, or file://; 1 MB at most.
func fetch(raw string) ([]byte, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return nil, err
	}
	var r io.ReadCloser
	if u.Scheme == "file" {
		if r, err = os.Open(u.Path); err != nil {
			return nil, err
		}
	} else {
		c := &http.Client{Timeout: 10 * time.Second, Transport: &http.Transport{Proxy: nil}}
		resp, err := c.Get(raw)
		if err != nil {
			return nil, err
		}
		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			return nil, fmt.Errorf("the PAC file: %s", resp.Status)
		}
		r = resp.Body
	}
	defer r.Close()
	return io.ReadAll(io.LimitReader(r, 1<<20))
}

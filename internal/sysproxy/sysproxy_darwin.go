package sysproxy

import (
	"bufio"
	"bytes"
	"context"
	"net"
	"net/url"
	"os/exec"
	"path"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/procgroup"
)

// Timeout bounds each outside step: scutil, fetching a PAC file,
// evaluating it.
var Timeout = 10 * time.Second

// systemLookup reads the network settings `scutil --proxy` prints.
func systemLookup(u *url.URL, secure bool) ([]*url.URL, time.Duration) {
	ctx, cancel := context.WithTimeout(context.Background(), Timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "/usr/sbin/scutil", "--proxy")
	procgroup.Bound(cmd)
	out, err := cmd.Output()
	if err != nil {
		return []*url.URL{nil}, 30 * time.Second
	}
	proxies, ok := fromSettings(parse(out), u, secure)
	if !ok {
		return proxies, 30 * time.Second
	}
	return proxies, 5 * time.Minute
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

// fromSettings says what the settings name for u; false when a PAC file
// couldn't be read or run, and the static settings stood in, as macOS
// does.
func fromSettings(s settings, u *url.URL, secure bool) ([]*url.URL, bool) {
	v := s.values
	if v["ProxyAutoConfigEnable"] == "1" && v["ProxyAutoConfigURLString"] != "" {
		if proxies, err := pac(v["ProxyAutoConfigURLString"], u); err == nil {
			return proxies, true
		}
		return s.static(u, secure), false
	}
	return s.static(u, secure), true
}

// static is the HTTPS (or HTTP) proxy, else the SOCKS one, unless the
// exceptions send u's host direct.
func (s settings) static(u *url.URL, secure bool) []*url.URL {
	v := s.values
	if s.excepted(u.Hostname()) {
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

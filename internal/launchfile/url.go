package launchfile

import (
	"errors"
	"net"
	"net/url"
	"strconv"
	"strings"

	"golang.org/x/net/idna"
)

// target is an entry's url, checked by Claude's rules: http or https, no
// user name or password, a localhost address spelt the usual way and
// only as the server's origin.
type target struct {
	href  string // the url as Nushi opens it
	host  string // its host, with the port when not the scheme's own
	local bool   // a localhost address, by Claude's list
	port  int    // its port, the scheme's own when none is written
}

// parseURL checks s as Claude does. Its host is read as a browser reads
// it (lower case, mapped to ASCII as IDNA maps it, IPv4 and IPv6
// addresses in their usual form), so a spelling of localhost, 127.0.0.1
// or ::1 meets the rules for localhost.
func parseURL(s string) (target, error) {
	invalid := errors.New(`"url" is not a valid URL`)
	u, err := url.Parse(strings.TrimFunc(s, isJSSpace))
	if err != nil {
		return target{}, invalid
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return target{}, errors.New(`"url" must be http or https`)
	}
	if u.Opaque != "" {
		return target{}, invalid
	}
	if u.User != nil {
		if pw, _ := u.User.Password(); u.User.Username() != "" || pw != "" {
			return target{}, errors.New(`"url" must not hold a user name or password`)
		}
		u.User = nil
	}
	host, ok := canonicalHost(u.Hostname())
	if !ok {
		return target{}, invalid
	}
	t := target{port: 80}
	if u.Scheme == "https" {
		t.port = 443
	}
	if p := u.Port(); p != "" {
		n, err := strconv.Atoi(p)
		if err != nil || n < 1 || n > 65535 {
			return target{}, invalid
		}
		t.port = n
	}
	t.host = host
	if strings.Contains(host, ":") {
		t.host = "[" + host + "]"
	}
	if (u.Scheme == "http" && t.port != 80) || (u.Scheme == "https" && t.port != 443) {
		t.host += ":" + strconv.Itoa(t.port)
	}
	if offLoopback(host) {
		return target{}, errors.New(`"url" is an address not written the usual way: write localhost, a *.localhost name, 127.0.0.1 or [::1]`)
	}
	t.local = isLocal(host)
	if t.local && ((u.Path != "" && u.Path != "/") || u.RawQuery != "" || u.Fragment != "") {
		return target{}, errors.New(`"url" is a localhost address with a path or query: it must be the server's origin alone`)
	}
	u.Host = t.host
	if t.local {
		u.Path, u.RawPath, u.ForceQuery = "/", "", false
	}
	t.href = u.String()
	return t, nil
}

// isLocal is Claude's list of localhost names.
func isLocal(host string) bool {
	switch host {
	case "localhost", "127.0.0.1", "0.0.0.0", "::1":
		return true
	}
	return strings.HasSuffix(host, ".localhost")
}

// offLoopback says host is an address Claude refuses as not written the
// usual way, so the localhost rules can't be dodged: a localhost name
// with dots after it, an address in 127/8 other than 127.0.0.1, any
// IPv4-mapped IPv6 address.
func offLoopback(host string) bool {
	if trimmed := strings.TrimRight(host, "."); trimmed != host && isLocal(trimmed) {
		return true
	}
	if ip := net.ParseIP(host); ip != nil && !strings.Contains(host, ":") {
		return ip[12] == 127 && host != "127.0.0.1"
	}
	return strings.HasPrefix(host, "::ffff:")
}

// toASCII is the WHATWG URL standard's domain to ASCII: UTS 46 without
// the STD3 rules, hyphen checks or DNS lengths, so a full-width
// ｌｏｃａｌｈｏｓｔ or 127。0。0。1 is localhost as a browser reads it.
var toASCII = idna.New(idna.MapForLookup(), idna.BidiRule(), idna.CheckJoiners(true),
	idna.CheckHyphens(false), idna.StrictDomainName(false), idna.Transitional(false),
	idna.VerifyDNSLength(false))

// canonicalHost is host as a browser's URL parser writes it, or false
// when it can't be one: mapped to ASCII, lower case, an IPv6 address
// compressed, an IPv4 address that ends in a number (127.1, 0x7f.0.0.1,
// 2130706433) dotted in four decimal parts.
func canonicalHost(host string) (string, bool) {
	if strings.ContainsFunc(host, func(r rune) bool { return r >= 0x80 }) {
		mapped, err := toASCII.ToASCII(host)
		if err != nil {
			return "", false
		}
		host = mapped
	}
	host = strings.ToLower(host)
	if host == "" || strings.ContainsAny(host, "%/\\?#@ ") {
		return "", false
	}
	if strings.Contains(host, ":") {
		ip := net.ParseIP(host)
		if ip == nil {
			return "", false
		}
		if ip.To4() != nil { // IPv4-mapped, which Go would print dotted
			return "::ffff:" + ip.To4().String(), true
		}
		return ip.String(), true
	}
	parts := strings.Split(host, ".")
	if len(parts) > 1 && parts[len(parts)-1] == "" {
		parts = parts[:len(parts)-1]
	}
	if !number(parts[len(parts)-1]) {
		return host, true
	}
	return ipv4(parts)
}

// number says a host's label is a number to a URL parser: decimal digits,
// or 0x and hex digits.
func number(label string) bool {
	if label == "" {
		return false
	}
	if hex, ok := strings.CutPrefix(label, "0x"); ok {
		return strings.Trim(hex, "0123456789abcdef") == ""
	}
	return strings.Trim(label, "0123456789") == ""
}

// ipv4 is the WHATWG IPv4 parser: up to four parts, each decimal, 0x hex
// or 0 octal, the last filling the bytes the others leave.
func ipv4(parts []string) (string, bool) {
	if len(parts) > 4 {
		return "", false
	}
	nums := make([]uint64, len(parts))
	for i, p := range parts {
		if p == "" { // 127..1: no number at all
			return "", false
		}
		base := 10
		switch {
		case strings.HasPrefix(p, "0x"):
			p, base = p[2:], 16
		case len(p) > 1 && p[0] == '0':
			p, base = p[1:], 8
		}
		if p == "" { // 0x alone is 0
			nums[i] = 0
			continue
		}
		n, err := strconv.ParseUint(p, base, 32)
		if err != nil {
			return "", false
		}
		nums[i] = n
	}
	last := len(nums) - 1
	for _, n := range nums[:last] {
		if n > 255 {
			return "", false
		}
	}
	if nums[last] >= 1<<(8*(5-len(nums))) {
		return "", false
	}
	v := nums[last]
	for i, n := range nums[:last] {
		v += n << (8 * (3 - i))
	}
	ip := make(net.IP, 4)
	for i := range ip {
		ip[i] = byte(v >> (8 * (3 - i)) & 0xff)
	}
	return ip.String(), true
}

// LoopbackURL is s, an agent's address of a page, as a browser loads it,
// when it is http or https to this Mac's loopback: localhost, a
// *.localhost name, 127.0.0.0/8 or [::1], on any port, with no user name
// or password and no space, control character or backslash anywhere (the
// show tool's url, ADR 0100). Its host is read as a browser reads it
// (canonicalHost), so no spelling reaches another machine while passing
// here; a trailing dot or an IPv4-mapped address isn't loopback to it.
func LoopbackURL(s string) (string, bool) {
	if s == "" || len(s) > 4096 || strings.ContainsFunc(s, func(r rune) bool { return r <= ' ' || r == 0x7f || r == '\\' }) {
		return "", false
	}
	u, err := url.Parse(s)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Opaque != "" || u.User != nil || u.Host == "" {
		return "", false
	}
	host, ok := canonicalHost(u.Hostname())
	if !ok || !loopback(host) {
		return "", false
	}
	if strings.Contains(host, ":") {
		host = "[" + host + "]"
	}
	if p := u.Port(); p != "" {
		n, err := strconv.Atoi(p)
		if err != nil || n < 1 || n > 65535 {
			return "", false
		}
		host += ":" + strconv.Itoa(n)
	}
	u.Host = host
	return u.String(), true
}

// loopback says a canonical host is this Mac's: localhost, a name under
// it, an address in 127.0.0.0/8, or ::1.
func loopback(host string) bool {
	if host == "localhost" || strings.HasSuffix(host, ".localhost") {
		return !strings.HasPrefix(host, ".") && !strings.Contains(host, "..")
	}
	if strings.Contains(host, ":") {
		return host == "::1"
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

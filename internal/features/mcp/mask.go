package mcp

import (
	"encoding/json"
	"fmt"
	"reflect"
	"regexp"
	"strings"
)

// Mask stands in for the secrets in a server's config, which never leave
// the daemon: env and header values, a headers helper, and what looks
// secret in its URL, command and arguments.
const Mask = "••••"

// masked is a server's config with its secrets replaced by Mask.
func masked(config string) string {
	cfg, err := decode(config)
	if err != nil {
		return "{}"
	}
	for _, key := range []string{"env", "headers"} {
		if m, ok := cfg[key].(map[string]any); ok {
			for k := range m {
				m[k] = Mask
			}
		}
	}
	if _, ok := cfg["headersHelper"].(string); ok {
		cfg["headersHelper"] = Mask
	}
	if u, ok := cfg["url"].(string); ok {
		cfg["url"] = maskURL(u)
	}
	if c, ok := cfg["command"].(string); ok && strings.Contains(c, " ") { // a whole command line
		cfg["command"] = strings.Join(maskArgs(strings.Fields(c)), " ")
	}
	if args, ok := cfg["args"].([]any); ok {
		var s []string
		for _, a := range args {
			s = append(s, fmt.Sprint(a))
		}
		cfg["args"] = maskArgs(s)
	}
	b, _ := json.Marshal(cfg)
	return string(b)
}

var (
	secretWord = regexp.MustCompile(`(?i)key|token|secret|pass|pwd|auth|cred|bearer|session|cookie|private`)
	envName    = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)
	tokenChars = regexp.MustCompile(`^[A-Za-z0-9_-]{16,}$`)
)

// maskArgs masks the arguments that look secret: the value of a flag
// named like a secret (--api-key x, --token=x), VAR=x when VAR is named
// like one or follows -e/--env (docker run -e VAR=x), and URLs' secrets.
func maskArgs(args []string) []string {
	out := append([]string(nil), args...)
	for i, a := range out {
		name, _, eq := strings.Cut(a, "=")
		flag := strings.HasPrefix(a, "-")
		switch {
		case flag && eq && secretWord.MatchString(name):
			out[i] = name + "=" + Mask
		case flag && !eq && secretWord.MatchString(a) && i+1 < len(out) && !strings.HasPrefix(out[i+1], "-"):
			out[i+1] = Mask
		case !flag && eq && envName.MatchString(name) && (secretWord.MatchString(name) || i > 0 && (args[i-1] == "-e" || args[i-1] == "--env")):
			out[i] = name + "=" + Mask
		case strings.Contains(a, "://"):
			out[i] = maskURL(a)
		}
	}
	return out
}

// maskURL masks a URL's user and password, its query's values, and the
// path segments that look like tokens.
func maskURL(u string) string {
	rest, _, hasFrag := strings.Cut(u, "#")
	rest, query, hasQuery := strings.Cut(rest, "?")
	scheme, rest, ok := strings.Cut(rest, "://")
	if !ok {
		scheme, rest = "", scheme
	}
	host, path, hasPath := strings.Cut(rest, "/")
	if at := strings.LastIndex(host, "@"); at >= 0 {
		host = Mask + host[at:]
	}
	segs := strings.Split(path, "/")
	for i, s := range segs {
		if tokenLike(s) {
			segs[i] = Mask
		}
	}
	out := host
	if ok {
		out = scheme + "://" + host
	}
	if hasPath {
		out += "/" + strings.Join(segs, "/")
	}
	if hasQuery {
		pairs := strings.Split(query, "&")
		for i, p := range pairs {
			if k, _, ok := strings.Cut(p, "="); ok {
				pairs[i] = k + "=" + Mask
			}
		}
		out += "?" + strings.Join(pairs, "&")
	}
	if hasFrag {
		out += "#" + Mask
	}
	return out
}

// tokenLike says whether a path segment looks like a token: long, of
// letters and digits (at least three), with few separators (unlike a
// slug such as my-server-2024-edition).
func tokenLike(s string) bool {
	if !tokenChars.MatchString(s) {
		return false
	}
	digits := 0
	for _, r := range s {
		if '0' <= r && r <= '9' {
			digits++
		}
	}
	seps := strings.Count(s, "-") + strings.Count(s, "_")
	return digits >= 3 && seps*8 <= len(s)
}

// unmasked is config with what is still masked as it was shown (Mask
// values, or a URL, command or arguments sent back exactly as masked)
// taken from old. A kept env or header value goes only to the same URL
// and command: when they change, a hidden value must be typed again, so
// an edit can't send a stored secret somewhere else.
func unmasked(config, old string) (string, error) {
	cfg, err := decode(config)
	if err != nil {
		return "", err
	}
	was, _ := decode(old)
	shown, _ := decode(masked(old))
	for _, key := range []string{"url", "command", "args", "headersHelper"} {
		if cfg[key] != nil && reflect.DeepEqual(cfg[key], shown[key]) {
			cfg[key] = was[key]
		}
	}
	for _, key := range []string{"url", "command", "args", "headersHelper"} {
		if b, _ := json.Marshal(cfg[key]); strings.Contains(string(b), Mask) {
			return "", fmt.Errorf("type the hidden parts of %s again: it changed", key)
		}
	}
	same := reflect.DeepEqual(cfg["url"], was["url"]) && reflect.DeepEqual(cfg["command"], was["command"])
	for _, key := range []string{"env", "headers"} {
		m, _ := cfg[key].(map[string]any)
		prev, _ := was[key].(map[string]any)
		for k, v := range m {
			if v != Mask {
				continue
			}
			p, ok := prev[k]
			switch {
			case !ok:
				return "", fmt.Errorf("%s %s has no value", strings.TrimSuffix(key, "s"), k)
			case !same:
				return "", fmt.Errorf("type %s %s again: the server's URL or command changed", strings.TrimSuffix(key, "s"), k)
			}
			m[k] = p
		}
	}
	b, _ := json.Marshal(cfg)
	return string(b), nil
}

package mcp

import (
	"encoding/json"
	"errors"
	"fmt"
	"maps"
	"reflect"
	"regexp"
	"slices"
	"strings"

	"github.com/afrase/nushi/internal/secrets"
)

// Mask stands in for the secrets in a server's config, which never leave
// the daemon: env and header values, a headers helper, an OAuth client's
// secret (PiG's oauth.clientSecret), and what looks secret in its URL,
// command and arguments (secrets' shapes too).
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
	if o, ok := cfg["oauth"].(map[string]any); ok && o["clientSecret"] != nil {
		o["clientSecret"] = Mask
	}
	if u, ok := cfg["url"].(string); ok {
		cfg["url"] = maskURL(secrets.Mask(u, Mask, nil))
	}
	if o, ok := cfg["oauth"].(map[string]any); ok {
		for _, key := range oauthURLs {
			if u, ok := o[key].(string); ok {
				o[key] = maskURL(secrets.Mask(u, Mask, nil))
			}
		}
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
	b, _ := json.Marshal(cfg) //nolint:errchkjson // decoded from JSON, so it encodes
	return string(b)
}

// oauthURLs are the URLs of PiG's oauth block, whose queries may carry
// a secret as the server's URL may.
var oauthURLs = []string{"callbackUrl", "authServerMetadataUrl"}

// field is a run of what isn't white space: a word of a program's output.
var field = regexp.MustCompile(`\S+`)

// maskText masks what a program printed (a server's stderr in its
// detail, the check's error, a sign-in's): the values under secret keys
// of any JSON object in it, secrets' shapes and the log's NAME: value
// rule (secrets.Names) anywhere, an Authorization header's value
// (maskAuthorization), then each line's words as maskArgs masks
// arguments, the lines and the space between words kept. It hides at
// least what the log's redactor does.
func maskText(s string) string {
	s = maskAuthorization(secrets.Mask(secrets.MaskJSONIn(s, Mask), Mask, secrets.Names))
	lines := strings.Split(s, "\n")
	for i, l := range lines {
		at := field.FindAllStringIndex(l, -1)
		words := make([]string, len(at))
		for j, a := range at {
			words[j] = l[a[0]:a[1]]
		}
		words = maskArgs(words)
		var b strings.Builder
		last := 0
		for j, a := range at {
			b.WriteString(l[last:a[0]])
			b.WriteString(words[j])
			last = a[1]
		}
		b.WriteString(l[last:])
		lines[i] = b.String()
	}
	return strings.Join(lines, "\n")
}

// maskHeader masks a header's value ("Authorization: Bearer x" keeps its
// name), or the whole of what isn't one. A name alone ("'Authorization:",
// a word of a line whose value maskAuthorization masked) stays.
func maskHeader(h string) string {
	if name, value, ok := strings.Cut(h, ":"); ok && !strings.Contains(name, " ") {
		if value == "" {
			return h
		}
		return name + ": " + Mask
	}
	return Mask
}

// authorization is an Authorization header's name and what parts it from
// its value.
var authorization = regexp.MustCompile(`(?i)\bauthorization(['"]?)[ \t]*[:=][ \t]*`)

// maskAuthorization masks the whole value after each "Authorization:" in
// s, whatever its scheme (Bearer, GitHub's token, Digest's): to the
// closing quote of the argument it stands in ('Authorization: token x'),
// or of its value (Authorization: "token x"), or else to the line's end.
// No word of it shows after the mask.
func maskAuthorization(s string) string {
	out, _ := maskAuthorizationIn(s)
	return out
}

// maskAuthorizationIn is maskAuthorization, and how many bytes its
// searches for a line's end and a closing quote read: at most twice
// len(s). A line's end is looked for once, for its first header, and
// a closing quote only up to it, from past what the last mask took.
func maskAuthorizationIn(s string) (out string, read int) {
	var b strings.Builder
	last, lineEnd := 0, -1
	for _, m := range authorization.FindAllStringSubmatchIndex(s, -1) {
		if m[0] < last {
			continue
		}
		start := m[1]
		if lineEnd < start {
			lineEnd = len(s)
			if nl := strings.IndexByte(s[start:], '\n'); nl >= 0 {
				lineEnd = start + nl
			}
			read += lineEnd - start
		}
		end := lineEnd
		quote := byte(0)
		switch {
		case start < end && (s[start] == '"' || s[start] == '\''):
			quote, start = s[start], start+1
		case m[2] == m[3] && m[0] > 0 && (s[m[0]-1] == '"' || s[m[0]-1] == '\''): // a quoted name's quote closes the name
			quote = s[m[0]-1]
		}
		if quote != 0 {
			q := strings.IndexByte(s[start:end], quote)
			if q >= 0 {
				end = start + q
			}
			read += end - start
		}
		value := strings.TrimRight(s[start:end], " \t\r")
		if value == "" || value == Mask {
			continue
		}
		b.WriteString(s[last:start])
		b.WriteString(Mask)
		last = start + len(value)
	}
	b.WriteString(s[last:])
	return b.String(), read
}

var (
	authValue  = regexp.MustCompile(`(?i)^['"]?(authorization:|bearer )`)
	secretWord = regexp.MustCompile(`(?i)key|token|secret|pass|pwd|auth|cred|bearer|session|cookie|private`)
	envName    = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)
	tokenChars = regexp.MustCompile(`^[A-Za-z0-9_-]{16,}$`)
	flagWord   = regexp.MustCompile(`^[a-z]+$`)       // -pthread, -pedantic, find's -print: no password
	idPair     = regexp.MustCompile(`^\d+:\d+['"]?$`) // docker's -u uid:gid
)

// secretNamed says a flag's or a variable's name says secret, and isn't
// a count's or a path's (secrets.NotSecret).
func secretNamed(name string) bool { return secretWord.MatchString(name) && !secrets.NotSecret(name) }

// maskLogin masks out[i]'s password when it is a login's: the one in
// -u or --user user:password (the next word, or after = or glued to
// -u), or one glued to -p; and says whether out[i] was such a flag.
func maskLogin(out []string, i int) bool {
	a := out[i]
	switch {
	case (a == "-u" || a == "--user") && i+1 < len(out):
		out[i+1] = maskUserPass(out[i+1])
	case strings.HasPrefix(a, "--user="):
		out[i] = "--user=" + maskUserPass(a[len("--user="):])
	case strings.HasPrefix(a, "-u") && !strings.HasPrefix(a, "--"):
		out[i] = "-u" + maskUserPass(a[2:])
	case strings.HasPrefix(a, "-p") && len(a) > 2 && !flagWord.MatchString(a[2:]):
		out[i] = "-p" + Mask
	default:
		return false
	}
	return true
}

// maskUserPass masks what follows the first colon of a -u or --user
// value (curl's user:password), a closing quote kept; a user alone, or
// a uid:gid, shows.
func maskUserPass(v string) string {
	user, pass, ok := strings.Cut(v, ":")
	if !ok || idPair.MatchString(v) {
		return v
	}
	core := strings.TrimRight(pass, `'"`)
	if core == "" || core == Mask {
		return v
	}
	return user + ":" + Mask + pass[len(core):]
}

// maskArgs masks the arguments that look secret: the value of a flag
// named like a secret (--api-key x, --token=x) or of a header (-H x,
// --header x), an Authorization or Bearer value anywhere, the password
// of -u or --user user:password and one glued to -p, VAR=x when VAR
// is named like a secret (not a count's or a path's: secrets.NotSecret)
// or follows -e/--env (docker run -e VAR=x), URLs'
// secrets, what internal/secrets knows the shape of (a GitHub or vendor
// token, a JWT, a PEM block) wherever it stands, and the same inside an
// argument of several words (sh -c '…').
// It's a display heuristic: what it doesn't recognize shows.
func maskArgs(args []string) []string {
	out := append([]string(nil), args...)
	for i, a := range out {
		// Secrets' shapes first, the whole argument at once: split into
		// words, a PEM block's would be masked one by one and miss.
		a = secrets.Mask(a, Mask, nil)
		out[i] = a
		name, _, eq := strings.Cut(a, "=")
		flag := strings.HasPrefix(a, "-")
		switch {
		case a == Mask:
		case (a == "-H" || a == "--header") && i+1 < len(out):
			out[i+1] = maskHeader(out[i+1])
		case authValue.MatchString(a):
			out[i] = maskHeader(a)
		case maskLogin(out, i):
		case strings.EqualFold(strings.Trim(a, `'"`), "bearer") && i+1 < len(out):
			out[i+1] = Mask
		case strings.ContainsAny(a, " \t\n"):
			out[i] = strings.Join(maskArgs(strings.Fields(maskAuthorization(a))), " ")
		case flag && eq && secretNamed(name):
			out[i] = name + "=" + Mask
		case flag && !eq && secretNamed(a) && i+1 < len(out) && !strings.HasPrefix(out[i+1], "-"):
			out[i+1] = Mask
		case !flag && eq && envName.MatchString(name) && (secretNamed(name) || i > 0 && (args[i-1] == "-e" || args[i-1] == "--env")):
			out[i] = name + "=" + Mask
		case strings.Contains(a, "://"): // quotes around it stay
			core := strings.Trim(a, `'"`)
			at := strings.Index(a, core)
			out[i] = a[:at] + maskURL(core) + a[at+len(core):]
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
			} else if tokenLike(p) {
				pairs[i] = Mask
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
// values, or a URL, command, arguments or helper sent back exactly as
// masked) taken from old. Hidden values go back only into a config that is
// then old exactly: after any other change (another URL, type, argument,
// header, env var…) they must be typed again, so an edit can't hand a
// stored secret to something else.
func unmasked(config, old string) (string, error) {
	cfg, err := decode(config)
	if err != nil {
		return "", err
	}
	was, _ := decode(old)
	shown, _ := decode(masked(old))
	var kept []string // the hidden values put back, by their keys
	for _, key := range []string{"url", "command", "args", "headersHelper"} {
		if cfg[key] != nil && reflect.DeepEqual(cfg[key], shown[key]) && !reflect.DeepEqual(shown[key], was[key]) {
			cfg[key], kept = was[key], append(kept, key)
		}
		if b, _ := json.Marshal(cfg[key]); strings.Contains(string(b), Mask) { //nolint:errchkjson // decoded from JSON, so it encodes
			return "", fmt.Errorf("type the hidden parts of %s again", key)
		}
	}
	for _, key := range []string{"env", "headers"} {
		m, _ := cfg[key].(map[string]any)
		prev, _ := was[key].(map[string]any)
		for _, k := range slices.Sorted(maps.Keys(m)) {
			if m[k] != Mask {
				continue
			}
			p, ok := prev[k]
			if !ok {
				return "", fmt.Errorf("%s %s has no value", strings.TrimSuffix(key, "s"), k)
			}
			m[k], kept = p, append(kept, key+"."+k)
		}
	}
	k, err := keptOAuthURLs(cfg, was, shown)
	if err != nil {
		return "", err
	}
	kept = append(kept, k...)
	if o, ok := cfg["oauth"].(map[string]any); ok && o["clientSecret"] == Mask {
		prev, _ := was["oauth"].(map[string]any)
		p, ok := prev["clientSecret"]
		if !ok {
			return "", errors.New("the OAuth client secret has no value")
		}
		o["clientSecret"], kept = p, append(kept, "oauth.clientSecret")
	}
	if len(kept) > 0 && !reflect.DeepEqual(cfg, was) {
		return "", typeAgain(kept)
	}
	b, err := json.Marshal(cfg)
	return string(b), err
}

// typeAgain is the refusal of an edit that changed a server whose hidden
// values ([keys], as "headers.Authorization") were sent back masked: each
// is named, and one of oauth's, which the app's form doesn't show, is
// typed again in Edit as JSON.
func typeAgain(keys []string) error {
	what := "value of " + keys[0]
	if n := len(keys); n > 1 {
		what = "values of " + strings.Join(keys[:n-1], ", ") + " and " + keys[n-1]
	}
	where := ""
	if slices.ContainsFunc(keys, func(k string) bool { return strings.HasPrefix(k, "oauth.") }) {
		where = ", in Edit as JSON"
	}
	return fmt.Errorf("the server changed: type the hidden %s (shown as %s) again%s", what, Mask, where)
}

// keptOAuthURLs puts back into cfg's oauth block each URL sent back
// exactly as shown (masked) from was, and gives the keys it put back; one
// still holding Mask otherwise must be typed again.
func keptOAuthURLs(cfg, was, shown map[string]any) (kept []string, err error) {
	o, ok := cfg["oauth"].(map[string]any)
	if !ok {
		return nil, nil
	}
	prev, _ := was["oauth"].(map[string]any)
	shownO, _ := shown["oauth"].(map[string]any)
	for _, key := range oauthURLs {
		if o[key] != nil && o[key] == shownO[key] && shownO[key] != prev[key] {
			o[key], kept = prev[key], append(kept, "oauth."+key)
		}
		if v, _ := o[key].(string); strings.Contains(v, Mask) {
			return nil, fmt.Errorf("type the hidden parts of oauth.%s again", key)
		}
	}
	return kept, nil
}

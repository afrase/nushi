package logs

import (
	"math/rand/v2"
	"regexp"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/secrets"
)

// The reference: origin/main's redactor, logs.Redact and the
// secrets.Mask it calls, copied as they are at origin/main 3308906a0
// (internal/logs/redact.go and internal/secrets/secrets.go, unchanged
// there since b69d6e0bd), renamed only. mainHidden below tracks which
// bytes of a line it replaced, and checks it writes what mainRedact does.

var mainShapes = regexp.MustCompile(strings.Join([]string{
	`()\bsk-[A-Za-z0-9_-]{16,}`,                                          // Anthropic (sk-ant-…), OpenAI (sk-proj-…)
	`()\bfw_[A-Za-z0-9]{16,}`,                                            // Fireworks
	`()\b(?:gh[pousr]_|github_pat_)\w{20,}`,                              // GitHub
	`()\bxox[abposr]-[A-Za-z0-9-]{10,}`,                                  // Slack
	`()\bAIza[0-9A-Za-z_-]{30,}`,                                         // Google
	`()\b(?:AKIA|ASIA)[0-9A-Z]{16}\b`,                                    // AWS key ids
	`()\beyJ[\w-]{8,}\.[\w-]{8,}\.[\w-]{8,}`,                             // JWTs
	`(-----BEGIN [A-Z0-9 ]+-----)[\s\S]*?(?:-----END [A-Z0-9 ]+-----|$)`, // PEM, to its end or the text's
	`((?i)\b(?:bearer|basic)\s+)[\w.~+/=-]{8,}`,
	`(://[^/\s:@]+:)[^/\s@]+@`, // a password in a URL
}, "|"))

var mainSecretNames = regexp.MustCompile(`((?i)\b[\w.-]*(?:key|token|secret|passw(?:or)?d|credential)[\w.-]*"?\s*[:=]\s*"?)[^\s"',;]{4,}`)

func mainRedact(s string) string {
	maskMu.RLock()
	for _, m := range masked {
		s = strings.ReplaceAll(s, m, "[redacted]")
	}
	maskMu.RUnlock()
	return mainMask(s, "[redacted]", mainSecretNames)
}

func mainMask(s, with string, extra *regexp.Regexp) string {
	s = mainReplace(mainShapes, s, with)
	if extra != nil {
		s = mainReplace(extra, s, with)
	}
	return s
}

func mainReplace(re *regexp.Regexp, s, with string) string {
	matches := re.FindAllStringSubmatchIndex(s, -1)
	if matches == nil {
		return s
	}
	var b strings.Builder
	last := 0
	for _, m := range matches {
		b.WriteString(s[last:m[0]])
		keep := ""
		for i := 2; i+1 < len(m); i += 2 {
			if m[i] >= 0 && m[i+1] > m[i] {
				keep = s[m[i]:m[i+1]]
				break
			}
		}
		b.WriteString(keep)
		b.WriteString(with)
		if strings.HasPrefix(keep, "://") {
			b.WriteByte('@')
		}
		last = m[1]
	}
	b.WriteString(s[last:])
	return b.String()
}

// tracked is mainReplace that also says where each byte it wrote came
// from: from[i] is the byte of s that out[i] is, or -1 for what it put
// in a secret's place; and hid marks the bytes of s it replaced.
func tracked(re *regexp.Regexp, s, with string, from []int) (out string, outFrom, hid []int) {
	var b strings.Builder
	last := 0
	copyFrom := func(i, j int) {
		b.WriteString(s[i:j])
		outFrom = append(outFrom, from[i:j]...)
	}
	for _, m := range re.FindAllStringSubmatchIndex(s, -1) {
		copyFrom(last, m[0])
		keep := 0
		for i := 2; i+1 < len(m); i += 2 {
			if m[i] >= 0 && m[i+1] > m[i] {
				keep = m[i+1] - m[i]
				break
			}
		}
		copyFrom(m[0], m[0]+keep)
		end := m[1]
		if strings.HasPrefix(s[m[0]:m[0]+keep], "://") {
			end-- // the '@' is written again
		}
		for i := m[0] + keep; i < end; i++ {
			if from[i] >= 0 {
				hid = append(hid, from[i])
			}
		}
		b.WriteString(with)
		for range len(with) {
			outFrom = append(outFrom, -1)
		}
		copyFrom(end, m[1])
		last = m[1]
	}
	copyFrom(last, len(s))
	return b.String(), outFrom, hid
}

// mainHidden is which bytes of l origin/main's Redact replaced (l holds
// no exact secret logs.Mask was given): its shapes', then its rule for
// names' on the text the shapes left, each byte traced to l.
func mainHidden(t *testing.T, l string) []bool {
	t.Helper()
	from := make([]int, len(l))
	for i := range from {
		from[i] = i
	}
	t1, from1, hid1 := tracked(mainShapes, l, "[redacted]", from)
	t2, _, hid2 := tracked(mainSecretNames, t1, "[redacted]", from1)
	if want := mainRedact(l); t2 != want {
		t.Fatalf("the tracked copy wrote %q, main's Redact %q", t2, want)
	}
	hidden := make([]bool, len(l))
	for _, i := range append(hid1, hid2...) {
		hidden[i] = true
	}
	return hidden
}

// fakeToken is a made-up token of n characters of chars.
func fakeToken(r *rand.Rand, n int, chars string) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = chars[r.IntN(len(chars))]
	}
	return string(b)
}

const (
	alnum = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	hexes = "0123456789abcdef"
	words = alnum + "_-"
)

// newShape is a made-up token of a shape origin/main didn't know.
func newShape(r *rand.Rand) string {
	switch r.IntN(10) {
	case 0:
		return []string{"sk_" + "live_", "rk_" + "test_", "sk_" + "test_", "rk_" + "live_"}[r.IntN(4)] + fakeToken(r, 16+r.IntN(8), alnum)
	case 1:
		return "glpat-" + fakeToken(r, 20+r.IntN(6), words)
	case 2:
		return "npm_" + fakeToken(r, 30+r.IntN(6), alnum)
	case 3:
		return "hf_" + fakeToken(r, 30+r.IntN(6), alnum)
	case 4:
		return "SK" + fakeToken(r, 32, hexes)
	case 5:
		return "GOCSPX-" + fakeToken(r, 24+r.IntN(6), words)
	case 6:
		return "dop_v1_" + fakeToken(r, 64, hexes)
	case 7:
		return "SG." + fakeToken(r, 22, words) + "." + fakeToken(r, 43, words)
	case 8:
		return []string{"shpat_", "shpss_"}[r.IntN(2)] + fakeToken(r, 32, hexes)
	default:
		return "GOCSPX-" + fakeToken(r, 26, alnum)
	}
}

// mainShape is a made-up token of a shape origin/main knew.
func mainShape(r *rand.Rand) string {
	switch r.IntN(9) {
	case 0:
		return "sk-ant-" + fakeToken(r, 16+r.IntN(6), words)
	case 1:
		return "fw_" + fakeToken(r, 16, alnum)
	case 2:
		return "ghp_" + fakeToken(r, 20+r.IntN(4), alnum)
	case 3:
		return "xoxb-" + fakeToken(r, 10+r.IntN(4), alnum)
	case 4:
		return "AIza" + fakeToken(r, 30+r.IntN(4), words)
	case 5:
		return "AKIA" + fakeToken(r, 16, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
	case 6:
		return "eyJ" + fakeToken(r, 8, alnum) + "." + fakeToken(r, 8, alnum) + "." + fakeToken(r, 8, alnum)
	case 7:
		return []string{"Bearer ", "basic ", "bearer "}[r.IntN(3)] + fakeToken(r, 8+r.IntN(6), alnum+"./=")
	default:
		return "https://u" + fakeToken(r, 2, alnum) + ":" + fakeToken(r, 6, alnum) + "@h.io/x"
	}
}

// logLine is a made-up line of a program's output: secret-ish names,
// separators, quotes, KeyError's forms, values, PEM headers and ends,
// URLs' parts, and tokens of main's shapes and of the new ones, glued
// to each other and to the rest or not.
func logLine(r *rand.Rand) (line string, newShapes int) {
	pick := func(of ...string) string { return of[r.IntN(len(of))] }
	var b strings.Builder
	for range 3 + r.IntN(10) {
		switch r.IntN(12) {
		case 0, 1:
			b.WriteString(pick("token", "api_key", "MY_TOKEN", "password", "passwd", "secret", "x-api-key", "secretary",
				"credentials", "Key", "keyPath", "max_tokens", "a_token", "zzzz_key", "missing_token", "TokenError", "user"))
		case 2:
			b.WriteString(pick("=", ": ", " = ", ":", " : ", "= ", "=", ": "))
		case 3:
			b.WriteString(pick("'", `"`, " ", ", ", "; ", "{", "}", "\n", "(", ""))
		case 4:
			b.WriteString(pick("KeyError: '", "KeyError: ", `KeyError: "`, "x.KeyError: '", "'KeyError': '"))
		case 5, 6:
			b.WriteString(newShape(r))
			newShapes++
		case 7:
			b.WriteString(mainShape(r))
		case 8:
			b.WriteString(pick("-----BEGIN RSA KEY-----", "-----BEGIN OPENSSH PRIVATE KEY-----\n", "\n-----END RSA KEY-----", "-----END OPENSSH PRIVATE KEY-----"))
		case 9:
			b.WriteString(pick("https://", "://", "u:", "@h.io/x", "postgres://app:", "@db"))
		default:
			b.WriteString(fakeToken(r, 1+r.IntN(10), "abcdefXYZ0123456789_.-+/"))
		}
	}
	return b.String(), newShapes
}

// window is a run of what a value could be made of, to look for in what
// the log wrote.
var window = regexp.MustCompile(`[A-Za-z0-9_.+/=-]+`)

// The log hides every byte of a line origin/main's log hid, whatever
// the line holds: shapes main knew and new ones glued to names, to PEM
// headers, to URLs and to each other; no line is passed over. Checked
// twice: byte by byte, on the spans the log replaces (which write what
// Redact writes), and on what the log writes: no run of five bytes main
// hid (and never wrote) shows.
func TestRedactHidesWhatMainHid(t *testing.T) {
	r := rand.New(rand.NewPCG(7, 11)) //nolint:gosec // seeded test lines, not a secret
	withNew := 0
	for range 5000 {
		l, n := logLine(r)
		if n > 0 {
			withNew++
		}
		hidden := mainHidden(t, l)
		was, now := mainRedact(l), Redact(l)
		spans := secrets.Spans(l, "[redacted]", secrets.Names)
		if got := secrets.Replace(l, spans); got != now {
			t.Fatalf("%q: the spans write %q, Redact %q", l, got, now)
		}
		hid := make([]bool, len(l))
		for _, sp := range spans {
			for i := sp.From; i < sp.To; i++ {
				hid[i] = true
			}
		}
		for i := range l {
			if hidden[i] && !hid[i] {
				t.Errorf("%q: main hid byte %d (%q), now it shows: %q", l, i, l[i], now)
				break
			}
		}
		for _, w := range window.FindAllStringIndex(l, -1) {
			for i := w[0]; i+5 <= w[1]; i++ {
				if !allHidden(hidden[i : i+5]) {
					continue
				}
				if part := l[i : i+5]; !strings.Contains(was, part) && strings.Contains(now, part) {
					t.Errorf("%q: main hid %q (%q), now %q", l, part, was, now)
					break
				}
			}
		}
	}
	if withNew < 3500 {
		t.Errorf("only %d lines hold a shape main didn't know", withNew)
	}
}

func allHidden(h []bool) bool {
	for _, b := range h {
		if !b {
			return false
		}
	}
	return true
}

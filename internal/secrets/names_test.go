package secrets

import (
	"math/rand/v2"
	"regexp"
	"strings"
	"testing"
)

// The reference: origin/main's MaskText, Mask with its shapes as one
// pattern and then its rule for a tool call's names on what that left,
// copied as they are at origin/main 3308906a0
// (internal/secrets/secrets.go and input.go), renamed only, its replace
// made to tell which bytes of the text it replaced.

var mainTextShapes = regexp.MustCompile(strings.Join([]string{
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

var mainSecretName = regexp.MustCompile(`((?i)\b[A-Za-z_][\w.-]*(?:token|secret|passw(?:or)?d|api[_-]?key|credential)[\w.-]*=)[^\s"',;&|]{4,}`)

// mainTextReplace is main's replace, from[i] being the byte of the
// first text s[i] is (-1 for what a mask put in), and hid the bytes of
// the first text it replaced.
func mainTextReplace(re *regexp.Regexp, s, with string, from []int) (out string, outFrom, hid []int) {
	var b strings.Builder
	last := 0
	put := func(i, j int) {
		b.WriteString(s[i:j])
		outFrom = append(outFrom, from[i:j]...)
	}
	for _, m := range re.FindAllStringSubmatchIndex(s, -1) {
		put(last, m[0])
		keep := 0
		for i := 2; i+1 < len(m); i += 2 {
			if m[i] >= 0 && m[i+1] > m[i] {
				keep = m[i+1] - m[i]
				break
			}
		}
		put(m[0], m[0]+keep)
		end := m[1]
		if strings.HasPrefix(s[m[0]:m[0]+keep], "://") {
			end--
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
		put(end, m[1])
		last = m[1]
	}
	put(last, len(s))
	return b.String(), outFrom, hid
}

// textLine is a made-up tool call's text: names that hold the words, in
// every place and case, =, values, and tokens glued to them.
func textLine(r *rand.Rand) string {
	pick := func(of ...string) string { return of[r.IntN(len(of))] }
	var b strings.Builder
	for range 3 + r.IntN(8) {
		switch r.IntN(6) {
		case 0, 1:
			b.WriteString(pick("token", "MY_TOKEN", "tokenizer", "my_tokenizer", "secretary", "my_secretary", "max_tokens",
				"apiKey", "x-api-key", "API_KEY_FILE", "credentialsFile", "db.password", "passwordless", "AUTHTOKEN", "tokenUrl", "a.secret.b"))
		case 2:
			b.WriteString(pick("=", "==", " ", "&&", "'", "\n"))
		case 3:
			b.WriteString(pick("hf_", "ghp_", "sk-ant-", "GOCSPX-", "Bearer ") + strings.Repeat("Ab3", 8+r.IntN(4)))
		default:
			const chars = "abcXYZ0129_.-/"
			v := make([]byte, 1+r.IntN(10))
			for i := range v {
				v[i] = chars[r.IntN(len(chars))]
			}
			b.Write(v)
		}
	}
	return b.String()
}

// A tool call's text hides every byte origin/main's MaskText hid, on a
// few thousand made-up lines, shapes and all: the rule for names may
// show what main's never masked, never what it did.
func TestMaskTextHidesWhatMainHid(t *testing.T) {
	r := rand.New(rand.NewPCG(5, 8)) //nolint:gosec // seeded test lines, not a secret
	for range 5000 {
		l := textLine(r)
		from := make([]int, len(l))
		for i := range from {
			from[i] = i
		}
		t1, from1, hid1 := mainTextReplace(mainTextShapes, l, InputMask, from)
		_, _, hid2 := mainTextReplace(mainSecretName, t1, InputMask, from1)
		spans := Spans(l, InputMask, secretName)
		if got := Replace(l, spans); got != MaskText(l) {
			t.Fatalf("%q: the spans write %q, MaskText %q", l, got, MaskText(l))
		}
		now := make([]bool, len(l))
		for _, sp := range spans {
			for i := sp.From; i < sp.To; i++ {
				now[i] = true
			}
		}
		for _, i := range append(hid1, hid2...) {
			if !now[i] {
				t.Errorf("%q: main hid byte %d (%q), now it shows: %q", l, i, l[i], MaskText(l))
				break
			}
		}
	}
}

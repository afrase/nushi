// Package secrets masks what looks like a key or token in text: the shapes
// both the log (internal/logs) and tool calls' input (MaskInput: a chat's
// transcript, a workflow agent's steps) mask. Each keeps its own rule for
// NAME=value pairs: the log's is broad, and a tool call's input holds
// code, which that rule would mask.
//
// Every rule is a detector: it reports the spans of the text as given
// that it masks, never reading another rule's output, and a mask replaces
// the union of all of them in one pass (Spans, Replace). One detector is
// the floor: what origin/main's Mask masked, run as main ran it, so a
// mask hides at least every byte main's did, whatever a newer rule finds.
package secrets

import (
	"cmp"
	"regexp"
	"slices"
	"sort"
	"strings"
)

// mainShapes are origin/main's shapes (at b69d6e0bd, unchanged at
// 3308906a0): vendors' prefixes, AWS key ids, JWTs, PEM blocks, the values
// of bearer and basic credentials, and a password in a URL. A match's
// first group that isn't empty (what names the secret) is kept.
var mainShapes = []string{
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
}

// moreShapes are the vendors' prefixes main didn't know: Stripe, GitLab,
// npm, Hugging Face, Twilio, Google's OAuth clients, DigitalOcean,
// SendGrid and Shopify.
var moreShapes = []string{
	`()\b[sr]k_(?:live|test)_[A-Za-z0-9]{16,}`, // Stripe's secret and restricted keys
	`()\bglpat-[A-Za-z0-9_-]{20,}`,             // GitLab
	`()\bnpm_[A-Za-z0-9]{30,}`,                 // npm
	`()\bhf_[A-Za-z0-9]{30,}`,                  // Hugging Face
	`()\bSK[0-9a-fA-F]{32}\b`,                  // Twilio's API keys
	`()\bGOCSPX-[A-Za-z0-9_-]{24,}`,            // Google's OAuth client secrets
	`()\bdop_v1_[0-9a-f]{64}\b`,                // DigitalOcean
	`()\bSG\.[\w-]{22}\.[\w-]{43}`,             // SendGrid
	`()\bshp(?:at|ss)_[0-9a-fA-F]{32}\b`,       // Shopify's access tokens and shared secrets
}

// shapes are each shape on its own, so each finds every match of its own
// in the text as given: one shape's match never hides another's start (a
// GOCSPX- key's run of dashes eating a PEM block's header).
var shapes = func() []shape {
	var out []shape
	for _, p := range slices.Concat(mainShapes, moreShapes) {
		prefix, _ := regexp.MustCompile(strings.TrimPrefix(p, `()\b`)).LiteralPrefix()
		out = append(out, shape{regexp.MustCompile(p), prefix})
	}
	return out
}()

// A shape is a secret's pattern and the text every match of it starts
// with ("" when none in particular). A text without that is passed over
// unread: a pattern that opens on \b gets none of the regexp package's
// search for a literal start, and reads every byte slowly.
type shape struct {
	re     *regexp.Regexp
	prefix string
}

// floorShapes are main's shapes as main ran them: one pattern, the
// leftmost match taken, the floor's first step.
var floorShapes = regexp.MustCompile(strings.Join(mainShapes, "|"))

// A NameRule masks the values of NAME=value pairs whose name says
// secret: what each of its patterns matches past its first group (the
// name, kept) where accept takes that group (nil: whatever it is), and at
// least what floor, origin/main's rule, masked run as main ran it (after
// main's shapes, on the text they left).
type NameRule struct {
	patterns []*regexp.Regexp
	accept   func(group string) bool
	floor    *regexp.Regexp
}

// Names are NAME=value, NAME: value, "name": "value" or 'name': 'value'
// pairs (TOML's and a Node object dump's single quotes) whose name says
// secret, in a line of a program's output (an agent's stderr, a
// failed MCP server's): the log's rule (internal/logs), and the MCP
// page's, so the app is never sent more than the log shows. Broader than
// a tool call's input's rule: a line of output isn't code. Its floor is
// the log's rule as main had it, before it took a single quote.
var Names = &NameRule{
	patterns: []*regexp.Regexp{regexp.MustCompile(`((?i)\b[\w.-]*(?:key|token|secret|passw(?:or)?d|credential)[\w.-]*['"]?\s*[:=]\s*['"]?)[^\s"',;]{4,}`)},
	floor:    regexp.MustCompile(`((?i)\b[\w.-]*(?:key|token|secret|passw(?:or)?d|credential)[\w.-]*"?\s*[:=]\s*"?)[^\s"',;]{4,}`),
}

// plainNames are names that say secret but name something else: a
// count of tokens or its limit, a tokenizer, a key's path. Each is a
// whole name, lower case, without _ or -.
var plainNames = map[string]bool{
	"maxtokens": true, "mintokens": true, "maxoutputtokens": true, "maxcompletiontokens": true,
	"maxnewtokens": true, "maxtokenstosample": true, "budgettokens": true,
	"inputtokens": true, "outputtokens": true, "totaltokens": true, "prompttokens": true,
	"completiontokens": true, "cachedtokens": true, "reasoningtokens": true, "thinkingtokens": true,
	"cachereadinputtokens": true, "cachecreationinputtokens": true,
	"tokencount": true, "tokenlimit": true, "tokenbudget": true, "tokensused": true, "tokenusage": true,
	"tokenizer": true, "tokeniser": true, "keypath": true,
}

// NotSecret says whether name, though named like a secret, is a plain
// one (plainNames: max_tokens, token_count, tokenizer, keyPath), its
// value no secret: only the whole name, case, _ and - (a flag's too)
// aside, so a secret's name that holds one (API_KEY_MAX_TOKENS,
// my_tokenizer_api_key) is still a secret's. A JSON key, a flag's or a
// variable's name asks it; the log's rule for names in text doesn't.
func NotSecret(name string) bool {
	return plainNames[separators.Replace(strings.ToLower(name))]
}

// separators drops a name's _ and -, for NotSecret: one for every call (a
// Replacer is safe to share).
var separators = strings.NewReplacer("_", "", "-", "")

// keyError says whether the match of a rule for names from at, its name
// to value and its value to end, is Python's KeyError: 'NAME' (the bare
// word KeyError, a colon, a space and a name in single quotes), whose
// quoted name is a missing key's, not a secret: the one name the log's
// rule never masked (it took no single quote then), and only in that
// form. Only a plain name is passed over, never what holds a NAME=value
// ('API_KEY=x'), and only that name: what follows it is still read.
func keyError(s string, at, value, end int) bool {
	return s[at:value] == "KeyError: '" && (at == 0 || !nameByte(s[at-1])) &&
		end < len(s) && s[end] == '\'' && plainName(s[value:end])
}

// plainName says whether s is a name alone, of name bytes only.
func plainName(s string) bool {
	for i := range len(s) {
		if !nameByte(s[i]) {
			return false
		}
	}
	return s != ""
}

// nameByte says whether c can be part of a name: a word's byte, '.' or
// '-'.
func nameByte(c byte) bool {
	return c == '_' || c == '.' || c == '-' || '0' <= c && c <= '9' || 'a' <= c && c <= 'z' || 'A' <= c && c <= 'Z'
}

// A Span is a run of a text to replace, From to To, and what stands in
// for it.
type Span struct {
	From, To int
	With     string
}

// Mask replaces what looks like a secret in s with with: the spans its
// detectors find (Spans), in one pass. What names a secret ("NAME=", a
// URL's user and its '@', "Bearer ") is kept.
func Mask(s, with string, names *NameRule) string {
	return Replace(s, Spans(s, with, names))
}

// Spans are what Mask replaces in s, each by with: every detector's, all
// on s as given: each shape alone; each of names' patterns (nil: none),
// whatever the name but Python's KeyError: 'NAME' (keyError); and the
// floor, what origin/main's Mask masked in s (floor). Their union is
// what is hidden: a caller may add its own detectors' spans before
// Replace.
func Spans(s, with string, names *NameRule) []Span {
	var runs [][2]int
	for _, sh := range shapes {
		if strings.Contains(s, sh.prefix) {
			runs = append(runs, find(sh.re, s, false, nil)...)
		}
	}
	if names != nil {
		for _, re := range names.patterns {
			runs = append(runs, find(re, s, true, names.accept)...)
		}
	}
	runs = append(runs, floor(s, with, names)...)
	out := make([]Span, 0, len(runs))
	for _, r := range runs {
		out = append(out, Span{r[0], r[1], with})
	}
	return out
}

// find is what re's matches in s mask: each from the end of its first
// group that isn't empty (what names the secret, kept) to its end, but a
// URL's '@'. Named (a rule for names), Python's KeyError: 'NAME' masks
// nothing, and a match whose first group accept doesn't take masks
// nothing either.
func find(re *regexp.Regexp, s string, named bool, accept func(string) bool) [][2]int {
	var out [][2]int
	for _, m := range re.FindAllStringSubmatchIndex(s, -1) {
		from, keep := m[0], ""
		for i := 2; i+1 < len(m); i += 2 {
			if m[i] >= 0 && m[i+1] > m[i] {
				from, keep = m[i+1], s[m[i]:m[i+1]]
				break
			}
		}
		if named && (keyError(s, m[0], from, m[1]) || accept != nil && !accept(keep)) {
			continue
		}
		to := m[1]
		if strings.HasPrefix(keep, "://") {
			to-- // the '@' stays
		}
		// A run can be empty: a key's BEGIN line with nothing after it
		// (a stderr read a line at a time). It still gets the mask, as it
		// always did, so the line says a key was there.
		if to > from || to == from && keep != "" && !strings.HasPrefix(keep, "://") {
			out = append(out, [2]int{from, to})
		}
	}
	return out
}

// floor is what origin/main's Mask masked in s, computed as main computed
// it: its shapes as one pattern (floorShapes) on s, then names' floor on
// the text that left (each shape's run replaced by with), each of that
// rule's runs traced back to s. A run that takes in any byte of a
// replaced run covers that run's whole span of s.
func floor(s, with string, names *NameRule) [][2]int {
	shaped := find(floorShapes, s, false, nil)
	if names == nil || names.floor == nil {
		return shaped
	}
	var b strings.Builder
	at := make([]int, len(shaped)) // where each run's with starts in main's text
	last := 0
	for i, r := range shaped {
		b.WriteString(s[last:r[0]])
		at[i] = b.Len()
		b.WriteString(with)
		last = r[1]
	}
	b.WriteString(s[last:])
	// origin is the span of s the byte at x of main's text stands for.
	origin := func(x int) (from, to int) {
		k := sort.Search(len(at), func(i int) bool { return at[i] > x }) - 1
		switch {
		case k < 0:
			return x, x + 1
		case x < at[k]+len(with):
			return shaped[k][0], shaped[k][1]
		}
		o := shaped[k][1] + x - at[k] - len(with)
		return o, o + 1
	}
	out := shaped
	for _, r := range find(names.floor, b.String(), false, nil) {
		from, _ := origin(r[0])
		_, to := origin(r[1] - 1)
		out = append(out, [2]int{from, to})
	}
	return out
}

// Replace is s with spans replaced: those that touch or overlap as one
// run, which the With of the one that starts first stands in for (the
// longest of those that start there; of those, the first given).
func Replace(s string, spans []Span) string {
	if len(spans) == 0 {
		return s
	}
	spans = slices.Clone(spans)
	slices.SortStableFunc(spans, func(a, b Span) int {
		return cmp.Or(cmp.Compare(a.From, b.From), cmp.Compare(b.To, a.To))
	})
	var b strings.Builder
	last := 0
	for i := 0; i < len(spans); {
		first := spans[i]
		to := first.To
		for i++; i < len(spans) && spans[i].From <= to; i++ {
			to = max(to, spans[i].To)
		}
		b.WriteString(s[last:first.From])
		b.WriteString(first.With)
		last = to
	}
	b.WriteString(s[last:])
	return b.String()
}

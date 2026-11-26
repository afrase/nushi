// Package secrets masks what looks like a key or token in text: the shapes
// both the log (internal/logs) and tool calls' input (MaskInput: a chat's
// transcript, a workflow agent's steps) mask. Each keeps its own rule for
// NAME=value pairs: the log's is broad, and a tool call's input holds
// code, which that rule would mask.
package secrets

import (
	"cmp"
	"regexp"
	"slices"
	"strings"
)

// shapes are what keys and tokens look like in any string: vendors'
// prefixes (Anthropic, OpenAI, Fireworks, GitHub, Slack, Google and its
// OAuth clients', Stripe, GitLab, npm, Hugging Face, Twilio,
// DigitalOcean, SendGrid, Shopify), AWS key ids, JWTs, PEM
// blocks, the values of bearer and basic credentials, and a password in a
// URL. A match's first group that isn't empty (what names the secret) is
// kept.
var shapes = regexp.MustCompile(strings.Join([]string{
	`()\bsk-[A-Za-z0-9_-]{16,}`,                                          // Anthropic (sk-ant-…), OpenAI (sk-proj-…)
	`()\bfw_[A-Za-z0-9]{16,}`,                                            // Fireworks
	`()\b(?:gh[pousr]_|github_pat_)\w{20,}`,                              // GitHub
	`()\bxox[abposr]-[A-Za-z0-9-]{10,}`,                                  // Slack
	`()\bAIza[0-9A-Za-z_-]{30,}`,                                         // Google
	`()\b[sr]k_(?:live|test)_[A-Za-z0-9]{16,}`,                           // Stripe's secret and restricted keys
	`()\bglpat-[A-Za-z0-9_-]{20,}`,                                       // GitLab
	`()\bnpm_[A-Za-z0-9]{30,}`,                                           // npm
	`()\bhf_[A-Za-z0-9]{30,}`,                                            // Hugging Face
	`()\bSK[0-9a-fA-F]{32}\b`,                                            // Twilio's API keys
	`()\bGOCSPX-[A-Za-z0-9_-]{24,}`,                                      // Google's OAuth client secrets
	`()\bdop_v1_[0-9a-f]{64}\b`,                                          // DigitalOcean
	`()\bSG\.[\w-]{22}\.[\w-]{43}`,                                       // SendGrid
	`()\bshp(?:at|ss)_[0-9a-fA-F]{32}\b`,                                 // Shopify's access tokens and shared secrets
	`()\b(?:AKIA|ASIA)[0-9A-Z]{16}\b`,                                    // AWS key ids
	`()\beyJ[\w-]{8,}\.[\w-]{8,}\.[\w-]{8,}`,                             // JWTs
	`(-----BEGIN [A-Z0-9 ]+-----)[\s\S]*?(?:-----END [A-Z0-9 ]+-----|$)`, // PEM, to its end or the text's
	`((?i)\b(?:bearer|basic)\s+)[\w.~+/=-]{8,}`,
	`(://[^/\s:@]+:)[^/\s@]+@`, // a password in a URL
}, "|"))

// A NameRule masks the values of NAME=value pairs whose name says
// secret: what each of its patterns matches past its first group (the
// name, which is kept), the union where their matches overlap.
type NameRule []*regexp.Regexp

// Names are NAME=value, NAME: value, "name": "value" or 'name': 'value'
// pairs (TOML's and a Node object dump's single quotes) whose name says
// secret, in a line of a program's output (an agent's stderr, a
// failed MCP server's), masked after the shapes: the log's rule
// (internal/logs), and the MCP page's, so the app is never sent more than
// the log shows. Broader than a tool call's input's rule: a line of
// output isn't code. The second pattern is the log's rule before it took
// a single quote (as at b69d6e0bd): a single quote can start a match
// earlier and take in the name that rule matched later (a_token='x_key"
// = value), so the log masks the union of both, and hides at least what
// it hid before.
var Names = NameRule{
	regexp.MustCompile(`((?i)\b[\w.-]*(?:key|token|secret|passw(?:or)?d|credential)[\w.-]*['"]?\s*[:=]\s*['"]?)[^\s"',;]{4,}`),
	regexp.MustCompile(`((?i)\b[\w.-]*(?:key|token|secret|passw(?:or)?d|credential)[\w.-]*"?\s*[:=]\s*"?)[^\s"',;]{4,}`),
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
// variable's name asks it; the rule for names in text doesn't (spans).
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

// Mask replaces what looks like a secret in s with with: the shapes
// above, then what names matches (nil: nothing more), each of its
// patterns on the same text, whose first group is kept as theirs is
// ("NAME="), whatever the name but Python's KeyError: 'NAME' (keyError).
// A URL keeps its user and its '@'.
func Mask(s, with string, names NameRule) string {
	s = masked(s, with, spans(shapes, s, false))
	var all [][2]int
	for _, re := range names {
		all = append(all, spans(re, s, true)...)
	}
	return masked(s, with, all)
}

// spans are what re's matches in s mask: each from the end of its first
// group that isn't empty (what names the secret, kept) to its end, but a
// URL's '@'. Named, Python's KeyError: 'NAME' masks nothing. The log's rule
// takes every name, a plain one's too (NotSecret is for a JSON key, a
// flag or a variable): the log hides at least what it hid before the
// rule was shared, and the MCP page at least what the log hides.
func spans(re *regexp.Regexp, s string, named bool) [][2]int {
	var out [][2]int
	for _, m := range re.FindAllStringSubmatchIndex(s, -1) {
		from, keep := m[0], ""
		for i := 2; i+1 < len(m); i += 2 {
			if m[i] >= 0 && m[i+1] > m[i] {
				from, keep = m[i+1], s[m[i]:m[i+1]]
				break
			}
		}
		if named && keyError(s, m[0], from, m[1]) {
			continue
		}
		to := m[1]
		if strings.HasPrefix(keep, "://") {
			to-- // the '@' stays
		}
		out = append(out, [2]int{from, to})
	}
	return out
}

// masked is s with each of spans replaced by with, those that overlap
// as one.
func masked(s, with string, spans [][2]int) string {
	if len(spans) == 0 {
		return s
	}
	slices.SortFunc(spans, func(a, b [2]int) int { return cmp.Compare(a[0], b[0]) })
	var b strings.Builder
	last := 0
	for i := 0; i < len(spans); {
		from, to := spans[i][0], spans[i][1]
		for i++; i < len(spans) && spans[i][0] < to; i++ {
			to = max(to, spans[i][1])
		}
		b.WriteString(s[last:from])
		b.WriteString(with)
		last = to
	}
	b.WriteString(s[last:])
	return b.String()
}

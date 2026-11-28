package secrets

import (
	"regexp"
	"strings"
	"testing"
)

// hex64 is 64 made-up hex digits.
const hex64 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

func TestMask(t *testing.T) {
	name := regexp.MustCompile(`((?i)\b[A-Za-z_]\w*token=)\S{4,}`)
	for _, tc := range []struct{ in, want string }{
		{"key sk-ant-api03-abcdefghijklmnopqrstuv end", "key ** end"},
		{"-----BEGIN OPENSSH PRIVATE KEY-----", "-----BEGIN OPENSSH PRIVATE KEY-----**"}, // a key's first line alone still says so
		{"fw_3ZabcdefghijklmnopqrstUV", "**"},
		{"ghp_abcdefghijklmnopqrstuvwxyz0123456789 github_pat_11ABCDEFG0123456789_abcdefghij", "** **"},
		{"xoxb-123456789012-abcdefghijkl xoxp-123456789012-abcdefghijkl", "** **"},
		{"AIzaSyA-abcdefghijklmnopqrstuvwxyz01234", "**"},
		{"AKIAIOSFODNN7EXAMPLE", "**"},
		{"Invalid API Key provided: sk_" + "live_FAKEfakeFAKEfake12345678", "Invalid API Key provided: **"}, // Stripe
		{"rk_" + "live_FAKEfakeFAKEfake12345678 sk_" + "test_FAKEfakeFAKEfake12345678", "** **"},
		{"glpat" + "-FAKEfakeFAKEfake1234 rejected", "** rejected"},                                                                      // GitLab
		{"npm ERR! token npm" + "_FAKEfakeFAKEfakeFAKEfakeFAKEfake1234", "npm ERR! token **"},                                            // npm
		{"huggingface hf" + "_FAKEfakeFAKEfakeFAKEfakeFAKEfake bad", "huggingface ** bad"},                                               // Hugging Face
		{"Twilio SK" + "0123456789abcdef0123456789abcdef auth error", "Twilio ** auth error"},                                            // Twilio's API key
		{"pk_live_FAKEfakeFAKEfake12345678 SKU SK12 npm_install hf_hub", "pk_live_FAKEfakeFAKEfake12345678 SKU SK12 npm_install hf_hub"}, // a publishable key, words
		{"do dop_v1_" + hex64 + " bad", "do ** bad"},                                                                                     // DigitalOcean
		{"SG" + ".FAKEfakeFAKEfake0016ab.FAKEfakeFAKEfakeFAKEfakeFAKEfakeFAKEfake016 denied", "** denied"},                               // SendGrid
		{"client_secret GOCSPX" + "-FAKEfakeFAKEfakeFAKEfake0017", "client_secret **"},                                                   // Google OAuth
		{"shpat" + "_0123456789abcdef0123456789abcdef shpss" + "_0123456789abcdef0123456789abcdef", "** **"},                             // Shopify
		{"SG.json shpat_short dop_v1_abc", "SG.json shpat_short dop_v1_abc"},                                                             // words
		{"jwt eyJhbGciOiJI.eyJzdWIiOiIx.SflKxwRJSMeKKF2QT4f", "jwt **"},
		{"Authorization: Bearer abc.def-ghi_jkl", "Authorization: Bearer **"},
		{"basic dXNlcjpwYXNzd29yZA==", "basic **"},
		{"https://me:hunter22@example.com/x", "https://me:**@example.com/x"},
		{"a\n-----BEGIN RSA PRIVATE KEY-----\nMIIEow\n-----END RSA PRIVATE KEY-----\nb", "a\n-----BEGIN RSA PRIVATE KEY-----**\nb"},
		{"-----BEGIN OPENSSH PRIVATE KEY-----\nb3Blbn", "-----BEGIN OPENSSH PRIVATE KEY-----**"}, // cut before its end
		{"GH_TOKEN=abcd1234 next", "GH_TOKEN=** next"},                                           // extra's rule
		{"GH_TOKEN=ghp_abcdefghijklmnopqrstuvwxyz0123456789", "GH_TOKEN=**"},                     // both
		{"session 019a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8 ok", "session 019a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8 ok"},
		{"sk-short", "sk-short"},
		{"", ""},
	} {
		if got := Mask(tc.in, "**", &NameRule{patterns: []*regexp.Regexp{name}}); got != tc.want {
			t.Errorf("Mask(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
	if got := Mask("GH_TOKEN=abcd1234", "**", nil); got != "GH_TOKEN=abcd1234" {
		t.Errorf("without extra: %q", got)
	}
}

// Names takes a name's value whichever quote is around the name or the
// value: JSON's and YAML's double, TOML's and a Node object dump's single.
func TestNames(t *testing.T) {
	for _, tc := range []struct{ in, want string }{
		{`api_key = "FAKEquoted0034"`, `api_key = "**"`},
		{`token = 'FAKEtoml0003abc'`, `token = '**'`},
		{`{ headers: { 'X-Api-Key': 'FAKEtrace0005abc' } }`, `{ headers: { 'X-Api-Key': '**' } }`},
		{`"password": "FAKEpw0021"`, `"password": "**"`},
		{`apiKey: FAKEkey0020`, `apiKey: **`},
		{`KeyError: 'GITHUB_PERSONAL_ACCESS_TOKEN'`, `KeyError: 'GITHUB_PERSONAL_ACCESS_TOKEN'`}, // an error's name
	} {
		if got := Mask(tc.in, "**", Names); got != tc.want {
			t.Errorf("Mask(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

// stillSecret are names that hold a name NotSecret knows but aren't it:
// the review's three, then each known name as a prefix, a suffix and a
// part of a secret's name, in each separator style and case.
var stillSecret = []string{
	"PRIVATE_KEY_PATH_PASSWORD", "my_tokenizer_api_key", "REFRESH_TOKEN_LIMIT_KEY",
	"max_tokens_api_key", "API_KEY_MAX_TOKENS", "github-max-tokens-secret", "maxTokensSecret", "secret.max_tokens",
	"token_count_secret", "SECRET_TOKEN_COUNT", "tokenCountPassword", "api.token_limit", "token-limit-token",
	"tokenizer_token", "openai-tokenizer-api-key", "secretTokenizer", "tokenizer.secret", "HF_TOKENIZER_TOKEN",
	"key_path_password", "SSH_KEY_PATH_TOKEN", "deploy-key-path-secret", "privateKeyPathPassword", "signing.key_path.secret",
	"input_tokens_secret", "secret_tokens_used", "x-token-budget-key",
	"KeyErrorToken", "API_KEY_ERROR", "secret_error", "token-exception", "AuthTokenError", "KEYERROR_TOKEN",
	"tokenizers_token", "key_paths_secret",
}

// plainNames' spellings: their values show where NotSecret is asked (a
// JSON key, a flag, a variable).
var plain = []string{
	"max_tokens", "MAX_TOKENS", "maxTokens", "max-tokens", "--max-tokens", "max_output_tokens", "budget_tokens",
	"input_tokens", "output_tokens", "cache_read_input_tokens", "total_tokens",
	"token_count", "tokenCount", "token_limit", "--token-limit", "token_budget", "tokens_used",
	"tokenizer", "Tokenizer", "--tokenizer", "key_path", "keyPath", "KEYPATH",
}

// A name is not a secret's only when it is a known plain name whole, case
// and _ or - aside: one that holds such a name is still a secret's.
func TestNotSecret(t *testing.T) {
	for _, n := range stillSecret {
		if NotSecret(n) {
			t.Errorf("NotSecret(%q): its value would show", n)
		}
		for _, line := range []string{n + "=FAKEvalue0001", n + ": FAKEvalue0001", `"` + n + `": "FAKEvalue0001"`} {
			if got := Mask(line, "**", Names); strings.Contains(got, "FAKEvalue0001") {
				t.Errorf("Mask(%q) = %q", line, got)
			}
		}
		if got := MaskJSONIn(`{"`+n+`": "FAKEvalue0001"}`, "**"); strings.Contains(got, "FAKEvalue0001") {
			t.Errorf("MaskJSONIn: %q", got)
		}
	}
	for _, n := range plain {
		if !NotSecret(n) {
			t.Errorf("NotSecret(%q) = false", n)
		}
	}
}

// The log's rule for names takes every name, a plain one too, as it did
// before NotSecret; Python's KeyError: 'NAME', whose quoted value is a
// missing key's name, alone shows, as it always did, and only in that
// exact form.
func TestNamesInText(t *testing.T) {
	for _, tc := range []struct{ in, want string }{
		{"max_tokens=4096 token_count: 1234", "max_tokens=** token_count: **"},
		{`"tokenizer": "cl100k" keyPath=server.tools`, `"tokenizer": "**" keyPath=**`},
		{"KeyError: 'GITHUB_TOKEN'", "KeyError: 'GITHUB_TOKEN'"},
		{"KeyError: GITHUB_TOKEN", "KeyError: **"},
		{`KeyError: "GITHUB_TOKEN"`, `KeyError: "**"`},
		{"x.KeyError: 'GITHUB_TOKEN'", "x.KeyError: '**'"},
		{"keyerror: 'GITHUB_TOKEN'", "keyerror: '**'"},
		{"TokenError: 'abcd1234'", "TokenError: '**'"},
		{"KeyError: 'GITHUB_TOKEN' token=abcd1234", "KeyError: 'GITHUB_TOKEN' token=**"}, // only the name passes
		{"KeyError: 'API_KEY=abcd1234'", "KeyError: '**'"},                               // a NAME=value, not a name
		{"'KeyError': 'Zq9vAl8eXy'", "'KeyError': '**'"},                                 // not Python's form
		{"KeyError:'GITHUB_TOKEN'", "KeyError:'**'"},
		{"KeyError: 'GITHUB_TOKEN", "KeyError: '**"}, // no closing quote
	} {
		if got := Mask(tc.in, "**", Names); got != tc.want {
			t.Errorf("Mask(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

// A tool call's text masks NAME=value whose name ends in a word that
// says secret, whole (the name split at . _ - and where lower case turns
// upper): password=, MY_TOKEN=, apiKey=. A name that only starts with
// such a word (secretary=, tokenizer=, credentialsFile=) shows, as does
// code's == and a name with no = after it; what origin/main's rule
// masked (any name holding the word after another character:
// my_secretary=, max_tokens=) stays masked, its floor.
func TestMaskText(t *testing.T) {
	for _, tc := range []struct{ in, want string }{
		{"MY_TOKEN=FAKEtext0001 make", "MY_TOKEN=•••• make"},
		{"password=FAKEtext0002 make", "password=•••• make"},
		{"token=FAKEtext0003", "token=••••"},
		{"secret=FAKEtext0004 && run", "secret=•••• && run"},
		{"api_key=FAKEtext0005", "api_key=••••"},
		{"curl -d 'apikey=FAKEtext0006'", "curl -d 'apikey=••••'"},
		{"Credential=FAKEtext0007", "Credential=••••"},
		{"passwd=FAKEtext0008 TokenError=FAKEtext0009", "passwd=•••• TokenError=FAKEtext0009"},
		{"apiKey=FAKEtext0012 db.password=FAKEtext0013", "apiKey=•••• db.password=••••"},
		{"AUTH_TOKEN=FAKEtext0014 x-api-key=FAKEtext0015", "AUTH_TOKEN=•••• x-api-key=••••"},
		{"--password=FAKEtext0016 credentials=FAKEtext0017", "--password=•••• credentials=••••"},
		{"x == token; password: FAKEtext0010", "x == token; password: FAKEtext0010"},
		{"tokens=abc keyed=FAKEtext0011", "tokens=abc keyed=FAKEtext0011"},
		// A key after secret or private is one; a key alone isn't, nor an id.
		{"SECRET_KEY=FAKEtext0020 run", "SECRET_KEY=•••• run"},
		{"secret_key=FAKEtext0021 secretKey=FAKEtext0022", "secret_key=•••• secretKey=••••"},
		{"private_key=FAKEtext0023 SECRET_ACCESS_KEY=FAKEtext0024", "private_key=•••• SECRET_ACCESS_KEY=••••"},
		{"primary_key=users_id1 KEY=FAKEtext0025", "primary_key=users_id1 KEY=FAKEtext0025"},
		{"monkey=banana12 token_id=FAKEtext0026", "monkey=banana12 token_id=FAKEtext0026"},
		// Names that only start with the word: no secret.
		{"secretary=alice1234", "secretary=alice1234"},
		{"tokenizer=cl100k_base", "tokenizer=cl100k_base"},
		{"tokens=1234567", "tokens=1234567"},
		{"passwordless=true", "passwordless=true"},
		{"secretsmanager=aws1", "secretsmanager=aws1"},
		{"credentialsFile=/x/y.json", "credentialsFile=/x/y.json"},
		{"tokenUrl=https://h.io/t", "tokenUrl=https://h.io/t"},
		{"token_count=2048", "token_count=2048"},
		{"git -c credential.helper=store push", "git -c credential.helper=store push"},
		// The floor: origin/main masked these, so they stay masked.
		{"my_secretary=alice1234", "my_secretary=••••"},
		{"max_tokens=4096 AUTHTOKEN=FAKEtext0018", "max_tokens=•••• AUTHTOKEN=••••"},
		{"x_tokenizer=cl100k_base", "x_tokenizer=••••"},
	} {
		if got := MaskText(tc.in); got != tc.want {
			t.Errorf("MaskText(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

// NotSecret shares one Replacer: a call allocates no more than the
// lowered name and the name without its separators.
func TestNotSecretSharesItsReplacer(t *testing.T) {
	if n := testing.AllocsPerRun(100, func() { NotSecret("MAX_OUTPUT_TOKENS") }); n > 2 {
		t.Errorf("%.0f allocations a call", n)
	}
}

// Each rule reads the text as given: a shape main didn't know, glued to
// a secret's name or to a PEM block's header, hides neither the name's
// value nor the block (the third pass's verifier's lines).
func TestRulesReadTheTextAsGiven(t *testing.T) {
	for _, tc := range []struct{ in, want string }{
		{"hf" + "_FAKEfakeFAKEfakeFAKEfakeFAKE0001secretary=FAKEalice01", "**=**"},
		{"hf" + "_FAKEfakeFAKEfakeFAKEfakeFAKE0002credentials= FAKEcred0002 x", "**= ** x"},
		{"GOCSPX" + "-FAKEfakeFAKEfakeFAKEfake03-----BEGIN RSA KEY-----\nFAKEbody0003\n-----END RSA KEY-----", "** RSA KEY-----**"},
		{"glpat" + "-FAKEfakeFAKEfake0004-----BEGIN RSA KEY-----\nFAKEbody0004", "** RSA KEY-----**"},
		{"sk_" + "live_FAKEfakeFAKEfake0005token=FAKEvalue05", "**=**"},
		{"a token=sk-ant-FAKEfakeFAKEfake0006 b", "a token=** b"}, // one span where two rules meet
	} {
		if got := Mask(tc.in, "**", Names); got != tc.want {
			t.Errorf("Mask(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

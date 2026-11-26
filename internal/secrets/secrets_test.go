package secrets

import (
	"regexp"
	"testing"
)

// hex64 is 64 made-up hex digits.
const hex64 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

func TestMask(t *testing.T) {
	name := regexp.MustCompile(`((?i)\b[A-Za-z_]\w*token=)\S{4,}`)
	for _, tc := range []struct{ in, want string }{
		{"key sk-ant-api03-abcdefghijklmnopqrstuv end", "key ** end"},
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
		if got := Mask(tc.in, "**", name); got != tc.want {
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
		{`KeyError: 'GITHUB_PERSONAL_ACCESS_TOKEN'`, `KeyError: 'GITHUB_PERSONAL_ACCESS_TOKEN'`},                                       // an error's name
		{`token_count=1234 keyPath=server.tools "tokenizer": "cl100k"`, `token_count=1234 keyPath=server.tools "tokenizer": "cl100k"`}, // not secrets
	} {
		if got := Mask(tc.in, "**", Names); got != tc.want {
			t.Errorf("Mask(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

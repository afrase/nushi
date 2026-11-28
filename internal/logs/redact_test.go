package logs

import (
	"regexp"
	"strings"
	"testing"
)

// beforeNames is what the log's redactor made of each line before the
// rule for names became internal/secrets' (secrets.Names): origin/main's
// Redact at b69d6e0bd, run on each line.
var beforeNames = []struct{ in, was string }{
	{"max_tokens=4096", "max_tokens=[redacted]"},
	{`{"max_tokens": 4096, "input_tokens": 1234, "x": 1}`, `{"max_tokens": [redacted], "input_tokens": [redacted], "x": 1}`},
	{"token_count=1234 done", "token_count=[redacted] done"},
	{"loaded token_count=12 keyPath=server.tools --token-limit 4096", "loaded token_count=12 keyPath=[redacted] --token-limit 4096"},
	{`{"tokenizer":"cl100k"} loaded`, `{"tokenizer":"[redacted]"} loaded`},
	{"PRIVATE_KEY_PATH_PASSWORD=hunter2hunter2", "PRIVATE_KEY_PATH_PASSWORD=[redacted]"},
	{"my_tokenizer_api_key: abcd1234efgh", "my_tokenizer_api_key: [redacted]"},
	{"REFRESH_TOKEN_LIMIT_KEY=abcd1234efgh", "REFRESH_TOKEN_LIMIT_KEY=[redacted]"},
	{"max_tokens_secret=abcd1234", "max_tokens_secret=[redacted]"},
	{"deploy-key-path=/home/me/.ssh/id_ed25519", "deploy-key-path=[redacted]"},
	{"API_KEY_ERROR=abcd1234", "API_KEY_ERROR=[redacted]"},
	{"token_exception: abcd1234", "token_exception: [redacted]"},
	{"AuthTokenError: abcd1234", "AuthTokenError: [redacted]"},
	{"KeyError: GITHUB_TOKEN", "KeyError: [redacted]"},
	{`KeyError: "GITHUB_TOKEN"`, `KeyError: "[redacted]"`},
	{"Traceback (most recent call last):\n  File \"/opt/mcp/server.py\", line 12, in <module>\nKeyError: 'GITHUB_PERSONAL_ACCESS_TOKEN'", "Traceback (most recent call last):\n  File \"/opt/mcp/server.py\", line 12, in <module>\nKeyError: 'GITHUB_PERSONAL_ACCESS_TOKEN'"},
	{"token = 'abcd1234'", "token = 'abcd1234'"},
	{"FIREWORKS_API_KEY=abcd1234 next", "FIREWORKS_API_KEY=[redacted] next"},
	{"x-api-key: abcd1234 password=hunter22", "x-api-key: [redacted] password=[redacted]"},
	// The verifier's five: a NAME=value inside KeyError's quotes, and a
	// single quote that started a match before the name main matched.
	{"KeyError: 'API_KEY=FAKEkeyerr01'", "KeyError: 'API_KEY=[redacted]'"},
	{"KeyError: 'password: FAKEkeyerr02'", "KeyError: 'password: [redacted]'"},
	{`KeyError: 'missing_token": "FAKEkeyerr03"`, `KeyError: 'missing_token": "[redacted]"`},
	{`a_token='zzzz_key" = FAKEquote004`, `a_token='zzzz_key" = [redacted]`},
	{`token: 'x_secret": "FAKEquote005"`, `token: 'x_secret": "[redacted]"`},
}

// valueWord is a run of what a value could be made of.
var valueWord = regexp.MustCompile(`[A-Za-z0-9_.+/-]{4,}`)

// The log hides at least what it hid before its rule for names was
// shared: every word the old redactor hid stays hidden.
func TestRedactHidesWhatItHid(t *testing.T) {
	for _, l := range beforeNames {
		got := Redact(l.in)
		for _, w := range valueWord.FindAllString(l.in, -1) {
			if !strings.Contains(l.was, w) && strings.Contains(got, w) {
				t.Errorf("%q: was %q, now shows %q in %q", l.in, l.was, w, got)
			}
		}
	}
}

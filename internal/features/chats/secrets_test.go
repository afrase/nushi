package chats

import (
	"encoding/json"
	"strings"
	"testing"
)

// A tool call's input loses what looks secret before it is kept (and
// saved in the transcript's copy): values of keys named like a secret,
// and every well-known token shape, wherever it is.
func TestSecretsMaskedInInput(t *testing.T) {
	pem := "-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAABG5vbmU=\n-----END OPENSSH PRIVATE KEY-----"
	shapes := map[string]string{
		"anthropic":   "sk-ant-api03-Zr8fakeFAKEfake0123456789",
		"openai":      "sk-proj-abcdefghijklmnop1234",
		"github":      "ghp_abcdefghijklmnopqrstuvwxyz0123456789",
		"github fine": "github_pat_11ABCDEFG0123456789_abcdefghijklmnopqrstuvwxyz",
		"slack":       "xoxb-123456789012-abcdefghijkl",
		"aws":         "AKIAIOSFODNN7EXAMPLE",
		"jwt":         "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U",
		"pem":         pem,
	}
	for name, secret := range shapes {
		core := secret
		if name == "pem" {
			core = "b3BlbnNzaC1rZXktdjEAAAAABG5vbmU="
		}
		for _, form := range []string{
			"curl -s https://api.example.com/v1 -d " + secret, // in a command
			"see " + secret + " here",                         // in prose
		} {
			raw, _ := json.Marshal(map[string]any{"command": form, "description": "Call the API && print"})
			got := inputText(raw)
			if strings.Contains(got, core) {
				t.Errorf("%s: kept in %s", name, got)
			}
			if !strings.Contains(got, secretMask) || !strings.Contains(got, "Call the API && print") {
				t.Errorf("%s: %s", name, got)
			}
		}
	}

	raw := json.RawMessage(`{"url": "https://x.dev", "headers": {"Authorization": "Bearer abcdefgh12345678", "Accept": "json"},
		"api_key": "plain-value", "password": "hunter2", "client_secret": "s3cr3t", "Cookie": "sid=abc", "private_key": "k",
		"tokens": ["one", "two"], "max_tokens": 4096, "input_tokens": 12, "token_count": 3, "env": "GITHUB_TOKEN=abcd1234 make", "note": "Bearer token rotation",
		"git": "https://me:pa55word@github.com/x.git"}`)
	want := `{
  "url": "https://x.dev",
  "headers": {
    "Authorization": "••••",
    "Accept": "json"
  },
  "api_key": "••••",
  "password": "••••",
  "client_secret": "••••",
  "Cookie": "••••",
  "private_key": "••••",
  "tokens": [
    "••••",
    "••••"
  ],
  "max_tokens": 4096,
  "input_tokens": 12,
  "token_count": 3,
  "env": "GITHUB_TOKEN=•••• make",
  "note": "Bearer token rotation",
  "git": "https://me:••••@github.com/x.git"
}`
	if got := inputText(raw); got != want {
		t.Errorf("by key, in order:\n%s\nwant:\n%s", got, want)
	}

	// Under a secret key, however deep, every value; a token as a key.
	nested := json.RawMessage(`{"password": {"value": "x", "pin": 1234, "on": true, "none": null},
		"token": [["x"], {"k": "y"}], "ghp_abcdefghijklmnopqrstuvwxyz0123456789": true}`)
	wantNested := `{
  "password": {
    "value": "••••",
    "pin": "••••",
    "on": "••••",
    "none": null
  },
  "token": [
    [
      "••••"
    ],
    {
      "k": "••••"
    }
  ],
  "••••": true
}`
	if got := inputText(nested); got != wantNested {
		t.Errorf("nested:\n%s\nwant:\n%s", got, wantNested)
	}

	// Not JSON: the shapes still go.
	if got := inputText(json.RawMessage(`not json ghp_abcdefghijklmnopqrstuvwxyz0123456789`)); got != "not json ••••" {
		t.Errorf("text input: %q", got)
	}
}

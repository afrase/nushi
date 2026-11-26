package mcp

import (
	"context"
	"errors"
	"regexp"
	"strings"
	"testing"

	"github.com/afrase/nushi/internal/logs"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/testcheck"
)

// printed is what a failed server may print, made up: the second
// review's 34 rows (the first five before them), each with what must not
// show and what must. Two can't be known by shape and show: they say so.
var printed = []struct {
	name, said string
	hidden     []string // what must not show
	kept       []string // what must
}{
	{"a token's shape", "MCP connection closed\nauth failed for key ghp_" + "abcdefghijklmnopqrstuvwxyz0123456789 (made-up)", []string{"abcdefghijklmnopqrstuvwxyz0123456789"}, []string{"MCP connection closed\nauth failed for key ", " (made-up)"}},
	{"a secret-named word", "bad login: token=abc123 user=me", []string{"abc123"}, []string{"token=", "user=me"}},
	{"a secret-named flag", "spawned with --api-key s3cr3t-value\n  at main", []string{"s3cr3t-value"}, []string{"--api-key", "\n  at main"}},
	{"a bearer", "sent Authorization: Bearer abc.def.ghi", []string{"abc.def.ghi"}, []string{"sent "}},
	{"a URL's secrets", "GET https://u:pw@h.io/x?key=v failed", []string{"pw", "key=v"}, []string{"h.io/x", " failed"}},

	{"anthropic", "error: invalid x-api-key sk-ant-api03-FAKEfakeFAKEfake0001", []string{"FAKEfakeFAKEfake0001"}, []string{"error: invalid x-api-key "}},
	{"openai proj", "401 Incorrect API key provided: sk-proj-FAKEfakeFAKEfake0002", []string{"FAKEfakeFAKEfake0002"}, []string{"401 Incorrect API key provided: "}},
	{"github ghp", "remote: token ghp_FAKEfakeFAKEfakeFAKEfake0003", []string{"FAKEfakeFAKEfakeFAKEfake0003"}, []string{"remote: token "}},
	{"github pat", "using github_pat_11FAKEfakeFAKEfake0004_abcdef", []string{"FAKEfakeFAKEfake0004"}, []string{"using "}},
	{"slack bot", "slack: invalid_auth xoxb-123456789012-FAKEfake0005", []string{"FAKEfake0005"}, []string{"slack: invalid_auth "}},
	{"google", "API key not valid: AIzaSyFAKEfakeFAKEfakeFAKEfake0006xyz", []string{"FAKEfakeFAKEfakeFAKEfake0006"}, []string{"API key not valid: "}},
	{"aws id", "The security token included AKIAFAKEFAKEFAKE0007 is invalid", []string{"AKIAFAKEFAKEFAKE0007"}, []string{"The security token included ", " is invalid"}},
	{"aws secret kv", "aws_secret_access_key=wJalrFAKEFAKEFAKE0008", []string{"wJalrFAKEFAKEFAKE0008"}, []string{"aws_secret_access_key="}},
	{"aws secret spaced", "AWS_SECRET_ACCESS_KEY: wJalrFAKEFAKEFAKE0009", []string{"wJalrFAKEFAKEFAKE0009"}, []string{"AWS_SECRET_ACCESS_KEY: "}},
	{"stripe live", "Invalid API Key provided: sk_" + "live_FAKEfakeFAKEfake12345678", []string{"FAKEfakeFAKEfake12345678"}, []string{"Invalid API Key provided: "}},
	{"stripe rk", "restricted key rk_" + "live_FAKEfakeFAKEfake12345678 denied", []string{"FAKEfakeFAKEfake12345678"}, []string{"restricted key ", " denied"}},
	{"gitlab", "glpat" + "-FAKEfakeFAKEfake1234 rejected", []string{"FAKEfakeFAKEfake1234"}, []string{" rejected"}},
	{"npm", "npm ERR! token npm" + "_FAKEfakeFAKEfakeFAKEfakeFAKEfake1234", []string{"FAKEfakeFAKEfakeFAKEfakeFAKEfake1234"}, []string{"npm ERR! token "}},
	// The review spelled it "SK FAKE…": Twilio's key is SK and 32 hex.
	{"twilio", "Twilio SK" + "0123456789abcdef0123456789abcdef auth error", []string{"0123456789abcdef0123456789abcdef"}, []string{"Twilio ", " auth error"}},
	{"hf", "huggingface hf" + "_FAKEfakeFAKEfakeFAKEfakeFAKEfake unauthorized", []string{"FAKEfakeFAKEfakeFAKEfakeFAKEfake"}, []string{"huggingface ", " unauthorized"}},
	{"jwt", "jwt expired eyJhbGciOiJI.eyJzdWIiOiIx.SflKxwRJSMeKKF2QT4f", []string{"eyJzdWIiOiIx", "SflKxwRJSMeKKF2QT4f"}, []string{"jwt expired "}},
	{"bearer", "> Authorization: Bearer FAKEbearer0017", []string{"FAKEbearer0017"}, []string{"> Authorization: "}},
	{"bearer lower short", "sent bearer FAKE0018x", []string{"FAKE0018x"}, []string{"sent bearer "}},
	{"kv token", "connect failed token=FAKE0019", []string{"FAKE0019"}, []string{"connect failed token="}},
	{"kv apikey colon", "config apiKey: FAKEkey0020", []string{"FAKEkey0020"}, []string{"config apiKey: "}},
	{"kv password", "db password=FAKEpw0021", []string{"FAKEpw0021"}, []string{"db password="}},
	{"json token", `{"error":"unauthorized","token":"FAKEjson0022"}`, []string{"FAKEjson0022"}, []string{`{"error":"unauthorized","token":"`}},
	{"json access_token", `{"access_token": "FAKEjson0023", "expires_in": 3600}`, []string{"FAKEjson0023"}, []string{`{"access_token": "`, `", "expires_in": 3600}`}},
	{"url userpass", "connect to postgres://app:FAKEpw0024@db.internal:5432/app failed", []string{"FAKEpw0024"}, []string{"@db.internal:5432/app failed"}},
	{"url query", "GET https://api.example.com/v1?api_key=FAKE0025&x=1 -> 403", []string{"FAKE0025"}, []string{"https://api.example.com/v1?api_key=", " -> 403"}},
	{"split lines", "Authorization: Bearer\nFAKEsplit0026", []string{"FAKEsplit0026"}, []string{"Authorization: "}},
	// A token broken across lines: its second half has no shape and
	// follows no name, so it shows. Can't be known by shape.
	{"split token", "key ghp_FAKEfakeFAKEfakeFAKEfake0027\nsplitFAKEsplit0027", []string{"ghp_FAKEfakeFAKEfakeFAKEfake0027"}, []string{"splitFAKEsplit0027"}},
	{"base64 basic", "Authorization: Basic dXNlcjpGQUtFcGFzczAwMjg=", []string{"dXNlcjpGQUtFcGFzczAwMjg="}, []string{"Authorization: "}},
	// A bare base64 blob is any data's shape too: it shows. Can't be
	// known by shape.
	{"base64 blob", "secret blob dXNlcjpGQUtFcGFzc3dvcmQwMDEwZmFrZWZha2U=", nil, []string{"dXNlcjpGQUtFcGFzc3dvcmQwMDEwZmFrZWZha2U="}},
	{"pem", "-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEFAKE0030\n-----END OPENSSH PRIVATE KEY-----", []string{"b3BlbnNzaC1rZXktdjEFAKE0030"}, []string{"-----BEGIN OPENSSH PRIVATE KEY-----"}},
	{"env dump", "env: GITHUB_TOKEN=FAKEenv0031 HOME=/Users/x", []string{"FAKEenv0031"}, []string{"env: GITHUB_TOKEN=", " HOME=/Users/x"}},
	{"cookie", "Set-Cookie: session=FAKEcookie0032; Path=/", []string{"FAKEcookie0032"}, []string{"Set-Cookie: session="}},
	{"x-api-key header", "x-api-key: FAKEhdr0033", []string{"FAKEhdr0033"}, []string{"x-api-key: "}},
	{"quoted kv", `api_key = "FAKEquoted0034"`, []string{"FAKEquoted0034"}, []string{`api_key = "`}},
	// Single quotes, as TOML and a Node object dump (axios's failed
	// request) print them (the third review's V03 and V05).
	{"toml single quotes", "token = 'FAKEtoml0003abc'", []string{"FAKEtoml0003abc"}, []string{"token = '"}},
	{"node object", "AxiosError: 401\n  config: { headers: { 'X-Api-Key': 'FAKEtrace0005abc' } }", []string{"FAKEtrace0005abc"}, []string{"AxiosError: 401\n  config: { headers: { 'X-Api-Key': '"}},
	// After "Authorization:" the rest of the header is the secret, whatever
	// its scheme (GitHub's "token", Digest's, an ApiKey), to the argument's
	// closing quote or the line's end (the third review's V09 and V24).
	{"github token scheme quoted", "curl -H 'Authorization: token FAKEcurl0009abc' https://api.example.com", []string{"token FAKE", "FAKEcurl0009abc"}, []string{"curl -H 'Authorization: ", "' https://api.example.com"}},
	{"yaml token scheme", "headers:\n  Authorization: \"token FAKEyaml0024abc\"\nnext", []string{"token FAKE", "FAKEyaml0024abc"}, []string{"  Authorization: \"", "\"\nnext"}},
	{"apikey scheme double quoted", `curl -H "Authorization: ApiKey FAKEapikey0041abc" -d x`, []string{"ApiKey", "FAKEapikey0041abc"}, []string{`curl -H "Authorization: `, `" -d x`}},
	{"digest scheme bare", "> authorization: Digest username=me, response=FAKEdigest0042abc\n< 401", []string{"Digest", "FAKEdigest0042abc"}, []string{"> authorization: ", "\n< 401"}},
	{"token scheme bare", "Authorization: Token FAKEtok0043abc", []string{"Token", "FAKEtok0043abc"}, []string{"Authorization: "}},
	// A command line's user:password after -u or --user, and a password
	// glued to -p (the third review's V10, V11 and V20).
	{"curl -u", "curl -u admin:FAKEcurl0010abc https://h.io/api", []string{"FAKEcurl0010abc"}, []string{"curl -u admin:", " https://h.io/api"}},
	{"curl --user", "curl --user 'admin:FAKEcurl0011abc' https://h.io", []string{"FAKEcurl0011abc"}, []string{"curl --user 'admin:", "' https://h.io"}},
	{"curl --user=", "curl --user=admin:FAKEcurl0012abc", []string{"FAKEcurl0012abc"}, []string{"curl --user=admin:"}},
	{"mysql -p", "mysql -uroot -pFAKEmy0020abc -h db", []string{"FAKEmy0020abc"}, []string{"mysql -uroot -p", " -h db"}},
	// JSON pasted unescaped inside a JSON string (the fourth review's
	// three): an array, a value with spaces, a short value.
	{"pasted array", `{"x": "a {"password": ["FAKEarr0044", 98765]}`, []string{"FAKEarr0044", "98765"}, []string{`{"x": "a {"password": [`}},
	{"pasted spaces", `{"error": "invalid", "detail": "body was {"password": "fake horse battery staple"}"}`, []string{"horse", "battery", "staple"}, []string{`"detail": "body was {"password": `}},
	{"pasted short", `{"a": "unterminated {"token": "abc"}`, []string{`"abc"`}, []string{`{"a": "unterminated {"token": `}},
	{"json in a line", `HTTP 401: {"error": {"code": 401, "password": 98765432}} retrying`, []string{"98765432"}, []string{`HTTP 401: {"error": {"code": 401, "password": `, `}} retrying`}},
	// A plain name (secrets.NotSecret) in NAME=value or "key": "value" is
	// masked as the log masks it: the log's rule takes every name.
	{"key path", "loaded keyPath=server.tools", []string{"server.tools"}, []string{"loaded keyPath="}},
	{"tokenizer in json", `{"tokenizer":"cl100k"} loaded`, []string{"cl100k"}, []string{`{"tokenizer":"`, `"} loaded`}},
}

// readable is what a server prints that holds no secret: it reads as
// printed, or nearly (the review's over-masking cases, kept as they are).
var readable = []string{
	"Error: Cannot find module '/Users/me/dev/mcp-server-github/dist/index.js'\n    at Module._resolveFilename (node:internal/modules/cjs/loader:1145:15)",
	"Traceback (most recent call last):\n  File \"/opt/mcp/server.py\", line 12, in <module>\nKeyError: 'GITHUB_PERSONAL_ACCESS_TOKEN'",
	"error: unexpected argument '--auth-token' found\n  tip: to pass '--auth-token' as a value, use '-- --auth-token'",
	"Error: missing env GITHUB_TOKEN",
	"npx srv -p 8080 -u alice: EADDRINUSE",
	"cc -pthread -pedantic -o srv srv.c",
	"docker run -u 1000:1000 srv",
	"loaded token_count=12 --token-limit 4096 --tokenizer cl100k",
}

// Nothing a server prints leaves the daemon unmasked: a failed server's
// detail (PiG's error is the server's own stderr), one only the check
// knows, the check's own error, and a sign-in's or sign-out's error, for
// every agent; and an OAuth client's callback and metadata URLs in a
// config.
func TestWhatAServerPrintsIsMasked(t *testing.T) {
	for _, c := range printed {
		svc := New("pig", &fakeConfig{
			files:   []model.MCPServer{{Name: "s", Scope: "user"}},
			checked: []model.MCPServer{{Name: "s", State: "failed", Detail: c.said}, {Name: "x", Scope: "project", State: "failed", Detail: c.said}},
		}, nil)
		got, _, err := svc.List(context.Background(), "/f", true)
		if err != nil || len(got) != 2 {
			t.Fatalf("%s: %v %v", c.name, got, err)
		}
		_, checkErr, _ := New("pig", &fakeConfig{checkErr: errors.New("pig mcp list: " + c.said)}, nil).List(context.Background(), "/f", true)
		account := New("claude", &fakeConfig{accountErr: errors.New("signing in to s didn't finish: " + c.said)}, nil)
		loginErr := account.Login(context.Background(), "/f", "s")
		logoutErr := account.Logout(context.Background(), "/f", "s")
		if checkErr == nil || loginErr == nil || logoutErr == nil {
			t.Fatalf("%s: %v %v %v", c.name, checkErr, loginErr, logoutErr)
		}
		for _, out := range []string{got[0].Detail, got[1].Detail, checkErr.Error(), loginErr.Error(), logoutErr.Error()} {
			for _, h := range c.hidden {
				if strings.Contains(out, h) {
					t.Errorf("%s: %q shows %q", c.name, out, h)
				}
			}
			for _, k := range c.kept {
				if !strings.Contains(out, k) {
					t.Errorf("%s: %q lost %q", c.name, out, k)
				}
			}
		}
	}
	for _, r := range readable {
		if got := maskText(r); got != r {
			t.Errorf("%q became %q", r, got)
		}
	}
	shown := masked(`{"url":"https://h.io/mcp","oauth":{"callbackUrl":"http://127.0.0.1:8765/cb?state=s1","authServerMetadataUrl":"https://h.io/.well-known/x?api_key=s2"}}`)
	if strings.Contains(shown, "s1") || strings.Contains(shown, "s2") || !strings.Contains(shown, "127.0.0.1:8765/cb?state=") {
		t.Errorf("oauth URLs: %s", shown)
	}
}

// word is a run of what a secret could be made of.
var word = regexp.MustCompile(`[A-Za-z0-9_.+/=-]{4,}`)

// The log never hides more than the app is sent: each line above, put
// through the log's redactor and through the mask the app's text takes,
// and every word the log hides is hidden from the app too.
func TestTheAppIsSentNoMoreThanTheLogShows(t *testing.T) {
	lines := append([]string(nil), readable...)
	for _, c := range printed {
		lines = append(lines, c.said)
	}
	for _, l := range lines {
		logged, sent := logs.Redact(l), maskText(l)
		for _, w := range word.FindAllString(l, -1) {
			if !strings.Contains(logged, w) && strings.Contains(sent, w) {
				t.Errorf("%q: the log hides %q, the app is sent %q", l, w, sent)
			}
		}
	}
}

// The OAuth URLs sent back as shown keep what they hid; changed, the
// hidden parts must be typed again.
func TestOAuthURLsComeBackAsTheyWere(t *testing.T) {
	old := `{"url":"https://h.io/mcp","oauth":{"callbackUrl":"http://127.0.0.1:8765/cb?state=s1"}}`
	got, err := unmasked(masked(old), old)
	if err != nil || !strings.Contains(got, "state=s1") {
		t.Errorf("sent back as shown: %s, %v", got, err)
	}
	if got, err := unmasked(`{"url":"https://h.io/mcp","oauth":{"callbackUrl":"http://127.0.0.1:9999/cb?state=••••"}}`, old); err == nil {
		t.Errorf("a changed URL kept its hidden part: %s", got)
	}
}

// A refused edit names each hidden value that must be typed again, and
// sends one the form doesn't show (oauth's) to Edit as JSON.
func TestTheRefusalNamesTheHiddenValues(t *testing.T) {
	const old = `{"url":"https://h.io/mcp?key=s1","headers":{"Authorization":"Bearer s2"},` +
		`"oauth":{"authServerMetadataUrl":"https://login.example.com/0f3a9c1e-77b2-4d8e-9a10-3c5d2e8b4f61/v2.0/meta","clientSecret":"s3"}}`
	shown := decoded(masked(old))
	for _, c := range []struct {
		name string
		edit func(map[string]any)
		want string
	}{
		{"a header added", func(m map[string]any) {
			m["headers"].(map[string]any)["X-Team"] = "blue"
		}, "the server changed: type the hidden values of url, headers.Authorization, oauth.authServerMetadataUrl " +
			"and oauth.clientSecret (shown as ••••) again, in Edit as JSON"},
		{"only yours, the URL typed again", func(m map[string]any) {
			m["url"] = "https://h.io/mcp?key=new"
			delete(m, "oauth")
		}, "the server changed: type the hidden value of headers.Authorization (shown as ••••) again"},
	} {
		edit := decoded(masked(old))
		c.edit(edit)
		if _, err := unmasked(testcheck.JSON(t, edit), old); err == nil || err.Error() != c.want {
			t.Errorf("%s: %v\nwant %s", c.name, err, c.want)
		}
	}
	if _, err := unmasked(testcheck.JSON(t, shown), old); err != nil {
		t.Errorf("sent back as shown: %v", err)
	}
}

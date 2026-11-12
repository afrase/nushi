package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"testing/fstest"
)

// The app a relay serves: none without an origin (a pipe, as before a
// release's relay had one built in), the one built in at -origin, a
// folder's with -web (its origin https://<host> with -host), and a
// refusal that says what to do when -origin has no app to serve.
func TestSite(t *testing.T) {
	app := fstest.MapFS{"index.html": {Data: []byte("built in")}}
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "index.html"), []byte("a folder's"), 0o600); err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct {
		name, dir, origin, host string
		built                   bool
		want, fails             string
	}{
		{name: "a pipe", built: true},
		{name: "a pipe with TLS", host: "relay.example.com", built: true},
		{name: "a pipe built without the app"},
		{name: "built in", origin: "https://relay.example.com", built: true, want: "built in"},
		{name: "a folder's instead", dir: dir, origin: "https://relay.example.com", built: true, want: "a folder's"},
		{name: "a folder's, the host's origin", dir: dir, host: "relay.example.com", want: "a folder's"},
		{name: "a folder without an origin", dir: dir, fails: "origin"},
		{name: "no app", origin: "https://relay.example.com", fails: "built without the web app"},
		{name: "a bad origin", origin: "relay.example.com", built: true, fails: "origin"},
	} {
		var in fstest.MapFS
		if c.built {
			in = app
		}
		var s http.Handler
		got, err := site(c.dir, c.origin, c.host, builtInFrom(in))
		switch {
		case c.fails != "":
			if err == nil || !strings.Contains(err.Error(), c.fails) {
				t.Errorf("%s: %v", c.name, err)
			}
			continue
		case err != nil:
			t.Errorf("%s: %v", c.name, err)
			continue
		case c.want == "":
			if got != nil {
				t.Errorf("%s: serves an app", c.name)
			}
			continue
		case got == nil:
			t.Errorf("%s: serves nothing", c.name)
			continue
		}
		s = got
		w := httptest.NewRecorder()
		s.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/", http.NoBody))
		if w.Body.String() != c.want || !strings.Contains(w.Header().Get("Content-Security-Policy"), "wss://relay.example.com") {
			t.Errorf("%s: served %q, %q", c.name, w.Body.String(), w.Header().Get("Content-Security-Policy"))
		}
	}
}

// The repository's web folder holds a placeholder, not an app: a relay
// built from it has none.
func TestBuiltInIsEmptyHere(t *testing.T) {
	if _, err := os.Stat("web/index.html"); err == nil {
		t.Skip("a web app was copied into cmd/nushi-relay/web")
	}
	if builtIn() != nil {
		t.Fatal("a relay built from the repository has a web app")
	}
}

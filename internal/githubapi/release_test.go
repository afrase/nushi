package githubapi

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

// TestLatestRelease: the latest release, asked without a token and with
// the last answer's ETag (a 304 is the same answer); a repository with
// none is ErrNotFound, and GitHub failing is an error.
func TestLatestRelease(t *testing.T) {
	status := http.StatusOK
	var asked []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		asked = append(asked, r.Method+" "+r.URL.Path+" "+r.Header.Get("If-None-Match")+" "+r.Header.Get("Authorization"))
		switch {
		case status != http.StatusOK:
			w.WriteHeader(status)
		case r.Header.Get("If-None-Match") == `"r1"`:
			w.WriteHeader(http.StatusNotModified)
		default:
			w.Header().Set("ETag", `"r1"`)
			_, _ = w.Write([]byte(`{"tag_name": "v0.1.17", "html_url": "https://example.com/x", "published_at": "2026-10-29T01:29:31Z", "prerelease": false}`))
		}
	}))
	defer srv.Close()
	r := &Releases{Repo: "afrase/nushi", Base: srv.URL}
	for range 2 {
		got, err := r.Latest(t.Context())
		if err != nil || got.Tag != "v0.1.17" || got.Published.Day() != 29 {
			t.Fatalf("%+v %v", got, err)
		}
	}
	want := []string{"GET /repos/afrase/nushi/releases/latest  ", `GET /repos/afrase/nushi/releases/latest "r1" `}
	if len(asked) != 2 || asked[0] != want[0] || asked[1] != want[1] {
		t.Fatalf("asked %q", asked)
	}
	status = http.StatusNotFound
	if _, err := r.Latest(t.Context()); !errors.Is(err, ErrNotFound) {
		t.Fatalf("no release: %v", err)
	}
	status = http.StatusBadGateway
	if _, err := r.Latest(t.Context()); err == nil {
		t.Fatal("a 502 isn't a release")
	}
}

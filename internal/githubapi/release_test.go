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
		if err != nil || got != "v0.1.17" {
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

// TestReleaseTags: the newest releases' tags, pre-releases among them and
// drafts not, with their own ETag beside the latest release's.
func TestReleaseTags(t *testing.T) {
	var asked []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		asked = append(asked, r.URL.RequestURI()+" "+r.Header.Get("If-None-Match"))
		switch {
		case r.URL.Path == "/repos/afrase/nushi/releases/latest":
			w.Header().Set("ETag", `"latest"`)
			_, _ = w.Write([]byte(`{"tag_name": "v0.28.0"}`))
		case r.Header.Get("If-None-Match") == `"list"`:
			w.WriteHeader(http.StatusNotModified)
		default:
			w.Header().Set("ETag", `"list"`)
			_, _ = w.Write([]byte(`[{"tag_name": "v0.29.0-beta.2", "prerelease": true}, {"tag_name": "v0.30.0", "draft": true},
				{"tag_name": "v0.28.0"}, {"tag_name": "v0.29.0-beta.1", "prerelease": true}]`))
		}
	}))
	defer srv.Close()
	r := &Releases{Repo: "afrase/nushi", Base: srv.URL}
	if _, err := r.Latest(t.Context()); err != nil {
		t.Fatal(err)
	}
	for range 2 {
		got, err := r.Tags(t.Context())
		if err != nil || len(got) != 3 || got[0] != "v0.29.0-beta.2" || got[1] != "v0.28.0" || got[2] != "v0.29.0-beta.1" {
			t.Fatalf("%q %v", got, err)
		}
	}
	want := []string{"/repos/afrase/nushi/releases/latest ", "/repos/afrase/nushi/releases?per_page=10 ", `/repos/afrase/nushi/releases?per_page=10 "list"`}
	if len(asked) != 3 || asked[0] != want[0] || asked[1] != want[1] || asked[2] != want[2] {
		t.Fatalf("asked %q", asked)
	}
}

package githubapi

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"slices"
	"strconv"
	"strings"
	"testing"
	"time"
)

// spentBody is what GitHub's API says to an address whose hour is spent,
// as its documentation gives it (docs/facts/github.md: not recorded).
const spentBody = `{"message":"API rate limit exceeded for 203.0.113.7. (But here's the good news: Authenticated requests get a higher rate limit. Check out the documentation for more details.)","documentation_url":"https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"}`

// limitedGitHub is a fake of both of GitHub's hosts: an API that refuses
// every request for its rate (a 403 with the limit's headers, reset 12
// minutes after the clock), and the repository's pages, answered by
// pages. It records what was asked of each, with any Authorization.
type limitedGitHub struct {
	asked []string
	pages http.HandlerFunc
}

var limitedNow = time.Unix(1794390421, 0)

func (g *limitedGitHub) serve(t *testing.T) *Releases {
	t.Helper()
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		g.asked = append(g.asked, "api "+r.URL.RequestURI()+r.Header.Get("Authorization"))
		w.Header().Set("X-Ratelimit-Limit", "60")
		w.Header().Set("X-Ratelimit-Remaining", "0")
		w.Header().Set("X-Ratelimit-Reset", strconv.FormatInt(limitedNow.Add(12*time.Minute).Unix(), 10))
		w.Header().Set("X-Ratelimit-Resource", "core")
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte(spentBody))
	}))
	t.Cleanup(api.Close)
	web := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		g.asked = append(g.asked, "web "+r.URL.RequestURI()+r.Header.Get("Authorization")+r.Header.Get("Cookie"))
		g.pages(w, r)
	}))
	t.Cleanup(web.Close)
	return &Releases{Repo: "afrase/nushi", Base: api.URL, Web: web.URL, now: func() time.Time { return limitedNow }}
}

// redirect answers as github.com's /releases/latest does: a 302 with no
// body and a Location (recorded 2026-11-11: the release's page).
func redirect(to string) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Location", to)
		w.WriteHeader(http.StatusFound)
	}
}

// The API refusing for its rate, the latest release is read from the
// Location of the page's redirect, which is never followed.
func TestLatestFromThePage(t *testing.T) {
	g := &limitedGitHub{}
	r := g.serve(t)
	g.pages = redirect(r.Web + "/afrase/nushi/releases/tag/v0.28.2")
	got, err := r.Latest(t.Context())
	if err != nil || got != "v0.28.2" {
		t.Fatalf("%q %v", got, err)
	}
	want := []string{"api /repos/afrase/nushi/releases/latest", "web /afrase/nushi/releases/latest"}
	if !slices.Equal(g.asked, want) {
		t.Fatalf("asked %q", g.asked)
	}
	// A repository with no release goes to its list.
	g.pages = redirect(r.Web + "/afrase/nushi/releases")
	if _, err := r.Latest(t.Context()); !errors.Is(err, ErrNotFound) {
		t.Fatalf("no release: %v", err)
	}
}

// The API refusing for its rate, the newest releases' tags are read from
// the feed as recorded, pre-releases among them.
func TestTagsFromTheFeed(t *testing.T) {
	g := &limitedGitHub{}
	r := g.serve(t)
	feed, err := os.ReadFile("testdata/releases.atom")
	if err != nil {
		t.Fatal(err)
	}
	// The recording links to github.com; the fake is elsewhere.
	feed = []byte(strings.ReplaceAll(string(feed), "https://github.com", r.Web))
	g.pages = func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/atom+xml; charset=utf-8")
		_, _ = w.Write(feed)
	}
	got, err := r.Tags(t.Context())
	want := []string{"v0.29.0-beta.2", "v0.29.0-beta.1", "v0.28.2", "v0.28.1"}
	if err != nil || !slices.Equal(got, want) {
		t.Fatalf("%q %v", got, err)
	}
	if asked := []string{"api /repos/afrase/nushi/releases?per_page=10", "web /afrase/nushi/releases.atom"}; !slices.Equal(g.asked, asked) {
		t.Fatalf("asked %q", g.asked)
	}
}

// A link in the feed that isn't a release's page of this repository on
// this host names no tag; of an entry's links the first that is one does.
func TestHostileFeed(t *testing.T) {
	feed, err := os.ReadFile("testdata/releases_hostile.atom")
	if err != nil {
		t.Fatal(err)
	}
	web := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write(feed) }))
	defer web.Close()
	// The fake stands at https://github.com itself, so that the links
	// are judged as the real ones would be.
	r := &Releases{Repo: "afrase/nushi", Transport: rewrite{to: web}}
	got, err := r.webTags(t.Context())
	if err != nil || !slices.Equal(got, []string{"v0.28.2"}) {
		t.Fatalf("%q %v", got, err)
	}
}

// rewrite sends every request to a test server, whatever host it names.
type rewrite struct{ to *httptest.Server }

func (rw rewrite) RoundTrip(req *http.Request) (*http.Response, error) {
	req = req.Clone(req.Context())
	req.URL.Host = strings.TrimPrefix(rw.to.URL, "https://")
	return rw.to.Client().Transport.RoundTrip(req)
}

// When the pages don't answer either (another host in the redirect, a
// redirect elsewhere in the site, a feed that isn't one, an error), the
// API's refusal is the error, and it says when to try again.
func TestBothRefuse(t *testing.T) {
	g := &limitedGitHub{}
	r := g.serve(t)
	const message = "GitHub is limiting requests from this network. Try again in about 12 minutes."
	for name, pages := range map[string]http.HandlerFunc{
		"another host":   redirect("https://evil.example/afrase/nushi/releases/tag/v9.9.9"),
		"another repo":   redirect("/someone/else/releases/tag/v9.9.9"),
		"a sign-in page": redirect("/login?return_to=%2Fafrase%2Fnushi%2Freleases%2Ftag%2Fv9.9.9"),
		"no location":    func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusFound) },
		"limited too":    func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusTooManyRequests) },
		"not a feed": func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte("<html><body>Sign in</body></html>"))
		},
		"a broken feed": func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte(`<feed xmlns="http://www.w3.org/2005/Atom"><entry>`))
		},
		"declared entity": func(w http.ResponseWriter, _ *http.Request) {
			_, _ = w.Write([]byte(`<!DOCTYPE feed [<!ENTITY a "aaaa">]><feed xmlns="http://www.w3.org/2005/Atom"><entry><title>&a;</title></entry></feed>`))
		},
	} {
		g.pages = pages
		_, lerr := r.Latest(t.Context())
		_, terr := r.Tags(t.Context())
		for _, err := range []error{lerr, terr} {
			// The two feeds that aren't redirects are, to Latest, a 200.
			if err == nil || err.Error() != message {
				t.Errorf("%s: %v", name, err)
			}
		}
	}
}

// What a refusal says, by what GitHub said: the limit's reset, a
// secondary limit's wait, or neither. Any other 403 or status keeps its
// plain words and asks no page.
func TestRateRefusals(t *testing.T) {
	const limiting = "GitHub is limiting requests from this network. "
	reset := strconv.FormatInt(limitedNow.Add(30*time.Second).Unix(), 10)
	for _, c := range []struct {
		status  int
		headers map[string]string
		body    string
		want    string
		pages   bool
	}{
		{403, map[string]string{"X-Ratelimit-Remaining": "0", "X-Ratelimit-Reset": reset}, "", limiting + "Try again in about a minute.", true},
		{429, map[string]string{"Retry-After": "170"}, "", limiting + "Try again in about 3 minutes.", true},
		{403, nil, `{"message":"You have exceeded a secondary rate limit."}`, limiting + "Try again later.", true},
		{429, nil, "", limiting + "Try again later.", true},
		{403, map[string]string{"X-Ratelimit-Remaining": "0", "X-Ratelimit-Reset": "99999999999"}, "", limiting + "Try again later.", true},
		{403, map[string]string{"X-Ratelimit-Remaining": "41"}, "<html>Blocked by the proxy</html>", "GitHub answered 403 Forbidden", false},
		{502, nil, "", "GitHub answered 502 Bad Gateway", false},
	} {
		pages := false
		api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			for k, v := range c.headers {
				w.Header().Set(k, v)
			}
			w.WriteHeader(c.status)
			_, _ = w.Write([]byte(c.body))
		}))
		web := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			pages = true
			w.WriteHeader(http.StatusServiceUnavailable)
		}))
		r := &Releases{Repo: "afrase/nushi", Base: api.URL, Web: web.URL, now: func() time.Time { return limitedNow }}
		_, err := r.Latest(t.Context())
		api.Close()
		web.Close()
		if err == nil || err.Error() != c.want || pages != c.pages {
			t.Errorf("%d %v: %v, pages asked %v", c.status, c.headers, err, pages)
		}
	}
	// Not found and a network's failure ask no page either.
	web := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { t.Error("the page was asked") }))
	defer web.Close()
	api := httptest.NewServer(http.NotFoundHandler())
	r := &Releases{Repo: "afrase/nushi", Base: api.URL, Web: web.URL}
	if _, err := r.Latest(t.Context()); !errors.Is(err, ErrNotFound) {
		t.Fatalf("404: %v", err)
	}
	api.Close()
	if _, err := r.Latest(t.Context()); err == nil || networkLimited(err) {
		t.Fatalf("unreachable: %v", err)
	}
}

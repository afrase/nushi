package jira

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/afrase/nushi/internal/jiracloud"
	"github.com/afrase/nushi/internal/model"
)

func TestParseLink(t *testing.T) {
	for _, c := range []struct{ text, origin, path, key string }{
		{"https://acme.atlassian.net/browse/ABC-123", "https://acme.atlassian.net", "/browse/ABC-123", "ABC-123"},
		{"https://ACME.atlassian.net:443/browse/abc-123?focusedCommentId=1#c", "https://acme.atlassian.net", "/browse/abc-123", "ABC-123"},
		{"https://acme.atlassian.net/jira/software/projects/ABC/boards/1?selectedIssue=ABC-7", "https://acme.atlassian.net", "/jira/software/projects/ABC/boards/1", "ABC-7"},
		{"https://acme.atlassian.net/jira/software/c/projects/ABC/issues/ABC-9?jql=x", "https://acme.atlassian.net", "/jira/software/c/projects/ABC/issues/ABC-9", "ABC-9"},
		{"https://jira.corp.example:8443/jira/browse/OPS-1/", "https://jira.corp.example:8443", "/jira/browse/OPS-1/", "OPS-1"},
		{"http://jira.local/browse/X_Y-2", "http://jira.local", "/browse/X_Y-2", "X_Y-2"},
	} {
		origin, path, key, ok := ParseLink(c.text)
		if !ok || origin != c.origin || path != c.path || key != c.key {
			t.Errorf("ParseLink(%q) = %q, %q, %q, %v", c.text, origin, path, key, ok)
		}
	}
	for _, text := range []string{
		"ABC-123", "fix the login", "https://acme.atlassian.net/browse/", "https://acme.atlassian.net/browse/ABC",
		"https://acme.atlassian.net/jira/software/projects/ABC/boards/1", "ftp://acme.atlassian.net/browse/ABC-1",
		"https:///browse/ABC-1", "https://acme.atlassian.net/browse/ABC-0", "https://acme.atlassian.net/x?selectedIssue=a b",
	} {
		if _, _, key, ok := ParseLink(text); ok {
			t.Errorf("ParseLink(%q) took %q", text, key)
		}
	}
}

func TestMatchSites(t *testing.T) {
	sites := []model.JiraSite{
		{URL: "https://acme.atlassian.net"},
		{URL: "https://other.atlassian.net/"},
		{URL: "https://jira.corp.example/jira"},
		{URL: "https://jira.corp.example/jira2"},
		{URL: "https://jira.corp.example/"},
	}
	ids := func(ss []model.JiraSite) []string {
		var out []string
		for _, s := range ss {
			out = append(out, s.URL)
		}
		return out
	}
	for _, c := range []struct {
		link string
		want []string
	}{
		{"https://acme.atlassian.net/browse/A-1", []string{"https://acme.atlassian.net"}},
		{"https://acme.atlassian.net/browse/A-1?x=1", []string{"https://acme.atlassian.net"}},
		{"https://evil.example/browse/A-1", nil},
		{"https://acme.atlassian.net.evil.example/browse/A-1", nil},
		{"http://acme.atlassian.net/browse/A-1", nil}, // another origin
		// A path prefix: the site at /jira, and the one at the root.
		{"https://jira.corp.example/jira/browse/OPS-1", []string{"https://jira.corp.example/jira", "https://jira.corp.example/"}},
		{"https://jira.corp.example/jira2/browse/OPS-1", []string{"https://jira.corp.example/jira2", "https://jira.corp.example/"}},
		{"https://jira.corp.example/browse/OPS-1", []string{"https://jira.corp.example/"}},
	} {
		origin, path, _, ok := ParseLink(c.link)
		if !ok {
			t.Fatalf("%q isn't a link", c.link)
		}
		if got := ids(MatchSites(sites, origin, path)); !slices.Equal(got, c.want) {
			t.Errorf("%s: matched %q, want %q", c.link, got, c.want)
		}
	}
}

func TestTextJQL(t *testing.T) {
	for text, want := range map[string]string{
		"login":                        `text ~ "login*" ORDER BY updated DESC`,
		` Fix  the "login" page\ `:     `text ~ "Fix*" AND text ~ "the*" AND text ~ "login*" AND text ~ "page*" ORDER BY updated DESC`,
		`x" OR project = SECRET OR "y`: `text ~ "x*" AND text ~ "OR*" AND text ~ "project*" AND text ~ "SECRET*" AND text ~ "OR*" AND text ~ "y*" ORDER BY updated DESC`,
		"ünïcode ελληνικά":             `text ~ "ünïcode*" AND text ~ "ελληνικά*" ORDER BY updated DESC`,
		"*?~()":                        recentJQL,
		"a b c d e f g h":              `text ~ "a*" AND text ~ "b*" AND text ~ "c*" AND text ~ "d*" AND text ~ "e*" AND text ~ "f*" ORDER BY updated DESC`,
	} {
		if got := TextJQL(text); got != want {
			t.Errorf("TextJQL(%q) = %s, want %s", text, got, want)
		}
	}
}

// fakeJira is a Jira site's /search/jql: the issues it answers, by the JQL
// asked (any other is Jira's 400).
type fakeJira struct {
	srv    *httptest.Server
	issues map[string][]string // by JQL: key and summary, "A-1 Fix it"
}

func newFakeJira(t *testing.T, issues map[string][]string) *fakeJira {
	t.Helper()
	f := &fakeJira{issues: issues}
	f.srv = httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			JQL string `json:"jql"`
		}
		if r.URL.Path != "/rest/api/3/search/jql" || json.NewDecoder(r.Body).Decode(&req) != nil {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		list, ok := f.issues[req.JQL]
		if !ok {
			w.WriteHeader(http.StatusBadRequest)
			_, _ = w.Write([]byte(`{"errorMessages":["An issue with key 'ZZ-1' does not exist for field 'key'."]}`))
			return
		}
		var out []map[string]any
		for _, is := range list {
			key, summary, _ := strings.Cut(is, " ")
			out = append(out, map[string]any{"key": key, "fields": map[string]any{
				"summary": summary, "status": map[string]any{"name": "To Do", "statusCategory": map[string]any{"key": "new"}},
			}})
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"issues": out})
	}))
	t.Cleanup(f.srv.Close)
	return f
}

// findService is the service with two sites, each a fake Jira.
func findService(t *testing.T, a, b *fakeJira) *Service {
	t.Helper()
	s, _, _ := newService(t)
	fakes := map[string]*fakeJira{a.srv.URL: a, b.srv.URL: b}
	open := func(site string) Client {
		f := fakes[site]
		return jiracloud.New(f.srv.URL, "", "me@e.com", "good", f.srv.Client().Transport)
	}
	s.sites.Connect = func(_ context.Context, site, _, _ string) (Client, model.JiraSite, error) {
		return open(site), model.JiraSite{URL: site}, nil
	}
	for _, f := range []*fakeJira{a, b} {
		if _, err := s.AddSite(t.Context(), f.srv.URL, "me@e.com", "good", time.Time{}); err != nil {
			t.Fatal(err)
		}
	}
	return s
}

// found says what f found: each issue's site (by name), key, status and
// branch, or the unknown site.
func found(f Finding, names map[string]string) string {
	var out []string
	for _, x := range f.Issues {
		out = append(out, fmt.Sprintf("%s %s %s %s", names[x.Site], x.Issue.Key, x.Issue.Status, x.Branch))
	}
	return strings.Join(out, "|") + f.UnknownSite
}

func TestFind(t *testing.T) {
	a := newFakeJira(t, map[string][]string{
		`text ~ "login*" ORDER BY updated DESC`: {"A-2 Fix the login", "A-1 Log in"},
		"key = A-1":                             {"A-1 Log in"},
		recentJQL:                               {"A-3 Looked at"},
	})
	b := newFakeJira(t, map[string][]string{
		`text ~ "login*" ORDER BY updated DESC`: {"B-9 Login page"},
		"key = A-1":                             {"A-1 Another site's A-1"},
		recentJQL:                               {},
	})
	s := findService(t, a, b)
	idA, idB := strings.TrimPrefix(a.srv.URL, "https://"), strings.TrimPrefix(b.srv.URL, "https://")
	names := map[string]string{idA: "a", idB: "b"}
	for _, c := range []struct{ text, site, want string }{
		// Words: every site, each in its own order.
		{" login ", "", "a A-2 To Do A-2-fix-the-login|a A-1 To Do A-1-log-in|b B-9 To Do B-9-login-page"},
		// A key: on the site used last, else the first.
		{"a-1", idB, "b A-1 To Do A-1-another-site-s-a-1"},
		{"A-1", "", "a A-1 To Do A-1-log-in"},
		{"A-1", "gone.atlassian.net", "a A-1 To Do A-1-log-in"},
		// A link: its site by its address, query string and all.
		{b.srv.URL + "/browse/A-1?focusedCommentId=3", "", "b A-1 To Do A-1-another-site-s-a-1"},
		{"https://acme.atlassian.net/browse/A-1", "", "https://acme.atlassian.net"},
		// Nothing typed: the issues looked at last.
		{"", "", "a A-3 To Do A-3-looked-at"},
	} {
		f, err := s.Find(t.Context(), c.text, c.site)
		if err != nil {
			t.Fatalf("%q: %v", c.text, err)
		}
		if got := found(f, names); got != c.want {
			t.Errorf("%q: %s\nwant %s", c.text, got, c.want)
		}
	}

	// A key the site hasn't: Jira's own words, without the site.
	if _, err := s.Find(t.Context(), "ZZ-1", idA); err == nil || !strings.HasPrefix(err.Error(), "An issue with key") {
		t.Errorf("a missing key: %v", err)
	}
	// A site failing: the others' issues still come.
	b.issues = nil
	if got := found(s.mustFind(t, "login"), names); got != "a A-2 To Do A-2-fix-the-login|a A-1 To Do A-1-log-in" {
		t.Errorf("one site failing: %s", got)
	}
	a.issues = nil
	if _, err := s.Find(t.Context(), "login", ""); err == nil || !strings.Contains(err.Error(), idA) {
		t.Errorf("every site failing: %v", err)
	}
}

func (s *Service) mustFind(t *testing.T, text string) Finding {
	t.Helper()
	f, err := s.Find(t.Context(), text, "")
	if err != nil {
		t.Fatal(err)
	}
	return f
}

func TestFindNoSite(t *testing.T) {
	s, _, _ := newService(t)
	if _, err := s.Find(t.Context(), "login", ""); err == nil {
		t.Error("found with no site")
	}
}

func TestBranch(t *testing.T) {
	for _, c := range []struct{ key, summary, want string }{
		{"SCRUM-5", "ADF sample: what Jira's editor makes", "SCRUM-5-adf-sample-what-jira-s-editor-makes"},
		{"A-1", "  Ünïcode — and *marks*!  ", "A-1-n-code-and-marks"},
		{"A-1", "???", "A-1"},
		{"A-1", strings.Repeat("long ", 30), "A-1-long-long-long-long-long-long-long-long"},
	} {
		got := Branch(c.key, c.summary)
		if got != c.want {
			t.Errorf("Branch(%q, %q) = %q, want %q", c.key, c.summary, got, c.want)
		}
	}
}

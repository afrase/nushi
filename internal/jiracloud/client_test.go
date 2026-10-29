package jiracloud

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"
)

// fake is a scripted Jira: routes by method and path (the gateway's
// prefix taken off), each answered from a handler or a testdata file. It
// checks the Basic auth of the token it was given.
type fake struct {
	t      *testing.T
	srv    *httptest.Server
	token  string
	scoped bool // the token works only through the gateway
	mu     sync.Mutex
	routes map[string]http.HandlerFunc
	calls  []string // method and path of every request, the gateway's marked
}

func newFake(t *testing.T) *fake {
	t.Helper()
	f := &fake{t: t, token: "tok", routes: map[string]http.HandlerFunc{}}
	f.srv = httptest.NewTLSServer(http.HandlerFunc(f.serve))
	t.Cleanup(f.srv.Close)
	old := Gateway
	Gateway = f.srv.URL + "/ex/jira/"
	t.Cleanup(func() { Gateway = old })
	return f
}

func (f *fake) serve(w http.ResponseWriter, r *http.Request) {
	path, gateway := r.URL.Path, false
	if rest, ok := strings.CutPrefix(path, "/ex/jira/cloud-1"); ok {
		path, gateway = rest, true
	}
	f.mu.Lock()
	f.calls = append(f.calls, fmt.Sprintf("%s %s gateway=%v", r.Method, path, gateway))
	h := f.routes[r.Method+" "+path]
	f.mu.Unlock()
	want := "Basic " + base64.StdEncoding.EncodeToString([]byte("me@example.com:"+f.token))
	if path != "/_edge/tenant_info" && (r.Header.Get("Authorization") != want || f.scoped != gateway) {
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte("Client must be authenticated to access this resource."))
		return
	}
	if h == nil {
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(`{"errorMessages":["no route"]}`))
		return
	}
	h(w, r)
}

// file answers with a testdata file.
func (f *fake) file(route, name string) {
	b, err := os.ReadFile("testdata/" + name)
	if err != nil {
		f.t.Fatal(err)
	}
	f.routes[route] = func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write(b) }
}

func (f *fake) client() *Client {
	c := New(f.srv.URL, "", "me@example.com", f.token, f.srv.Client().Transport)
	c.wait = func(context.Context, time.Duration) error { return nil }
	return c
}

func TestConnectClassic(t *testing.T) {
	f := newFake(t)
	f.file("GET /rest/api/3/myself", "myself.json")
	c, _, err := Connect(t.Context(), f.srv.URL+"/", "me@example.com", "tok", f.srv.Client().Transport)
	if err != nil {
		t.Fatal(err)
	}
	if c.CloudID != "" {
		t.Errorf("a classic token went through the gateway: %q", c.CloudID)
	}
	u, err := c.Myself(t.Context())
	if err != nil || u.Name != "Test User" || u.AccountID != "557058:00000000-0000-0000-0000-000000000001" {
		t.Errorf("myself: %+v, %v", u, err)
	}
}

func TestConnectScoped(t *testing.T) {
	f := newFake(t)
	f.scoped = true
	f.file("GET /rest/api/3/myself", "myself.json")
	f.routes["GET /_edge/tenant_info"] = func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte(`{"cloudId":"cloud-1"}`)) }
	f.file("POST /rest/api/3/search/jql", "search.json")
	c, _, err := Connect(t.Context(), f.srv.URL, "me@example.com", "tok", f.srv.Client().Transport)
	if err != nil {
		t.Fatal(err)
	}
	if c.CloudID != "cloud-1" {
		t.Fatalf("cloud id %q", c.CloudID)
	}
	if _, err := c.Search(t.Context(), "project = SCRUM", 1); err != nil {
		t.Fatal(err)
	}
	if last := f.calls[len(f.calls)-1]; last != "POST /rest/api/3/search/jql gateway=true" {
		t.Errorf("searched as %s", last)
	}
}

func TestConnectRefused(t *testing.T) {
	f := newFake(t)
	f.file("GET /rest/api/3/myself", "myself.json")
	f.routes["GET /_edge/tenant_info"] = func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte(`{"cloudId":"cloud-1"}`)) }
	if _, _, err := Connect(t.Context(), f.srv.URL, "me@example.com", "wrong", f.srv.Client().Transport); !errors.Is(err, ErrUnauthorized) {
		t.Errorf("a wrong token: %v", err)
	}
	for _, site := range []string{"example.atlassian.net", "http://example.atlassian.net", "https://e.atlassian.net/jira", "https://"} {
		if _, _, err := Connect(t.Context(), site, "me@example.com", "tok", f.srv.Client().Transport); err == nil || errors.Is(err, ErrUnauthorized) {
			t.Errorf("%q: %v", site, err)
		}
	}
}

func TestSearchPages(t *testing.T) {
	f := newFake(t)
	var tokens []string
	pages := map[string]string{ // token asked for -> the page's issues and next token
		"":   `{"issues":[{"key":"A-1","fields":{"summary":"one","status":{"name":"To Do","statusCategory":{"key":"new"}},"updated":"2026-10-25T21:15:39.083+0900"}}],"nextPageToken":"t1"}`,
		"t1": `{"issues":[{"key":"A-2","fields":{"summary":"two","assignee":{"accountId":"712020:ann","displayName":"Ann Lee","avatarUrls":{"24x24":"https://secure.gravatar.com/avatar/x"}},"priority":{"name":"High"}}}],"nextPageToken":"t2"}`,
		"t2": `{"issues":[{"key":"A-3","fields":{"summary":"three","assignee":null}}],"nextPageToken":"t1"}`, // goes round
	}
	f.routes["POST /rest/api/3/search/jql"] = func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			JQL           string   `json:"jql"`
			Fields        []string `json:"fields"`
			NextPageToken string   `json:"nextPageToken"`
			MaxResults    int      `json:"maxResults"`
		}
		_ = json.NewDecoder(r.Body).Decode(&req)
		tokens = append(tokens, req.NextPageToken)
		// Only what a row shows; the assignee among them.
		if strings.Join(req.Fields, ",") != "summary,status,priority,assignee" {
			t.Errorf("fields asked for: %q", req.Fields)
		}
		_, _ = w.Write([]byte(pages[req.NextPageToken]))
	}
	c := f.client()
	got, err := c.Search(t.Context(), "assignee = currentUser()", 50)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 3 || got[0].Key != "A-1" || got[1].Priority != "High" || got[0].StatusCategory != "new" {
		t.Errorf("got %+v", got)
	}
	if got[1].Assignee != "Ann Lee" || got[1].AssigneeID != "712020:ann" {
		t.Errorf("the assignee: %q %q", got[1].Assignee, got[1].AssigneeID)
	}
	if got[0].Assignee != "" || got[0].AssigneeID != "" || got[2].AssigneeID != "" {
		t.Errorf("unassigned issues have an assignee: %+v", got)
	}
	if strings.Join(tokens, ",") != ",t1,t2" {
		t.Errorf("asked for pages %q: a token seen before must end it", tokens)
	}
	if got, _ := c.Search(t.Context(), "x", 2); len(got) != 2 {
		t.Errorf("a limit of 2 gave %d", len(got))
	}
}

func TestRateLimited(t *testing.T) {
	f := newFake(t)
	n := 0
	f.routes["GET /rest/api/3/myself"] = func(w http.ResponseWriter, _ *http.Request) {
		n++
		if n < 3 {
			w.Header().Set("Retry-After", "2")
			w.WriteHeader(http.StatusTooManyRequests)
			return
		}
		_, _ = w.Write([]byte(`{"displayName":"Test User"}`))
	}
	c := f.client()
	var waited []time.Duration
	c.wait = func(_ context.Context, d time.Duration) error { waited = append(waited, d); return nil }
	if u, err := c.Myself(t.Context()); err != nil || u.Name != "Test User" {
		t.Fatalf("after two 429s: %+v, %v", u, err)
	}
	if len(waited) != 2 || waited[0] < 1400*time.Millisecond || waited[0] > 2600*time.Millisecond {
		t.Errorf("waited %v; Retry-After 2 with jitter", waited)
	}
	n = -10 // more refusals than retries
	var limited *RateLimitedError
	if _, err := c.Myself(t.Context()); !errors.As(err, &limited) {
		t.Errorf("past the retries: %v", err)
	}
	f.routes["GET /rest/api/3/myself"] = func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Retry-After", "3600")
		w.WriteHeader(http.StatusTooManyRequests)
	}
	waited = nil
	if _, err := c.Myself(t.Context()); !errors.As(err, &limited) || len(waited) != 0 {
		t.Errorf("an hour's wait isn't waited: %v after %v", err, waited)
	}
}

// A write is tried again after a 429 (Jira didn't do it), not after a
// 503, which may come after Jira did.
func TestWriteRetries(t *testing.T) {
	f := newFake(t)
	var answers []int
	tries := 0
	f.routes["POST /rest/api/3/issue/A-1/comment"] = func(w http.ResponseWriter, _ *http.Request) {
		tries++
		if len(answers) > 0 {
			w.WriteHeader(answers[0])
			answers = answers[1:]
			return
		}
		_, _ = w.Write([]byte(`{"id":"1","body":{"type":"doc","version":1,"content":[]}}`))
	}
	c := f.client()
	answers = []int{http.StatusServiceUnavailable}
	if _, err := c.AddComment(t.Context(), "A-1", "hi"); err == nil || tries != 1 {
		t.Fatalf("a 503 on a write: %v, %v", err, f.calls)
	}
	answers = []int{http.StatusTooManyRequests}
	if _, err := c.AddComment(t.Context(), "A-1", "hi"); err != nil || tries != 3 {
		t.Fatalf("a 429 on a write: %v, %v", err, f.calls)
	}
}

func TestErrors(t *testing.T) {
	f := newFake(t)
	f.routes["POST /rest/api/3/search/jql"] = func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"errorMessages":["Unbounded JQL queries are not allowed here."],"errors":{}}`))
	}
	c := f.client()
	if _, err := c.Search(t.Context(), "order by key", 10); err == nil || err.Error() != "Unbounded JQL queries are not allowed here." {
		t.Errorf("got %v", err)
	}
	if _, _, err := c.ActiveSprint(t.Context(), 9); !errors.Is(err, ErrNotFound) {
		t.Errorf("a missing board: %v", err)
	}
}

func TestBoardsSprintJQL(t *testing.T) {
	f := newFake(t)
	f.file("GET /rest/agile/1.0/board", "boards.json")
	f.file("GET /rest/agile/1.0/board/1/sprint", "sprints.json")
	f.file("GET /rest/api/3/jql/autocompletedata", "acdata.json")
	f.file("GET /rest/api/3/jql/autocompletedata/suggestions", "acsugg.json")
	c := f.client()
	boards, err := c.Boards(t.Context())
	if err != nil || len(boards) != 1 || boards[0].ID != 1 || boards[0].Project != "SCRUM" || boards[0].Name != "SCRUM board" {
		t.Errorf("boards %+v, %v", boards, err)
	}
	id, name, err := c.ActiveSprint(t.Context(), 1)
	if err != nil || id != 2 || name != "SCRUM Sprint 0" {
		t.Errorf("sprint %d %q, %v", id, name, err)
	}
	jql, err := c.JQL(t.Context())
	if err != nil || len(jql.Fields) == 0 || len(jql.Words) == 0 || len(jql.Functions) == 0 {
		t.Errorf("jql %+v, %v", jql, err)
	}
	sugg, err := c.Suggestions(t.Context(), "status", "In")
	if err != nil || len(sugg) != 2 || sugg[0].ID != `"In Progress"` || sugg[0].Name != "In Progress" {
		t.Errorf("suggestions %+v, %v", sugg, err)
	}
}

// The log has the request's path template, its status and time, never
// the query, the JQL, an issue's key or the token.
func TestLogging(t *testing.T) {
	f := newFake(t)
	f.file("POST /rest/api/3/search/jql", "search.json")
	f.file("GET /rest/agile/1.0/board/1/sprint", "sprints.json")
	var buf bytes.Buffer
	c := f.client()
	c.log = slog.New(slog.NewTextHandler(&buf, &slog.HandlerOptions{Level: slog.LevelDebug}))
	_, _ = c.Search(t.Context(), "summary ~ secretword", 5)
	if _, _, err := c.ActiveSprint(t.Context(), 1); err != nil {
		t.Fatal(err)
	}
	log := buf.String()
	for _, s := range []string{"secretword", "tok", "SCRUM-1", "Task 1", "state=active", "Basic"} {
		if strings.Contains(log, s) {
			t.Errorf("the log has %q:\n%s", s, log)
		}
	}
	if !strings.Contains(log, "path=/rest/agile/1.0/board/{}/sprint status=200") {
		t.Errorf("no request line:\n%s", log)
	}
}

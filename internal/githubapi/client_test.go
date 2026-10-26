package githubapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// fake is a scripted GitHub Enterprise server (so its host is the test
// server's): REST routes by method and path under /api/v3, GraphQL by
// operation name, each answered by a handler or a testdata file. It
// checks the token.
type fake struct {
	t      *testing.T
	srv    *httptest.Server
	mu     sync.Mutex
	routes map[string]http.HandlerFunc
	calls  []string
}

const token = "ghp_test0123456789"

func newFake(t *testing.T) *fake {
	t.Helper()
	f := &fake{t: t, routes: map[string]http.HandlerFunc{}}
	f.srv = httptest.NewTLSServer(http.HandlerFunc(f.serve))
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fake) serve(w http.ResponseWriter, r *http.Request) {
	route := r.Method + " " + strings.TrimPrefix(r.URL.Path, "/api/v3")
	if r.URL.Path == "/api/graphql" {
		body, _ := io.ReadAll(r.Body)
		r.Body = io.NopCloser(bytes.NewReader(body))
		var q struct {
			Op string `json:"operationName"`
		}
		_ = json.Unmarshal(body, &q)
		route = "graphql " + q.Op
	}
	f.mu.Lock()
	f.calls = append(f.calls, route)
	h := f.routes[route]
	f.mu.Unlock()
	if r.Header.Get("Authorization") != "Bearer "+token || r.Header.Get("X-Github-Api-Version") != Version {
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"message":"Bad credentials"}`))
		return
	}
	if h == nil {
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(`{"message":"Not Found"}`))
		return
	}
	h(w, r)
}

func (f *fake) route(route string, h http.HandlerFunc) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.routes[route] = h
}

func (f *fake) count(route string) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	n := 0
	for _, c := range f.calls {
		if c == route {
			n++
		}
	}
	return n
}

func (f *fake) client() *Client {
	c := New(strings.TrimPrefix(f.srv.URL, "https://"), token, f.srv.Client().Transport)
	c.lim.sleep = func(context.Context, time.Duration) error { return nil }
	return c
}

func limited(w http.ResponseWriter, resource string, remaining int, reset time.Time) {
	w.Header().Set("X-Ratelimit-Resource", resource)
	w.Header().Set("X-Ratelimit-Limit", "5000")
	w.Header().Set("X-Ratelimit-Remaining", strconv.Itoa(remaining))
	w.Header().Set("X-Ratelimit-Reset", strconv.FormatInt(reset.Unix(), 10))
}

func TestEndpoints(t *testing.T) {
	for host, want := range map[string]string{
		"github.com":         "https://api.github.com https://api.github.com/graphql https://github.com",
		"octo.ghe.com":       "https://api.octo.ghe.com https://api.octo.ghe.com/graphql https://octo.ghe.com",
		"git.example.com":    "https://git.example.com/api/v3 https://git.example.com/api/graphql https://git.example.com",
		"git.example.com:84": "https://git.example.com:84/api/v3 https://git.example.com:84/api/graphql https://git.example.com:84",
	} {
		rest, gql, web := Endpoints(host)
		if got := rest + " " + gql + " " + web; got != want {
			t.Errorf("%s: %s, want %s", host, got, want)
		}
	}
}

func TestViewerAndLog(t *testing.T) {
	var logged bytes.Buffer
	old := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(&logged, &slog.HandlerOptions{Level: slog.LevelDebug})))
	t.Cleanup(func() { slog.SetDefault(old) })
	f := newFake(t)
	f.route("GET /user", func(w http.ResponseWriter, _ *http.Request) {
		limited(w, "core", 4990, time.Now().Add(time.Hour))
		w.Header().Set("X-Oauth-Scopes", "repo, read:org, gist")
		_, _ = w.Write([]byte(`{"login":"octo","name":"Octo Cat"}`))
	})
	c := f.client()
	u, err := c.Viewer(t.Context())
	if err != nil {
		t.Fatal(err)
	}
	if u.Login != "octo" || strings.Join(u.Scopes, " ") != "repo read:org gist" {
		t.Fatalf("%+v", u)
	}
	if b := c.Budget(); len(b) != 1 || b[0].Name != "core" || b[0].Remaining != 4990 {
		t.Fatalf("budget %+v", b)
	}
	log := logged.String()
	if !strings.Contains(log, "what=/user status=200") || !strings.Contains(log, "left=4990") || strings.Contains(log, token) {
		t.Fatalf("log: %s", log)
	}
	bad := New(c.Host, "ghp_wrong", f.srv.Client().Transport)
	if _, err := bad.Viewer(t.Context()); !errors.Is(err, ErrUnauthorized) {
		t.Fatalf("a wrong token: %v", err)
	}
}

func TestETag(t *testing.T) {
	f := newFake(t)
	f.route("GET /user", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("If-None-Match") == `"v1"` {
			w.WriteHeader(http.StatusNotModified)
			return
		}
		w.Header().Set("ETag", `"v1"`)
		_, _ = w.Write([]byte(`{"login":"octo"}`))
	})
	c := f.client()
	for range 2 {
		if u, err := c.Viewer(t.Context()); err != nil || u.Login != "octo" {
			t.Fatalf("%+v %v", u, err)
		}
	}
	if f.count("GET /user") != 2 {
		t.Fatal(f.calls)
	}
}

func TestPrimaryLimitShutsTheBucket(t *testing.T) {
	f := newFake(t)
	reset := time.Now().Add(20 * time.Minute)
	f.route("GET /user", func(w http.ResponseWriter, _ *http.Request) {
		limited(w, "core", 0, reset)
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte(`{"message":"API rate limit exceeded for user ID 1."}`))
	})
	c := f.client()
	_, err := c.Viewer(t.Context())
	var rl *RateLimitedError
	if !errors.As(err, &rl) || rl.Bucket != "core" || rl.Until.Unix() != reset.Unix() || rl.Low {
		t.Fatalf("%v", err)
	}
	if _, err := c.Viewer(t.Context()); !errors.As(err, &rl) || f.count("GET /user") != 1 {
		t.Fatalf("the shut bucket asked again: %v %v", err, f.calls)
	}
}

func TestSecondaryLimit(t *testing.T) {
	f := newFake(t)
	f.route("GET /user", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Retry-After", "30")
		w.WriteHeader(http.StatusTooManyRequests)
		_, _ = w.Write([]byte(`{"message":"You have exceeded a secondary rate limit."}`))
	})
	c := f.client()
	start := time.Now()
	_, err := c.Viewer(t.Context())
	var rl *RateLimitedError
	if !errors.As(err, &rl) || rl.Until.Before(start.Add(29*time.Second)) || rl.Until.After(start.Add(31*time.Second)) {
		t.Fatalf("%v", err)
	}
}

func TestPollsKeepTheFloor(t *testing.T) {
	f := newFake(t)
	f.route("GET /user", func(w http.ResponseWriter, _ *http.Request) {
		limited(w, "core", floor-1, time.Now().Add(time.Hour))
		_, _ = w.Write([]byte(`{"login":"octo"}`))
	})
	c := f.client()
	if _, err := c.Viewer(t.Context()); err != nil {
		t.Fatal(err)
	}
	_, err := c.Viewer(Poll(t.Context()))
	var rl *RateLimitedError
	if !errors.As(err, &rl) || !rl.Low || rl.Left != floor-1 {
		t.Fatalf("a poll went: %v", err)
	}
	if _, err := c.Viewer(t.Context()); err != nil || f.count("GET /user") != 2 {
		t.Fatalf("the user's own request: %v %v", err, f.calls)
	}
}

func TestAFewAtOnce(t *testing.T) {
	f := newFake(t)
	var now, most atomic.Int32
	release := make(chan struct{})
	f.route("GET /user", func(w http.ResponseWriter, _ *http.Request) {
		n := now.Add(1)
		for m := most.Load(); n > m; m = most.Load() {
			if most.CompareAndSwap(m, n) {
				break
			}
		}
		<-release
		now.Add(-1)
		_, _ = w.Write([]byte(`{"login":"octo"}`))
	})
	c := f.client()
	var wg sync.WaitGroup
	for range 3 * parallel {
		wg.Go(func() { _, _ = c.Viewer(t.Context()) })
	}
	time.Sleep(200 * time.Millisecond)
	close(release)
	wg.Wait()
	if most.Load() != parallel {
		t.Fatalf("%d at once", most.Load())
	}
}

func TestGraphQL(t *testing.T) {
	f := newFake(t)
	f.route("graphql Two", func(w http.ResponseWriter, r *http.Request) {
		var q struct{ Variables map[string]int }
		if err := json.NewDecoder(r.Body).Decode(&q); err != nil || q.Variables["n"] != 1 {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		_, _ = w.Write([]byte(`{"data":{"a":{"n":1},"b":null},"errors":[{"type":"NOT_FOUND","path":["b"],"message":"Could not resolve"}]}`))
	})
	f.route("graphql None", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"errors":[{"message":"Field 'x' doesn't exist"}]}`))
	})
	f.route("graphql Spent", func(w http.ResponseWriter, _ *http.Request) {
		limited(w, "graphql", 0, time.Now().Add(time.Hour))
		_, _ = w.Write([]byte(`{"errors":[{"type":"RATE_LIMITED","message":"API rate limit exceeded"}]}`))
	})
	c := f.client()
	var out struct{ A *struct{ N int } }
	partial, err := c.graphql(t.Context(), "query Two($n: Int!) { a(n: $n) { n } b { n } }", map[string]any{"n": 1}, &out)
	if err != nil || out.A == nil || out.A.N != 1 || len(partial) != 1 || partial[0].Type != "NOT_FOUND" {
		t.Fatalf("%+v %v %v", out, partial, err)
	}
	if _, err := c.graphql(t.Context(), "query None { x }", nil, &out); err == nil || !strings.Contains(err.Error(), "doesn't exist") {
		t.Fatalf("%v", err)
	}
	var rl *RateLimitedError
	if _, err := c.graphql(t.Context(), "query Spent { x }", nil, &out); !errors.As(err, &rl) || rl.Bucket != "graphql" {
		t.Fatalf("%v", err)
	}
	if _, err := c.graphql(t.Context(), "query Two { a { n } }", map[string]any{"n": 1}, &out); !errors.As(err, &rl) || f.count("graphql Two") != 1 {
		t.Fatalf("the shut bucket asked again: %v", err)
	}
	if _, err := c.graphql(t.Context(), "{ a }", nil, &out); err == nil {
		t.Fatal("an unnamed operation")
	}
}

func TestWritesWaitTheirTurn(t *testing.T) {
	f := newFake(t)
	f.route("graphql Write", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte(`{"data":{"x":1}}`)) })
	c := f.client()
	var waited []time.Duration
	c.lim.sleep = func(_ context.Context, d time.Duration) error {
		waited = append(waited, d)
		return nil
	}
	for range 2 {
		if _, err := c.graphql(t.Context(), "mutation Write { x }", nil, new(any)); err != nil {
			t.Fatal(err)
		}
	}
	if len(waited) != 1 || waited[0] <= writeGap/2 || waited[0] > writeGap {
		t.Fatalf("waited %v", waited)
	}
}

func TestTokenKind(t *testing.T) {
	for tok, want := range map[string]string{"ghp_x": "classic", "github_pat_x": "fine-grained", "gho_x": "oauth", "ghu_x": "app", "x": ""} {
		if got := TokenKind(tok); got != want {
			t.Errorf("%s: %q", tok, got)
		}
	}
}

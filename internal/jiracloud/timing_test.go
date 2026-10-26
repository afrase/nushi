package jiracloud

import (
	"cmp"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"sync"
	"testing"
	"time"
)

// slowFake is issueFake with each route taking what it took a real site
// to answer (scaled by NUSHI_JIRA_TIMING, 0.1 when unset), and a search
// of 100 issues a page.
func slowFake(t *testing.T) (*fake, time.Duration, *inflight) {
	t.Helper()
	scale := 0.1
	if v := os.Getenv("NUSHI_JIRA_TIMING"); v != "" {
		_, _ = fmt.Sscan(v, &scale)
	}
	ms := func(n int) time.Duration { return time.Duration(float64(n)*scale) * time.Millisecond }
	f := issueFake(t)
	f.file("GET /rest/agile/1.0/board/7/sprint", "sprints.json")
	var page strings.Builder
	page.WriteString(`{"issues":[`)
	for i := range 100 {
		if i > 0 {
			page.WriteString(",")
		}
		fmt.Fprintf(&page, `{"key":"A-%d","fields":{"summary":"issue %d","status":{"name":"To Do","statusCategory":{"key":"new"}},"updated":"2026-10-25T21:15:39.083+0900"}}`, i+1, i)
	}
	page.WriteString(`],"nextPageToken":"next"}`)
	f.routes["POST /rest/api/3/search/jql"] = func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			NextPageToken string `json:"nextPageToken"`
		}
		_ = json.NewDecoder(r.Body).Decode(&req)
		body := page.String()
		if req.NextPageToken != "" {
			body = strings.Replace(body, `"next"`, `""`, 1)
		}
		_, _ = w.Write([]byte(body))
	}
	// What the real calls took: the test site answers a trivial call in
	// about 250 ms; a work site's field list is large.
	slow := map[string]int{
		"GET /rest/api/3/field":                     900,
		"GET /rest/api/3/issue/SCRUM-5":             500,
		"GET /rest/api/3/issue/SCRUM-5/comment":     400,
		"GET /rest/api/3/issue/SCRUM-5/remotelink":  300,
		"GET /rest/api/3/issue/SCRUM-5/transitions": 400,
		"GET /rest/agile/1.0/board/7/sprint":        350,
		"POST /rest/api/3/search/jql":               600,
	}
	in := &inflight{}
	for route, d := range slow {
		h := f.routes[route]
		f.routes[route] = func(w http.ResponseWriter, r *http.Request) {
			in.add(1)
			defer in.add(-1)
			time.Sleep(ms(d))
			h(w, r)
		}
	}
	return f, ms(1000), in
}

// inflight counts the requests being answered, and the most at once.
type inflight struct {
	mu       sync.Mutex
	now, max int
}

func (n *inflight) add(d int) {
	n.mu.Lock()
	defer n.mu.Unlock()
	n.now += d
	n.max = max(n.max, n.now)
}

func (n *inflight) reset() int {
	n.mu.Lock()
	defer n.mu.Unlock()
	m := n.max
	n.max = 0
	return m
}

// TestTiming times what the Jira view asks for, against slowFake; with
// NUSHI_JIRA_TIMING=1 the times are the real site's (go test -v).
func TestTiming(t *testing.T) {
	f, second, in := slowFake(t)
	c := f.client()
	ctx := t.Context()
	timed := func(name string, run func() error) {
		start := time.Now()
		if err := run(); err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		took := time.Since(start)
		t.Logf("%-28s %4d ms (as a real site: %4d ms)", name, took.Milliseconds(), took*1000/second)
	}
	timed("mine (200 issues)", func() error { _, err := c.Search(ctx, "assignee = currentUser()", 200); return err })
	timed("sprint, first", func() error {
		id, _, err := c.ActiveSprint(ctx, 7)
		if err != nil {
			return err
		}
		_, err = c.Search(ctx, fmt.Sprint("sprint = ", id), 200)
		return err
	})
	// As features/jira asks once it knows the sprint: both at once.
	timed("sprint, again", func() error {
		var err error
		done := make(chan struct{})
		go func() {
			defer close(done)
			_, err = c.Search(ctx, "sprint = 1", 200)
		}()
		_, _, err2 := c.ActiveSprint(ctx, 7)
		<-done
		return cmp.Or(err, err2)
	})
	timed("issue, first", func() error { _, err := c.Issue(ctx, "SCRUM-5"); return err })
	in.reset()
	timed("issue, again", func() error { _, err := c.Issue(ctx, "SCRUM-5"); return err })
	// The issue's three calls go together: its fields, comments and
	// remote links.
	if n := in.reset(); n != 3 {
		t.Errorf("%d of the issue's calls at once, want 3", n)
	}
	timed("transitions", func() error { _, err := c.Transitions(ctx, "SCRUM-5"); return err })
}

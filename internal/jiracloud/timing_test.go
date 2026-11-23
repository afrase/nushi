package jiracloud

import (
	"context"
	"net/http"
	"testing"
	"time"
)

// An issue's three calls go together: its fields, comments and remote
// links. Each is answered only once all three are in, so calls made one
// after another never get past the first.
func TestIssueCallsTogether(t *testing.T) {
	f := issueFake(t)
	c := f.client()
	if _, err := c.Issue(t.Context(), "SCRUM-5"); err != nil { // the field list, asked for once
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(t.Context())
	defer cancel()
	in, all := make(chan string, 3), make(chan struct{})
	f.mu.Lock()
	for _, route := range []string{"GET /rest/api/3/issue/SCRUM-5", "GET /rest/api/3/issue/SCRUM-5/comment", "GET /rest/api/3/issue/SCRUM-5/remotelink"} {
		h := f.routes[route]
		f.routes[route] = func(w http.ResponseWriter, r *http.Request) {
			in <- route
			select {
			case <-all:
				h(w, r)
			case <-r.Context().Done():
			}
		}
	}
	f.mu.Unlock()
	done := make(chan error, 1)
	go func() {
		_, err := c.Issue(ctx, "SCRUM-5")
		done <- err
	}()
	for n := range 3 {
		select {
		case <-in:
		case <-time.After(5 * time.Second):
			t.Fatalf("%d of the issue's calls at once, want 3", n)
		}
	}
	close(all)
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}

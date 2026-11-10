package githubapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"testing"
)

// pendingFake is GitHub holding my review R0, pending: Thread adds its
// draft to the review's comments and Submit submits it, unless refuse
// says no. It fails the test on any other request: nothing is ever
// deleted.
type pendingFake struct {
	*fake
	state, body string
	comments    []fakeComment
	refuse      func(op string, vars map[string]any) string // GitHub's refusal, or ""
	down        bool                                        // the review's read answers 502
	threads     int                                         // Thread mutations sent
	submits     int                                         // Submit mutations sent
}

// fakeComment is an inline comment of the review, as the read gives it.
type fakeComment struct {
	Path      string `json:"path"`
	Line      int    `json:"line"`
	StartLine *int   `json:"startLine"`
	Body      string `json:"body"`
	ReplyTo   *struct {
		ID string `json:"id"`
	} `json:"replyTo"`
}

func newPendingFake(t *testing.T) *pendingFake {
	t.Helper()
	p := &pendingFake{fake: newFake(t), state: "PENDING"}
	p.route("graphql PendingReview", p.serveReview)
	p.route("graphql Thread", p.serveThread)
	p.route("graphql Submit", p.serveSubmit)
	t.Cleanup(func() {
		for _, c := range p.calls {
			if c != "graphql PendingReview" && c != "graphql Thread" && c != "graphql Submit" {
				t.Errorf("%s was sent", c)
			}
		}
	})
	return p
}

func decodeVars(r *http.Request) map[string]any {
	var q struct{ Variables map[string]any }
	_ = json.NewDecoder(r.Body).Decode(&q)
	return q.Variables
}

func (p *pendingFake) serveReview(w http.ResponseWriter, r *http.Request) {
	vars := decodeVars(r)
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.down {
		w.WriteHeader(http.StatusBadGateway)
		return
	}
	if vars["review"] != "R0" || p.state == "" {
		_, _ = w.Write([]byte(`{"data":{"node":null},"errors":[{"type":"NOT_FOUND","message":"Could not resolve to a node with the global id of 'R0'"}]}`))
		return
	}
	from := 0
	if a, ok := vars["after"].(string); ok {
		from, _ = strconv.Atoi(a)
	}
	to := min(from+100, len(p.comments))
	review := map[string]any{"state": p.state, "body": p.body, "comments": map[string]any{
		"pageInfo": map[string]any{"hasNextPage": to < len(p.comments), "endCursor": strconv.Itoa(to)},
		"nodes":    p.comments[from:to],
	}}
	_ = json.NewEncoder(w).Encode(map[string]any{"data": map[string]any{"node": review}})
}

func (p *pendingFake) serveThread(w http.ResponseWriter, r *http.Request) {
	vars := decodeVars(r)
	p.mu.Lock()
	defer p.mu.Unlock()
	p.threads++
	if no := p.refused("Thread", vars); no != "" || vars["review"] != "R0" || p.state != "PENDING" {
		_, _ = fmt.Fprintf(w, `{"data":{"addPullRequestReviewThread":null},"errors":[{"type":"UNPROCESSABLE","message":%q}]}`, no)
		return
	}
	c := fakeComment{Path: vars["path"].(string), Line: int(vars["line"].(float64)), Body: vars["body"].(string)}
	if s, ok := vars["startLine"].(float64); ok {
		c.StartLine = new(int(s))
	}
	p.comments = append(p.comments, c)
	_, _ = w.Write([]byte(`{"data":{"addPullRequestReviewThread":{"thread":{"id":"T` + strconv.Itoa(len(p.comments)) + `"}}}}`))
}

func (p *pendingFake) serveSubmit(w http.ResponseWriter, r *http.Request) {
	vars := decodeVars(r)
	p.mu.Lock()
	defer p.mu.Unlock()
	p.submits++
	if no := p.refused("Submit", vars); no != "" {
		_, _ = fmt.Fprintf(w, `{"data":{"submitPullRequestReview":null},"errors":[{"type":"UNPROCESSABLE","message":%q}]}`, no)
		return
	}
	p.state = strings.ReplaceAll(vars["event"].(string), "COMMENT", "COMMENTED")
	if b, ok := vars["body"].(string); ok {
		p.body = b
	}
	_, _ = w.Write([]byte(`{"data":{"submitPullRequestReview":{"pullRequestReview":{"id":"R0"}}}}`))
}

func (p *pendingFake) refused(op string, vars map[string]any) string {
	if p.refuse == nil {
		return ""
	}
	return p.refuse(op, vars)
}

// seen is what was sent and what the review holds: the mutations, the
// comments' bodies in order, and its state.
func (p *pendingFake) seen() string {
	p.mu.Lock()
	defer p.mu.Unlock()
	var b []string
	for _, c := range p.comments {
		b = append(b, c.Body)
	}
	return fmt.Sprintf("%d threads, %d submits: %q %s", p.threads, p.submits, strings.Join(b, " "), p.state)
}

// ownPull refuses an approval, as GitHub does on my own pull request.
func ownPull(op string, vars map[string]any) string {
	if op == "Submit" && vars["event"] == "APPROVE" {
		return "Can not approve your own pull request"
	}
	return ""
}

func drafts(bodies ...string) []Draft {
	var out []Draft
	for i, b := range bodies {
		out = append(out, Draft{Path: "a.go", Side: "right", Line: 3 + i, Body: b})
	}
	return out
}

func into(event string, d []Draft) Review {
	return Review{Pull: "PR_1", Pending: "R0", Event: event, Drafts: d}
}

func TestPendingRetryAddsEachOnce(t *testing.T) {
	p := newPendingFake(t)
	p.refuse = ownPull
	c := p.client()
	two := drafts("one", "two")
	err := c.SubmitReview(t.Context(), into("approve", two))
	if err == nil || !strings.Contains(err.Error(), "Can not approve your own pull request") ||
		!strings.Contains(err.Error(), "All 2 of this review's inline comments are in your pending review on GitHub now") {
		t.Fatal(err)
	}
	if err := c.SubmitReview(t.Context(), into("comment", two)); err != nil {
		t.Fatal(err)
	}
	if got := p.seen(); got != `2 threads, 2 submits: "one two" COMMENTED` {
		t.Fatal(got)
	}
}

func TestPendingRetryAddsWhatsMissing(t *testing.T) {
	p := newPendingFake(t)
	p.refuse = func(op string, vars map[string]any) string {
		if op == "Thread" && vars["body"] == "two" {
			return "Line could not be resolved"
		}
		return ""
	}
	c := p.client()
	three := drafts("one", "two", "three")
	err := c.SubmitReview(t.Context(), into("comment", three))
	if err == nil || !strings.Contains(err.Error(), "Line could not be resolved") ||
		!strings.Contains(err.Error(), "1 of this review's 3 inline comments is in your pending review on GitHub now") {
		t.Fatal(err)
	}
	if err := c.SubmitReview(t.Context(), into("comment", []Draft{three[0], three[2]})); err != nil {
		t.Fatal(err)
	}
	if got := p.seen(); got != `3 threads, 1 submits: "one three" COMMENTED` {
		t.Fatal(got)
	}
}

func TestPendingRetryWithNoDrafts(t *testing.T) {
	p := newPendingFake(t)
	p.refuse = ownPull
	c := p.client()
	if err := c.SubmitReview(t.Context(), into("approve", drafts("one", "two"))); err == nil || !strings.Contains(err.Error(), "All 2 of") {
		t.Fatal(err)
	}
	if err := c.SubmitReview(t.Context(), into("comment", nil)); err != nil {
		t.Fatal(err)
	}
	if got := p.seen(); got != `2 threads, 2 submits: "one two" COMMENTED` {
		t.Fatal(got)
	}
}

func TestPendingTwinDrafts(t *testing.T) {
	p := newPendingFake(t)
	twin := Draft{Path: "a.go", Side: "left", Line: 9, StartLine: 7, Body: "same"}
	p.comments = []fakeComment{{Path: "a.go", Line: 9, StartLine: new(7), Body: "same\r\n"}}
	if err := p.client().SubmitReview(t.Context(), into("comment", []Draft{twin, twin})); err != nil {
		t.Fatal(err)
	}
	if got := p.seen(); got != `1 threads, 1 submits: "same\r\n same" COMMENTED` {
		t.Fatal(got)
	}
}

func TestPendingAlreadySubmitted(t *testing.T) {
	p := newPendingFake(t)
	p.state, p.body = "APPROVED", "Looks good"
	p.comments = []fakeComment{
		{Path: "a.go", Line: 3, Body: "one\r\nmore  \r\n"},
		{Path: "a.go", Line: 4, Body: "two"},
		{Path: "a.go", Line: 4, Body: "three", ReplyTo: &struct {
			ID string `json:"id"`
		}{"C1"}},
	}
	c := p.client()
	r := into("approve", drafts("one\nmore", "two"))
	r.Body = "Looks good\n"
	if err := c.SubmitReview(t.Context(), r); err != nil {
		t.Fatalf("an answered submission: %v", err)
	}
	for _, r := range []Review{
		into("approve", drafts("one\nmore", "two", "three")), // three is only a reply
		{Pull: "PR_1", Pending: "R0", Event: "comment", Body: "Something else"},
	} {
		if err := c.SubmitReview(t.Context(), r); err == nil || !strings.Contains(err.Error(), "submitted on GitHub meanwhile") {
			t.Fatal(err)
		}
	}
	if got := p.seen(); !strings.HasPrefix(got, "0 threads, 0 submits") {
		t.Fatal("into a submitted review:", got)
	}
}

func TestPendingUnreadable(t *testing.T) {
	p := newPendingFake(t)
	c := p.client()
	p.down = true
	if err := c.SubmitReview(t.Context(), into("comment", drafts("one"))); err == nil {
		t.Fatal("went with no state")
	}
	p.down, p.state = false, ""
	if err := c.SubmitReview(t.Context(), into("comment", drafts("one"))); err == nil || !strings.Contains(err.Error(), "Could not resolve") {
		t.Fatal(err)
	}
	if got := p.seen(); !strings.HasPrefix(got, "0 threads, 0 submits") {
		t.Fatal("with no state:", got)
	}
}

func TestPendingManyComments(t *testing.T) {
	p := newPendingFake(t)
	var bodies []string
	for i := range 150 {
		bodies = append(bodies, "c"+strconv.Itoa(i))
	}
	for _, d := range drafts(bodies...) {
		p.comments = append(p.comments, fakeComment{Path: d.Path, Line: d.Line, Body: d.Body})
	}
	if err := p.client().SubmitReview(t.Context(), into("comment", drafts(append(bodies, "new")...))); err != nil {
		t.Fatal(err)
	}
	if got := p.seen(); !strings.HasPrefix(got, "1 threads, 1 submits") || !strings.Contains(got, `c149 new"`) || p.count("graphql PendingReview") != 2 {
		t.Fatal(got, p.count("graphql PendingReview"))
	}
}

package githubapi

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"
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
	lost        func()                                      // called when a submission is made, whose answer then never comes
	threads     int                                         // Thread mutations sent
	submits     int                                         // Submit mutations sent
}

// fakeComment is an inline comment of the review: Line and StartLine
// where it was made, Moved how far a push has moved it since, Outdated
// whether a push has left it no line.
type fakeComment struct {
	Path      string
	Line      int
	StartLine *int
	Moved     int
	Outdated  bool
	Body      string
	ReplyTo   string // the comment it replies to, if it's a reply
}

// node is the comment as GitHub's read gives it.
func (c fakeComment) node() map[string]any {
	n := map[string]any{"path": c.Path, "originalLine": c.Line, "originalStartLine": c.StartLine, "body": c.Body, "line": nil, "startLine": nil, "replyTo": nil}
	if !c.Outdated {
		n["line"] = c.Line + c.Moved
		if c.StartLine != nil {
			n["startLine"] = *c.StartLine + c.Moved
		}
	}
	if c.ReplyTo != "" {
		n["replyTo"] = map[string]any{"id": c.ReplyTo}
	}
	return n
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
	_, _ = io.Copy(io.Discard, r.Body) // read to its end, so the server sees the client go
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
	var nodes []map[string]any
	for _, c := range p.comments[from:to] {
		nodes = append(nodes, c.node())
	}
	review := map[string]any{"state": p.state, "body": p.body, "comments": map[string]any{
		"pageInfo": map[string]any{"hasNextPage": to < len(p.comments), "endCursor": strconv.Itoa(to)},
		"nodes":    nodes,
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
	p.submits++
	if no := p.refused("Submit", vars); no != "" {
		p.mu.Unlock()
		_, _ = fmt.Fprintf(w, `{"data":{"submitPullRequestReview":null},"errors":[{"type":"UNPROCESSABLE","message":%q}]}`, no)
		return
	}
	p.state = strings.ReplaceAll(vars["event"].(string), "COMMENT", "COMMENTED")
	if b, ok := vars["body"].(string); ok {
		p.body = b
	}
	lost := p.lost
	p.mu.Unlock()
	if lost != nil {
		lost()
		select { // until the client has gone
		case <-r.Context().Done():
		case <-time.After(5 * time.Second):
		}
		return
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
	if err == nil || !strings.HasSuffix(err.Error(), "Can not approve your own pull request. All 2 of this review's inline comments are in your pending review on GitHub now, "+
		"and go out with it even if removed here (delete them on github.com); sending the review again won't add them twice") {
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
		!strings.Contains(err.Error(), "1 of this review's 3 inline comments is in your pending review on GitHub now, and goes out with it even if removed here (delete it on github.com)") {
		t.Fatal(err)
	}
	if err := c.SubmitReview(t.Context(), into("comment", []Draft{three[0], three[2]})); err != nil {
		t.Fatal(err)
	}
	if got := p.seen(); got != `3 threads, 1 submits: "one three" COMMENTED` {
		t.Fatal(got)
	}
}

// A push between the failure and the retry moves the comments added, or
// leaves them no line: they're still the drafts, where they were made.
func TestPendingRetryAfterPush(t *testing.T) {
	p := newPendingFake(t)
	p.refuse = ownPull
	c := p.client()
	two := drafts("one", "two")
	two[1].StartLine = 2
	if err := c.SubmitReview(t.Context(), into("approve", two)); err == nil || !strings.Contains(err.Error(), "All 2 of") {
		t.Fatal(err)
	}
	p.mu.Lock()
	p.comments[0].Moved, p.comments[1].Outdated = 5, true
	p.mu.Unlock()
	if err := c.SubmitReview(t.Context(), into("comment", two)); err != nil {
		t.Fatal(err)
	}
	if got := p.seen(); got != `2 threads, 2 submits: "one two" COMMENTED` {
		t.Fatal(got)
	}
}

// A submission GitHub made whose answer was lost, the request cancelled
// meanwhile: the review read again (past the cancellation) holds every
// draft, so it's sent, and nothing is sent again.
func TestPendingSubmitAnswerLost(t *testing.T) {
	p := newPendingFake(t)
	ctx, cancel := context.WithCancel(t.Context())
	p.lost = cancel
	if err := p.client().SubmitReview(ctx, into("comment", drafts("one", "two"))); err != nil {
		t.Fatal(err)
	}
	if got := p.seen(); got != `2 threads, 1 submits: "one two" COMMENTED` || p.count("graphql PendingReview") != 2 {
		t.Fatal(got, p.count("graphql PendingReview"))
	}
}

// A refused submission leaves the review pending, as read again.
func TestPendingSubmitRefused(t *testing.T) {
	p := newPendingFake(t)
	p.refuse = ownPull
	err := p.client().SubmitReview(t.Context(), into("approve", drafts("one")))
	if err == nil || !strings.Contains(err.Error(), "Can not approve your own pull request. This review's inline comment is in your pending review on GitHub now") {
		t.Fatal(err)
	}
	if got := p.seen(); got != `1 threads, 1 submits: "one" PENDING` || p.count("graphql PendingReview") != 2 {
		t.Fatal(got, p.count("graphql PendingReview"))
	}
}

// A failed submission whose review can't be read again may have gone
// through: the error says to reload, not that a retry is safe.
func TestPendingSubmitFailedUnread(t *testing.T) {
	p := newPendingFake(t)
	p.refuse = func(op string, vars map[string]any) string {
		if op == "Submit" {
			p.down = true
			return "Something went wrong"
		}
		return ""
	}
	err := p.client().SubmitReview(t.Context(), into("comment", drafts("one", "two")))
	if err == nil || err.Error() != "GitHub: Something went wrong. The review may have been submitted: reload the pull request before sending it again" {
		t.Fatal(err)
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

// Comments made at 10 and 20, moved to 20 and 30: draft 20 is the one
// made there, though the other is there now, whatever the drafts' order.
func TestPendingMovedOntoAnother(t *testing.T) {
	p := newPendingFake(t)
	p.comments = []fakeComment{{Path: "a.go", Line: 10, Moved: 10, Body: "same"}, {Path: "a.go", Line: 20, Moved: 10, Body: "same"}}
	d := []Draft{{Path: "a.go", Line: 20, Body: "same"}, {Path: "a.go", Line: 10, Body: "same"}}
	if err := p.client().SubmitReview(t.Context(), into("comment", d)); err != nil {
		t.Fatal(err)
	}
	if got := p.seen(); got != `0 threads, 1 submits: "same same" COMMENTED` {
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
		{Path: "a.go", Line: 4, Body: "three", ReplyTo: "C1"},
	}
	c := p.client()
	for _, r := range []Review{
		into("approve", drafts("one\nmore", "two")),
		{Pull: "PR_1", Pending: "R0", Event: "approve", Body: "Looks good\n"},
	} {
		if err := c.SubmitReview(t.Context(), r); err != nil {
			t.Fatalf("an answered submission: %v", err)
		}
	}
	for _, s := range []struct {
		r    Review
		want string
	}{
		{into("approve", drafts("one\nmore", "two", "three")), // three is only a reply
			"your review was submitted on GitHub meanwhile with 2 of this review's 3 inline comments in it: reload the pull request, and remove those before sending the rest"},
		{into("approve", drafts("one\nmore", "four", "three")),
			"your review was submitted on GitHub meanwhile with 1 of this review's 3 inline comments in it: reload the pull request, and remove it before sending the rest"},
		{into("approve", drafts("five")), "your review was submitted on GitHub meanwhile: reload the pull request"},
		{Review{Pull: "PR_1", Pending: "R0", Event: "approve", Body: "Something else"}, "your review was submitted on GitHub meanwhile: reload the pull request"},
	} {
		if err := c.SubmitReview(t.Context(), s.r); err == nil || err.Error() != s.want {
			t.Fatal(err)
		}
	}
	if got := p.seen(); !strings.HasPrefix(got, "0 threads, 0 submits") {
		t.Fatal("into a submitted review:", got)
	}
}

// A review submitted on github.com with every draft, as something else
// and without the text: its comments are sent, so the drafts must go, or
// the next Submit, after a reload, posts them again.
func TestPendingSubmittedWithTheDrafts(t *testing.T) {
	p := newPendingFake(t)
	p.state = "COMMENTED"
	p.comments = []fakeComment{{Path: "a.go", Line: 3, Body: "one"}, {Path: "a.go", Line: 4, Body: "two"}}
	r := into("approve", drafts("one", "two"))
	r.Body = "LGTM"
	if err := p.client().SubmitReview(t.Context(), r); err != nil {
		t.Fatal(err)
	}
	if got := p.seen(); !strings.HasPrefix(got, "0 threads, 0 submits") {
		t.Fatal("into a submitted review:", got)
	}
}

// A call with no drafts is its event and text: a review submitted as
// something else isn't it.
func TestPendingSubmittedAsOther(t *testing.T) {
	p := newPendingFake(t)
	p.comments = []fakeComment{{Path: "a.go", Line: 3, Body: "from the browser"}}
	c := p.client()
	for _, s := range []struct{ state, event string }{
		{"COMMENTED", "approve"}, {"COMMENTED", "request_changes"}, {"DISMISSED", "approve"}, {"APPROVED", "comment"},
	} {
		p.state = s.state
		if err := c.SubmitReview(t.Context(), into(s.event, nil)); err == nil || !strings.Contains(err.Error(), "submitted on GitHub meanwhile") {
			t.Fatalf("%s into %s: %v", s.event, s.state, err)
		}
	}
	p.state = "CHANGES_REQUESTED"
	if err := c.SubmitReview(t.Context(), into("request_changes", nil)); err != nil {
		t.Fatalf("an answered submission: %v", err)
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
	if err := c.SubmitReview(t.Context(), into("comment", drafts("one"))); err == nil || !strings.Contains(err.Error(), "Could not resolve") ||
		!strings.HasSuffix(err.Error(), "reload the pull request") {
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

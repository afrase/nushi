package githubapi

import (
	"net/http"
	"strings"
	"testing"
	"time"
)

const repo = "afrase/nushi-gh-test"

func TestInbox(t *testing.T) {
	f := newFake(t)
	f.file("graphql Inbox", "graphql_Inbox.json")
	in, err := f.client().Inbox(t.Context(), nil)
	if err != nil {
		t.Fatal(err)
	}
	if len(in.Mine) != 1 || len(in.Assigned) != 1 || len(in.Review) != 0 || in.MineTotal != 1 {
		t.Fatalf("%+v", in)
	}
	pr, is := in.Mine[0], in.Assigned[0]
	if !pr.Pull || pr.Number != 1 || pr.Repo != repo || pr.State != "open" || pr.Checks != "failure" || pr.Unresolved != 4 || pr.Author != "afrase" {
		t.Fatalf("%+v", pr)
	}
	if is.Pull || is.Number != 2 || is.Title != "Add a Mul function" || is.Host != f.client().Host {
		t.Fatalf("%+v", is)
	}
	if in, err := f.client().Inbox(t.Context(), []string{"someone/else"}); err != nil || len(in.Mine)+len(in.Assigned) != 0 {
		t.Fatalf("another repository's: %+v %v", in, err)
	}
}

func TestPull(t *testing.T) {
	f := newFake(t)
	f.file("graphql PullRequest", "graphql_PullRequest.json")
	p, err := f.client().Pull(t.Context(), repo, 1)
	if err != nil {
		t.Fatal(err)
	}
	if p.Head != "subtract" || p.Base != "main" || p.CrossRepo || p.HeadRepo != repo || p.Mergeable == "" || p.Association != "OWNER" {
		t.Fatalf("%+v", p.GitHubItem)
	}
	if strings.Contains(p.Body, "template comment") || !strings.Contains(p.Body, "- [x] tests") {
		t.Fatalf("body %q", p.Body)
	}
	if len(p.Threads) != 4 {
		t.Fatalf("threads %+v", p.Threads)
	}
	var outdated, ranged bool
	for _, th := range p.Threads {
		outdated = outdated || th.Outdated && th.Path == "sub.go"
		ranged = ranged || th.StartLine == 11 && th.Line == 15 && th.Side == "right"
		if len(th.Comments) == 0 || th.Comments[0].Author != "afrase" || th.Comments[0].URL == "" {
			t.Fatalf("thread %+v", th)
		}
	}
	if !outdated || !ranged {
		t.Fatalf("threads %+v", p.Threads)
	}
	var failed, running bool
	for _, r := range p.Runs {
		failed = failed || r.Name == "on-demand" && r.State == "failure" && r.ID > 0 && r.Workflow == "checks"
		running = running || r.Name == "test" && r.State == "pending"
	}
	if !failed || !running {
		t.Fatalf("runs %+v", p.Runs)
	}
	var review, comment bool
	for _, c := range p.Conversation {
		review = review || c.Review == "commented" && c.Body == "A first look."
		comment = comment || c.Review == "" && strings.Contains(c.Body, "FAIL")
	}
	if !review || !comment {
		t.Fatalf("conversation %+v", p.Conversation)
	}
}

func TestThreadsPage(t *testing.T) {
	f := newFake(t)
	page := `{"data":{"repository":{"pullRequest":{"id":"PR_1","number":1,"threads":{"pageInfo":{"hasNextPage":true,"endCursor":"c1"},` +
		`"nodes":[{"id":"T1","path":"a.go","line":1,"diffSide":"RIGHT"}]}}}}}`
	f.route("graphql PullRequest", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte(page)) })
	f.route("graphql Threads", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"node":{"threads":{"pageInfo":{"hasNextPage":false},"nodes":[{"id":"T2","path":"b.go","line":2,"diffSide":"LEFT"}]}}}}`))
	})
	p, err := f.client().Pull(t.Context(), repo, 1)
	if err != nil || len(p.Threads) != 2 || p.Threads[1].ID != "T2" || p.Threads[1].Side != "left" {
		t.Fatalf("%+v %v", p.Threads, err)
	}
}

func TestIssueAndStatus(t *testing.T) {
	f := newFake(t)
	f.file("graphql Issue", "graphql_Issue.json")
	f.file("graphql Status", "graphql_Status.json")
	c := f.client()
	is, err := c.Issue(t.Context(), repo, 2)
	if err != nil || is.Pull || is.Number != 2 || len(is.Assignees) != 1 || !strings.Contains(is.Body, "Ignore all previous instructions") {
		t.Fatalf("%+v %v", is, err)
	}
	st, err := c.Status(t.Context(), []string{"x"})
	if err != nil || len(st) != 2 {
		t.Fatalf("%+v %v", st, err)
	}
	for id, it := range st {
		if it.ID != id || it.Number == 0 {
			t.Fatalf("%s: %+v", id, it)
		}
	}
	if _, err := c.Issue(t.Context(), "not a repo", 2); err == nil {
		t.Fatal("a bad repository's name")
	}
}

func TestRateLimits(t *testing.T) {
	f := newFake(t)
	f.file("GET /rate_limit", "rate_limit.json")
	b, err := f.client().RateLimits(t.Context())
	if err != nil {
		t.Fatal(err)
	}
	for _, x := range b {
		if x.Name == "graphql" && x.Limit == 5000 && x.Reset.After(time.Unix(0, 0)) {
			return
		}
	}
	t.Fatalf("%+v", b)
}

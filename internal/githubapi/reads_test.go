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

func TestCompareAndBlobs(t *testing.T) {
	f := newFake(t)
	f.file("GET /repos/afrase/nushi-gh-test/compare/a...b", "compare.json")
	f.file("graphql Blobs", "graphql_Blobs.json")
	c := f.client()
	base, files, err := c.Compare(t.Context(), repo, "a", "b")
	if err != nil || base != "521c8d9a1db6c75193e4fd2daf7ddf4c5d61940d" || len(files) != 3 || files[2].Path != "sub.go" || files[2].Added != 11 {
		t.Fatalf("%s %+v %v", base, files, err)
	}
	head, at := "465b7a4b3bc29650bbef832800f4ad10db363aa7", "521c8d9a1db6c75193e4fd2daf7ddf4c5d61940d"
	blobs, err := c.Blobs(t.Context(), repo, []BlobAt{{head, "sub.go"}, {at, "sub.go"}, {at, "add.go"}})
	if err != nil || !strings.Contains(blobs[BlobAt{head, "sub.go"}].Text, "0 - a") || blobs[BlobAt{at, "sub.go"}].Found ||
		!strings.Contains(blobs[BlobAt{at, "add.go"}].Text, "func Add") {
		t.Fatalf("%+v %v", blobs, err)
	}
}

func TestJobLog(t *testing.T) {
	f := newFake(t)
	f.route("GET /repos/afrase/nushi-gh-test/actions/jobs/7/logs", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Location", f.srv.URL+"/blob/log?sig=1")
		w.WriteHeader(http.StatusFound)
	})
	f.route("GET /blob/log", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(strings.Repeat("2026-10-26T04:15:17.1234567Z noise\n", 20000) +
			"2026-10-26T04:15:18.0000000Z \x1b[36;1mThe branch has a FAIL file:\x1b[0m\n" +
			"2026-10-26T04:15:18.0000000Z ##[error]Process completed with exit code 1.\n"))
	})
	log, err := f.client().JobLog(t.Context(), repo, 7)
	if err != nil || len(log) > logKept {
		t.Fatalf("%d %v", len(log), err)
	}
	tail := Tail(log, 200)
	if !strings.HasSuffix(tail, "noise\nThe branch has a FAIL file:\n##[error]Process completed with exit code 1.") || len(tail) > 200 ||
		!strings.HasPrefix(tail, "noise") {
		t.Fatalf("%q", tail)
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

// TestUnsafeURLs: a check's and a status's address are their poster's
// (any scheme); only http and https leave the daemon.
func TestUnsafeURLs(t *testing.T) {
	f := newFake(t)
	f.route("graphql PullRequest", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"repository":{"pullRequest":{"id":"PR_1","number":1,"url":"javascript:alert(1)",` +
			`"comments":{"nodes":[{"id":"C1","url":"file:///etc/passwd","body":"x"}]},` +
			`"last":{"nodes":[{"commit":{"statusCheckRollup":{"contexts":{"nodes":[` +
			`{"__typename":"CheckRun","name":"a","status":"COMPLETED","conclusion":"FAILURE","detailsUrl":"javascript:alert(1)"},` +
			`{"__typename":"StatusContext","context":"b","state":"FAILURE","targetUrl":"file:///tmp/x"},` +
			`{"__typename":"CheckRun","name":"c","status":"COMPLETED","conclusion":"SUCCESS","detailsUrl":"https://ci.example/1"}]}}}}]}}}}}`))
	})
	p, err := f.client().Pull(t.Context(), repo, 1)
	if err != nil {
		t.Fatal(err)
	}
	if p.URL != "" || p.Conversation[0].URL != "" || p.Runs[0].URL != "" || p.Runs[1].URL != "" || p.Runs[2].URL != "https://ci.example/1" {
		t.Fatalf("%q %q %+v", p.URL, p.Conversation[0].URL, p.Runs)
	}
}

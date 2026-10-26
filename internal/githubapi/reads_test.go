package githubapi

import (
	"encoding/json"
	"fmt"
	"maps"
	"net/http"
	"os"
	"slices"
	"strings"
	"testing"
	"time"
)

const repo = "afrase/nushi-gh-test"

func TestInbox(t *testing.T) {
	f := newFake(t)
	f.file("graphql Inbox", "graphql_Inbox.json")
	in, err := f.client().Inbox(t.Context(), InboxFilter{})
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
	if in, err := f.client().Inbox(t.Context(), InboxFilter{Repos: []string{"someone/else"}}); err != nil || len(in.Mine)+len(in.Assigned) != 0 {
		t.Fatalf("another repository's: %+v %v", in, err)
	}
}

// Review requested is me by name (user-review-requested:@me) unless my
// teams are asked for too (review-requested:@me); either way the inbox
// is one query.
func TestInboxReviewRequested(t *testing.T) {
	answer, err := os.ReadFile("testdata/graphql_Inbox.json")
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct {
		filter      InboxFilter
		review, not string
	}{
		{InboxFilter{}, " user-review-requested:@me", " review-requested:@me"},
		{InboxFilter{Teams: true}, " review-requested:@me", "user-review-requested"},
		{InboxFilter{Repos: []string{repo}}, "repo:" + repo + " user-review-requested:@me", " review-requested:@me"},
	} {
		f := newFake(t)
		var vars map[string]string
		f.route("graphql Inbox", func(w http.ResponseWriter, r *http.Request) {
			var q struct{ Variables map[string]string }
			_ = json.NewDecoder(r.Body).Decode(&q)
			vars = q.Variables
			_, _ = w.Write(answer)
		})
		if _, err := f.client().Inbox(t.Context(), c.filter); err != nil {
			t.Fatal(err)
		}
		if !strings.HasSuffix(vars["review"], c.review) || strings.Contains(vars["review"], c.not) || !strings.HasPrefix(vars["review"], "is:pr is:open") {
			t.Fatalf("%+v: review %q", c.filter, vars["review"])
		}
		if !strings.HasSuffix(vars["mine"], " author:@me") || !strings.HasSuffix(vars["assigned"], " assignee:@me") {
			t.Fatalf("%+v: %v", c.filter, vars)
		}
		if n := f.count("graphql Inbox"); n != 1 {
			t.Fatalf("%+v: %d queries", c.filter, n)
		}
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
		_, _ = w.Write([]byte("\ufeff" + strings.Repeat("2026-10-26T04:15:17.1234567Z noise\n", 20000) +
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

func TestTailOfAShortLog(t *testing.T) {
	if got := Tail("\ufeff2026-10-26T04:25:53.6105613Z Current runner version\n2026-10-26T04:25:54.0Z ##[error]x", 100); got != "Current runner version\n##[error]x" {
		t.Fatalf("%q", got)
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

// TestEveryTextIsAsGitHubShowsIt: every Markdown field of a pull request
// (its body, a comment, a review, a thread's comment, a check's summary)
// comes out as GitHub's page shows it: a hidden comment in each is gone.
func TestEveryTextIsAsGitHubShowsIt(t *testing.T) {
	f := newFake(t)
	const h = "shown <!-- HIDDEN -->"
	f.route("graphql PullRequest", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"repository":{"pullRequest":{"id":"PR_1","number":1,"body":"` + h + `",` +
			`"comments":{"nodes":[{"id":"C1","body":"` + h + `"}]},` +
			`"reviews":{"nodes":[{"id":"R1","state":"COMMENTED","body":"` + h + `"}]},` +
			`"threads":{"nodes":[{"id":"T1","path":"a","comments":{"nodes":[{"id":"C2","body":"` + h + `"}]}}]},` +
			`"last":{"nodes":[{"commit":{"statusCheckRollup":{"contexts":{"nodes":[` +
			`{"__typename":"CheckRun","name":"a","status":"COMPLETED","conclusion":"FAILURE","summary":"` + h + `"}]}}}}]}}}}}`))
	})
	p, err := f.client().Pull(t.Context(), repo, 1)
	if err != nil {
		t.Fatal(err)
	}
	texts := []string{p.Body, p.Conversation[0].Body, p.Conversation[1].Body, p.Threads[0].Comments[0].Body, p.Runs[0].Summary}
	for _, x := range texts {
		if x != "shown" {
			t.Errorf("%q", x)
		}
	}
	f.route("graphql Issue", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"data":{"repository":{"issue":{"id":"I_1","number":2,"body":"` + h + `","comments":{"nodes":[{"id":"C3","body":"` + h + `"}]}}}}}`))
	})
	is, err := f.client().Issue(t.Context(), repo, 2)
	if err != nil || is.Body != "shown" || is.Conversation[0].Body != "shown" {
		t.Fatalf("%q %+v %v", is.Body, is.Conversation, err)
	}
}

// The filters go into the searches themselves, so what they leave out
// doesn't take the 50 places: the date (a section widened goes without
// it, and with a date each search is counted without it too), hidden
// repositories and owners, and only some owners.
func TestInboxSearches(t *testing.T) {
	today := time.Date(2026, 10, 26, 23, 30, 0, 0, time.FixedZone("JST", 9*3600)) // the 26th, 14:30 UTC
	s := inboxSearches(InboxFilter{Days: 90, Wide: []string{"mine"}, Hide: []string{"boltops-tools/puma-cloudwatch", "spammy"},
		Owners: []string{"afrase", "degica"}}, today)
	const opts = "is:open archived:false sort:updated-desc user:afrase user:degica -repo:boltops-tools/puma-cloudwatch -user:spammy"
	want := map[string]any{
		"review":      "is:pr " + opts + " user-review-requested:@me updated:>=2026-07-28",
		"reviewAll":   "is:pr " + opts + " user-review-requested:@me",
		"mine":        "is:pr " + opts + " author:@me",
		"mineAll":     "is:pr " + opts + " author:@me",
		"assigned":    "is:issue " + opts + " assignee:@me updated:>=2026-07-28",
		"assignedAll": "is:issue " + opts + " assignee:@me",
	}
	if !maps.Equal(s, want) {
		t.Fatalf("%v", s)
	}
	if s := inboxSearches(InboxFilter{}, today); len(s) != 3 || strings.Contains(s["review"].(string), "updated:") {
		t.Fatalf("any time: %v", s)
	}
	var many []string
	for i := range hideQualifiers + 5 {
		many = append(many, fmt.Sprintf("o/r%d", i))
	}
	f := InboxFilter{Hide: many}
	if n := strings.Count(inboxSearches(f, today)["mine"].(string), "-repo:"); n != hideQualifiers {
		t.Fatalf("%d left out by the search", n)
	}
	if f.shows("o/r54") || f.shows("o/r0") || !f.shows("o/x") || (InboxFilter{Hide: []string{"o"}}).shows("o/x") ||
		!(InboxFilter{Owners: []string{"a"}}).shows("a/b") || (InboxFilter{Owners: []string{"a"}}).shows("b/a") {
		t.Fatal("the daemon's own check")
	}
	// No name can bring a qualifier of its own, quoted or not.
	for _, bad := range []InboxFilter{
		{Hide: []string{"a/b user:evil"}}, {Hide: []string{`a/b"`}}, {Hide: []string{`"a b"`}}, {Hide: []string{"-a"}},
		{Hide: []string{"a/b/c"}}, {Hide: []string{""}}, {Repos: []string{"a/b repo:c/d"}}, {Repos: []string{"a"}},
		{Owners: []string{"a b"}}, {Owners: []string{"a/b"}}, {Owners: []string{"a:b"}}, {Owners: []string{`"a"`}},
		{Owners: strings.Fields("a b c d e f g h i j k")}, {Wide: []string{"all"}}, {Days: -1},
	} {
		if bad.Check() == nil {
			t.Errorf("%+v passed", bad)
		}
	}
	// A name both asked for and hidden is neither (GitHub would drop the
	// first and search everyone's); with nothing left, nothing is asked.
	n, left := InboxFilter{Repos: []string{"a/b", "c/d", "e/f"}, Owners: []string{"x", "y"}, Hide: []string{"a/b", "e", "y", "z/z"}}.narrowed()
	if !left || !slices.Equal(n.Repos, []string{"c/d"}) || !slices.Equal(n.Owners, []string{"x"}) || !slices.Equal(n.Hide, []string{"e", "z/z"}) {
		t.Fatalf("%+v", n)
	}
	if _, left := (InboxFilter{Repos: []string{"a/b"}, Hide: []string{"a"}}).narrowed(); left {
		t.Fatal("all hidden")
	}
	if _, left := (InboxFilter{Owners: []string{"a"}, Hide: []string{"a"}}).narrowed(); left {
		t.Fatal("all hidden")
	}
	ok := InboxFilter{Repos: []string{"a-b/c.d_e"}, Hide: []string{"x", "x/y"}, Owners: []string{"Degica"}, Wide: Sections, Days: 30}
	if err := ok.Check(); err != nil {
		t.Fatal(err)
	}
}

// With a date, each section says how many more it has without it; a
// filter that isn't one is refused before GitHub is asked.
func TestInboxOlder(t *testing.T) {
	f := newFake(t)
	var vars map[string]string
	f.route("graphql Inbox", func(w http.ResponseWriter, r *http.Request) {
		var q struct{ Variables map[string]string }
		_ = json.NewDecoder(r.Body).Decode(&q)
		vars = q.Variables
		_, _ = w.Write([]byte(`{"data": {"review": {"issueCount": 2, "nodes": []}, "reviewAll": {"issueCount": 5},
			"mine": {"issueCount": 1, "nodes": []}, "mineAll": {"issueCount": 1},
			"assigned": {"issueCount": 0, "nodes": []}, "assignedAll": {"issueCount": 7}}}`))
	})
	in, err := f.client().Inbox(t.Context(), InboxFilter{Days: 30})
	if err != nil {
		t.Fatal(err)
	}
	if in.ReviewOlder != 3 || in.MineOlder != 0 || in.AssignedOlder != 7 || !strings.Contains(vars["review"], " updated:>=") || strings.Contains(vars["reviewAll"], "updated:") {
		t.Fatalf("%+v %v", in, vars)
	}
	if _, err := f.client().Inbox(t.Context(), InboxFilter{Hide: []string{"a/b is:closed"}}); err == nil || f.count("graphql Inbox") != 1 {
		t.Fatal("asked with a bad filter")
	}
}

package githubapi

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"regexp"
	"slices"
	"strings"
	"testing"

	"github.com/cli/go-gh/v2/pkg/auth"
)

// testRepo is the owner's throwaway repository for these tests: public,
// a tiny Go module whose "on-demand" check fails on a branch with a FAIL
// file. Pull request 1 (branch subtract) has that file, review threads
// (one outdated) and a comment; issue 2 is assigned to the owner. No
// other repository is read or written through the owner's token.
const testRepo = "afrase/nushi-gh-test"

// TestLive runs against testRepo with the gh login's token, read here
// through go-gh and never printed: only with NUSHI_GITHUB_LIVE=1 (never
// on CI). With NUSHI_GITHUB_RECORD=1 it also writes GitHub's answers to
// testdata, for the tests that run without GitHub.
func TestLive(t *testing.T) {
	if os.Getenv("NUSHI_GITHUB_LIVE") != "1" {
		t.Skip("NUSHI_GITHUB_LIVE=1 runs it against " + testRepo)
	}
	token, _ := auth.TokenForHost("github.com")
	if token == "" {
		t.Skip("no gh login for github.com")
	}
	transport := http.DefaultTransport
	if os.Getenv("NUSHI_GITHUB_RECORD") == "1" {
		transport = recorder{t}
	}
	c := New("github.com", token, transport)
	ctx := t.Context()
	me, err := c.Viewer(ctx)
	if err != nil || me.Login == "" {
		t.Fatalf("viewer: %+v %v", me, err)
	}
	if b, err := c.RateLimits(ctx); err != nil || !slices.ContainsFunc(b, func(b Bucket) bool { return b.Name == "graphql" && b.Limit > 0 }) {
		t.Fatalf("rate limits: %+v %v", b, err)
	}
	in, err := c.Inbox(ctx, []string{testRepo})
	if err != nil {
		t.Fatal(err)
	}
	for _, it := range slices.Concat(in.Review, in.Mine, in.Assigned) {
		if it.Repo != testRepo {
			t.Fatalf("the inbox went past %s: %s", testRepo, it.Repo)
		}
	}
	if len(in.Mine) == 0 || in.Mine[0].Number != 1 || len(in.Assigned) == 0 || in.Assigned[0].Number != 2 {
		t.Fatalf("inbox: %+v", in)
	}
	p, err := c.Pull(ctx, testRepo, 1)
	if err != nil {
		t.Fatal(err)
	}
	if p.Head != "subtract" || p.Base != "main" || len(p.Threads) < 3 || len(p.Runs) == 0 || !strings.Contains(p.Body, "Sub") {
		t.Fatalf("pull: %+v", p)
	}
	if strings.Contains(p.Body, "template comment") {
		t.Fatal("the body kept its HTML comment")
	}
	var failed int64
	for _, r := range p.Runs {
		if r.Name == "on-demand" && r.State == "failure" {
			failed = r.ID
		}
	}
	if failed == 0 {
		t.Fatalf("no failed on-demand check: %+v", p.Runs)
	}
	log, err := c.JobLog(ctx, testRepo, failed)
	if err != nil || !strings.Contains(Tail(log, TailSize), "FAIL") {
		t.Fatalf("job log: %v\n%s", err, Tail(log, 2000))
	}
	st, err := c.Status(ctx, []string{p.ID, in.Assigned[0].ID})
	if err != nil || st[p.ID].Number != 1 || st[in.Assigned[0].ID].Pull {
		t.Fatalf("status: %+v %v", st, err)
	}
	base, files, err := c.Compare(ctx, testRepo, p.BaseOID, p.HeadOID)
	if err != nil || base == "" || len(files) == 0 {
		t.Fatalf("compare: %s %+v %v", base, files, err)
	}
	blobs, err := c.Blobs(ctx, testRepo, []BlobAt{{p.HeadOID, "sub.go"}, {base, "sub.go"}, {base, "add.go"}})
	if err != nil || !strings.Contains(blobs[BlobAt{p.HeadOID, "sub.go"}].Text, "func Sub") || blobs[BlobAt{base, "sub.go"}].Found ||
		!blobs[BlobAt{base, "add.go"}].Found {
		t.Fatalf("blobs: %+v %v", blobs, err)
	}
	is, err := c.Issue(ctx, testRepo, 2)
	if err != nil || is.Pull || !strings.Contains(is.Body, "Mul") {
		t.Fatalf("issue: %+v %v", is, err)
	}
}

// recorder writes each answer's body to testdata, named after the
// request (a GraphQL operation, or the REST path's last part). Request
// headers (the token) are never written.
type recorder struct{ t *testing.T }

var nameRE = regexp.MustCompile(`[^A-Za-z0-9]+`)

func (r recorder) RoundTrip(req *http.Request) (*http.Response, error) {
	name := nameRE.ReplaceAllString(req.URL.Path[strings.LastIndex(req.URL.Path, "/")+1:], "_")
	if strings.Contains(req.URL.Path, "/compare/") {
		name = "compare"
	}
	if req.Body != nil && req.URL.Path == "/graphql" {
		b, _ := io.ReadAll(req.Body)
		req.Body = io.NopCloser(bytes.NewReader(b))
		var q struct {
			Op string `json:"operationName"`
		}
		_ = json.Unmarshal(b, &q)
		name = "graphql_" + q.Op
	}
	resp, err := http.DefaultTransport.RoundTrip(req)
	// Not /user: it says more of the account (its plan, its private
	// repositories' count) than a test needs; client_test makes its own.
	if err != nil || resp.StatusCode/100 != 2 || !strings.Contains(resp.Header.Get("Content-Type"), "json") || name == "user" {
		return resp, err
	}
	b, err := io.ReadAll(resp.Body)
	_ = resp.Body.Close()
	if err != nil {
		return nil, err
	}
	resp.Body = io.NopCloser(bytes.NewReader(b))
	var pretty bytes.Buffer
	if json.Indent(&pretty, b, "", "  ") == nil {
		if err := os.WriteFile("testdata/"+name+".json", append(pretty.Bytes(), '\n'), 0o600); err != nil {
			r.t.Error(err)
		}
	}
	return resp, nil
}

// TestLiveWrites writes to testRepo's pull request 1: a reply to its
// first thread, resolving and unresolving it, a comment, and a review
// with one inline comment. An approval of one's own pull request is
// refused by GitHub, and says so.
func TestLiveWrites(t *testing.T) {
	if os.Getenv("NUSHI_GITHUB_LIVE") != "1" {
		t.Skip("NUSHI_GITHUB_LIVE=1 runs it against " + testRepo)
	}
	token, _ := auth.TokenForHost("github.com")
	if token == "" {
		t.Skip("no gh login for github.com")
	}
	c := New("github.com", token, nil)
	ctx := t.Context()
	p, err := c.Pull(ctx, testRepo, 1)
	if err != nil || len(p.Threads) == 0 {
		t.Fatalf("%v %+v", err, p.Threads)
	}
	th := p.Threads[0]
	if _, err := c.Reply(ctx, th.ID, "A reply from Nushi's live test."); err != nil {
		t.Fatal(err)
	}
	if err := c.Resolve(ctx, th.ID, true); err != nil {
		t.Fatal(err)
	}
	if p, err := c.Pull(ctx, testRepo, 1); err != nil || !p.Threads[0].Resolved || !p.Threads[0].CanUnresolve {
		t.Fatalf("not resolved: %v %+v", err, p.Threads[0])
	}
	if err := c.Resolve(ctx, th.ID, false); err != nil {
		t.Fatal(err)
	}
	if _, err := c.Comment(ctx, p.ID, "A comment from Nushi's live test."); err != nil {
		t.Fatal(err)
	}
	err = c.SubmitReview(ctx, Review{Pull: p.ID, HeadOID: p.HeadOID, Event: "comment", Body: "A review from Nushi's live test.",
		Drafts: []Draft{{Path: "sub.go", Side: "right", Line: 4, Body: "An inline comment from Nushi's live test."}}})
	if err != nil {
		t.Fatal(err)
	}
	if err := c.SubmitReview(ctx, Review{Pull: p.ID, HeadOID: p.HeadOID, Event: "approve"}); err == nil {
		t.Fatal("GitHub let me approve my own pull request")
	} else {
		t.Logf("approving my own: %v", err)
	}
}

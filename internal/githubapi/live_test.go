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
	st, err := c.Status(ctx, []string{p.ID, in.Assigned[0].ID})
	if err != nil || st[p.ID].Number != 1 || st[in.Assigned[0].ID].Pull {
		t.Fatalf("status: %+v %v", st, err)
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

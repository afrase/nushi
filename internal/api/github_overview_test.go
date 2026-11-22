package api

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/github"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/store"
)

// TestGitHubPullOverview: GetGitHubPull carries what the Pull request tab's
// overview reads (labels, assignees, when it was opened, every review, a
// thread comment's review and the thread's diff hunk), and
// GetGitHubCommits a pull request's commits, from GitHub's recorded
// answers.
func TestGitHubPullOverview(t *testing.T) {
	const token = "ghp_overview0123456789"
	answers := map[string]string{"query PullRequest": "graphql_PullRequest_overview.json", "query Commits": "graphql_Commits.json"}
	gh := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		if r.Header.Get("Authorization") != "Bearer "+token {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		if r.URL.Path == "/api/v3/user" {
			_, _ = w.Write([]byte(`{"login":"mira"}`))
			return
		}
		for op, file := range answers {
			if bytes.Contains(body, []byte(op)) {
				b, err := os.ReadFile("../githubapi/testdata/" + file)
				if err != nil {
					t.Error(err)
				}
				_, _ = w.Write(b)
				return
			}
		}
		w.WriteHeader(http.StatusNotFound)
	}))
	defer gh.Close()
	host := strings.TrimPrefix(gh.URL, "https://")
	svc := github.New(github.Deps{
		Gh:     github.Gh{Token: func(context.Context, string) (string, string, error) { return "", "", nil }, Hosts: func() []string { return nil }, Reload: func() {}},
		Tokens: memTokens{}, Store: &memHosts{Store: store.New(t.TempDir())},
		Open: func(h, token string) github.Client { return githubapi.New(h, token, gh.Client().Transport) },
		Keys: github.Keys{NeedsOK: func(error) bool { return false }, Restart: func(error) bool { return false }, Missing: func(error) bool { return false }},
	})
	c := client(t, New(Services{GitHub: svc}))
	ctx := t.Context()
	if _, err := c.AddGitHubToken(ctx, connect.NewRequest(&nushiv1.AddGitHubTokenRequest{Host: host, Token: token})); err != nil {
		t.Fatal(err)
	}
	ref := &nushiv1.GitHubRef{Host: host, Repo: "acme/lumen", Number: 57}
	pr, err := c.GetGitHubPull(ctx, connect.NewRequest(&nushiv1.GetGitHubPullRequest{Ref: ref}))
	if err != nil {
		t.Fatal(err)
	}
	p := pr.Msg.Pull
	if p.Item.CreatedMs == 0 || len(p.Labels) != 2 || p.Labels[0].Color != "d73a4a" || strings.Join(p.Assignees, ",") != "mira,iris" {
		t.Fatalf("created %d, labels %v, assignees %v", p.Item.CreatedMs, p.Labels, p.Assignees)
	}
	if len(p.Reviews) != 3 || p.Reviews[0].Id != "PRR_tomas_1" || p.Reviews[0].Body != "" {
		t.Fatalf("reviews %v", p.Reviews)
	}
	th := p.Threads[0]
	if th.Comments[0].ReviewId != "PRR_tomas_1" || !strings.HasPrefix(th.DiffHunk, "@@ -40,6 +40,11 @@") {
		t.Fatalf("thread %v", th)
	}
	if ch := p.Checks[0]; ch.CompletedMs-ch.StartedMs != 132_000 {
		t.Fatalf("check %v", ch)
	}
	cs, err := c.GetGitHubCommits(ctx, connect.NewRequest(&nushiv1.GetGitHubCommitsRequest{Ref: ref, Quiet: true}))
	if err != nil {
		t.Fatal(err)
	}
	m := cs.Msg
	if m.Total != 3 || len(m.Commits) != 3 || m.Commits[0].Oid != "1a2b3c4d5e6f708192a3b4c5d6e7f80912345678" || m.Commits[0].Author != "mira" ||
		m.Commits[0].Checks != "failure" || m.Commits[0].CommittedMs == 0 || m.Commits[1].AuthorName != "Tomas" ||
		m.First.GetOid() != m.Commits[0].Oid || m.First.GetAuthor() != "mira" {
		t.Fatalf("commits %v", m)
	}
	if _, err := c.GetGitHubCommits(ctx, connect.NewRequest(&nushiv1.GetGitHubCommitsRequest{Ref: &nushiv1.GitHubRef{Host: "evil.example", Repo: "a/b", Number: 1}})); err == nil {
		t.Fatal("an unknown host was asked")
	}
}

package api

import (
	"context"
	"strings"
	"testing"
	"time"

	"connectrpc.com/connect"

	"github.com/afrase/nushi/internal/features/github"
	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
)

// overviewPull is GitHub with acme/lumen's pull request 57 as the Pull
// request tab's overview reads it, and its commits; githubapi's
// TestPullOverview and TestCommits read the same from GitHub's answers.
type overviewPull struct{ github.Client }

// overviewOpened is when the pull request was opened, and its first commit
// made.
var overviewOpened = time.Date(2026, 11, 18, 9, 0, 0, 0, time.UTC)

func (overviewPull) Refused() bool { return false }

func (overviewPull) Viewer(context.Context) (githubapi.User, error) {
	return githubapi.User{Login: "mira"}, nil
}

func (overviewPull) Pull(_ context.Context, repo string, number int) (model.GitHubPull, error) {
	if repo != "acme/lumen" || number != 57 {
		return model.GitHubPull{}, githubapi.ErrNotFound
	}
	review := func(id, state, body string) model.GitHubComment {
		return model.GitHubComment{ID: id, Author: "tomas", Review: state, Body: body, Created: overviewOpened}
	}
	return model.GitHubPull{
		Repo: repo, Number: number, ID: "PR_57", Pull: true,
		Title: "Expire idle sessions", State: "open", Author: "mira", Created: overviewOpened, Updated: overviewOpened,
		Labels:    []model.GitHubLabel{{Name: "security", Color: "d73a4a"}, {Name: "needs-docs", Color: "0e8a16"}},
		Assignees: []string{"mira", "iris"},
		Reviews: []model.GitHubComment{review("PRR_tomas_1", "commented", ""), review("PRR_tomas_2", "changes_requested", "Not yet."),
			review("PRR_iris_1", "approved", "")},
		Threads: []model.GitHubThread{{ID: "PRRT_1", Path: "store.go", Side: "right", Line: 44,
			Comments: []model.GitHubComment{{ID: "C_1", Author: "tomas", Body: "Why 30?", ReviewID: "PRR_tomas_1", Created: overviewOpened}},
			DiffHunk: "@@ -40,6 +40,11 @@ func (s *Store) Touch"}},
		Runs: []model.GitHubCheck{{ID: 7, Name: "test", State: "failure", Started: overviewOpened, Completed: overviewOpened.Add(2*time.Minute + 12*time.Second)}},
	}, nil
}

func (overviewPull) Commits(_ context.Context, repo string, number int) (model.GitHubCommits, error) {
	if repo != "acme/lumen" || number != 57 {
		return model.GitHubCommits{}, githubapi.ErrNotFound
	}
	first := model.GitHubCommit{OID: "1a2b3c4d5e6f708192a3b4c5d6e7f80912345678", Headline: "Expire idle sessions", Author: "mira",
		AuthorName: "Mira", Committed: overviewOpened, Checks: "failure", Cancelled: true}
	return model.GitHubCommits{Newest: []model.GitHubCommit{first,
		{OID: "2222222222222222222222222222222222222222", Headline: "Say why", AuthorName: "Tomas", Committed: overviewOpened.Add(time.Hour)},
		{OID: "3333333333333333333333333333333333333333", Headline: "Docs", Author: "mira", AuthorName: "Mira", Committed: overviewOpened.Add(2 * time.Hour), Checks: "success"},
	}, First: first, Total: 3}, nil
}

// TestGitHubPullOverview: GetGitHubPull carries what the Pull request tab's
// overview reads (labels, assignees, when it was opened, every review, a
// thread comment's review and the thread's diff hunk, a check's times),
// and GetGitHubCommits a pull request's commits, as the feature has them
// from GitHub; the client is opened on the host with the token given, and
// a host given none is never asked.
func TestGitHubPullOverview(t *testing.T) {
	const host, token = "ghe.example", "ghp_overview0123456789"
	var opened []string
	svc := github.New(github.Deps{
		Gh:     github.Gh{Token: func(context.Context, string) (string, string, error) { return "", "", nil }, Hosts: func() []string { return nil }},
		Tokens: memTokens{}, Store: &memHosts{Store: store.New(t.TempDir())},
		Open: func(h, tok string) github.Client {
			opened = append(opened, h+" "+tok)
			return overviewPull{}
		},
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
	if p.Item.CreatedMs != overviewOpened.UnixMilli() || len(p.Labels) != 2 || p.Labels[0].Color != "d73a4a" || strings.Join(p.Assignees, ",") != "mira,iris" {
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
		m.Commits[0].Checks != "failure" || !m.Commits[0].Cancelled || m.Commits[2].Cancelled || m.Commits[0].CommittedMs == 0 || m.Commits[1].AuthorName != "Tomas" ||
		m.First.GetOid() != m.Commits[0].Oid || m.First.GetAuthor() != "mira" {
		t.Fatalf("commits %v", m)
	}
	if _, err := c.GetGitHubCommits(ctx, connect.NewRequest(&nushiv1.GetGitHubCommitsRequest{Ref: &nushiv1.GitHubRef{Host: "evil.example", Repo: "a/b", Number: 1}})); err == nil {
		t.Fatal("an unknown host was asked")
	}
	for _, o := range opened {
		if o != host+" "+token {
			t.Errorf("a client opened as %q, want only on %s with its token", o, host)
		}
	}
	if len(opened) == 0 {
		t.Error("no client opened")
	}
}

package githubapi

import (
	"context"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// commitsQuery asks for a pull request's newest 100 commits, and its
// first (the alias first), which the newest 100 leave out of a longer
// one: one query of about two points, where more would page (GitHub
// allows 250 at most). Each commit's checks are counted by state
// (COUNTS, countsField), to tell a rollup failing only because of
// cancelled checks; a server that refuses the counts is asked without.
const commitsQuery = `query Commits($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      commits(last: 100) { totalCount nodes { commit { ...TrailCommit } } }
      first: commits(first: 1) { nodes { commit { ...TrailCommit } } }
    }
  }
}
fragment TrailCommit on Commit {
  oid messageHeadline committedDate
  author { name user { login } }
  statusCheckRollup { state COUNTS }
}`

// commitNode decodes a TrailCommit.
type commitNode struct {
	Commit struct {
		OID             string    `json:"oid"`
		MessageHeadline text      `json:"messageHeadline"`
		CommittedDate   time.Time `json:"committedDate"`
		Author          *struct {
			Name text   `json:"name"`
			User *login `json:"user"`
		} `json:"author"`
		StatusCheckRollup *struct {
			State    string `json:"state"`
			Contexts struct {
				CheckRuns []stateCount `json:"checkRunCountsByState"`
				Statuses  []stateCount `json:"statusContextCountsByState"`
			} `json:"contexts"`
		} `json:"statusCheckRollup"`
	} `json:"commit"`
}

func (n commitNode) commit() model.GitHubCommit {
	x := n.Commit
	cm := model.GitHubCommit{OID: x.OID, Headline: plain(string(x.MessageHeadline), 1024), Committed: x.CommittedDate}
	if a := x.Author; a != nil {
		cm.AuthorName = plain(string(a.Name), 256)
		if a.User != nil {
			cm.Author = a.User.Login
		}
	}
	if r := x.StatusCheckRollup; r != nil {
		cm.Checks = rollupState(r.State)
		var n model.CheckCounts
		for _, sc := range append(r.Contexts.CheckRuns, r.Contexts.Statuses...) {
			countCheck(&n, sc)
		}
		cm.Cancelled = cm.Checks == "failure" && n.Cancelled > 0 && n.Failed == n.Cancelled
	}
	return cm
}

// Commits are a pull request's newest 100 commits, oldest first (as
// GitHub lists them), its first on its own, for the commit trail's
// oldest (ADR 0137), and how many it has.
func (c *Client) Commits(ctx context.Context, repo string, number int) (model.GitHubCommits, error) {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return model.GitHubCommits{}, err
	}
	var data struct {
		Repository *struct {
			PullRequest *struct {
				Commits struct {
					TotalCount int          `json:"totalCount"`
					Nodes      []commitNode `json:"nodes"`
				} `json:"commits"`
				First struct {
					Nodes []commitNode `json:"nodes"`
				} `json:"first"`
			} `json:"pullRequest"`
		} `json:"repository"`
	}
	vars := map[string]any{"owner": owner, "name": name, "number": number}
	ask := func(counts bool) string {
		if counts {
			return strings.ReplaceAll(commitsQuery, "COUNTS", countsField)
		}
		return strings.ReplaceAll(commitsQuery, "COUNTS", "")
	}
	if err := c.countedQuery(ctx, ask, vars, &data); err != nil {
		return model.GitHubCommits{}, err
	}
	if data.Repository == nil || data.Repository.PullRequest == nil {
		return model.GitHubCommits{}, ErrNotFound
	}
	p := data.Repository.PullRequest
	out := model.GitHubCommits{Total: p.Commits.TotalCount, Newest: make([]model.GitHubCommit, 0, len(p.Commits.Nodes))}
	for _, n := range p.Commits.Nodes {
		out.Newest = append(out.Newest, n.commit())
	}
	if f := p.First.Nodes; len(f) > 0 {
		out.First = f[0].commit()
	}
	return out, nil
}

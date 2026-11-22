package githubapi

import (
	"context"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// commitsQuery asks for a pull request's newest 100 commits, and its
// first (the alias first), which the newest 100 leave out of a longer
// one: one query of about a point, where more would page (GitHub allows
// 250 at most).
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
  statusCheckRollup { state }
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
			State string `json:"state"`
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
	}
	return cm
}

// Commits are a pull request's newest 100 commits, oldest first (as
// GitHub lists them), and how many it has. One with more has its first
// commit put before them, so the oldest listed is always its first, as
// the commit trail shows it (ADR 0137).
func (c *Client) Commits(ctx context.Context, repo string, number int) ([]model.GitHubCommit, int, error) {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return nil, 0, err
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
	if _, err := c.graphql(ctx, commitsQuery, vars, &data); err != nil {
		return nil, 0, err
	}
	if data.Repository == nil || data.Repository.PullRequest == nil {
		return nil, 0, ErrNotFound
	}
	p := data.Repository.PullRequest
	cs := p.Commits
	out := make([]model.GitHubCommit, 0, len(cs.Nodes)+1)
	if f := p.First.Nodes; cs.TotalCount > len(cs.Nodes) && len(f) > 0 && len(cs.Nodes) > 0 && f[0].Commit.OID != cs.Nodes[0].Commit.OID {
		out = append(out, f[0].commit())
	}
	for _, n := range cs.Nodes {
		out = append(out, n.commit())
	}
	return out, cs.TotalCount, nil
}

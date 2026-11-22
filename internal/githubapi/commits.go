package githubapi

import (
	"context"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// commitsQuery asks for a pull request's newest 100 commits: one query
// of about a point, where more would page (GitHub allows 250 at most).
const commitsQuery = `query Commits($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      commits(last: 100) { totalCount nodes { commit {
        oid messageHeadline committedDate
        author { name user { login } }
        statusCheckRollup { state }
      } } }
    }
  }
}`

// Commits are a pull request's newest 100 commits, oldest first (as
// GitHub lists them), and how many it has.
func (c *Client) Commits(ctx context.Context, repo string, number int) ([]model.GitHubCommit, int, error) {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return nil, 0, err
	}
	var data struct {
		Repository *struct {
			PullRequest *struct {
				Commits struct {
					TotalCount int `json:"totalCount"`
					Nodes      []struct {
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
					} `json:"nodes"`
				} `json:"commits"`
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
	cs := data.Repository.PullRequest.Commits
	out := make([]model.GitHubCommit, 0, len(cs.Nodes))
	for _, n := range cs.Nodes {
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
		out = append(out, cm)
	}
	return out, cs.TotalCount, nil
}

package githubapi

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/mdwrite"
	"github.com/afrase/nushi/internal/model"
)

// pullRow and issueRow are what a list shows of a pull request and an
// issue (a GraphQL document may hold only the fragments it uses).
const pullRow = `
fragment PullRow on PullRequest {
  id number title url state isDraft updatedAt
  author { login }
  repository { nameWithOwner }
  reviewDecision
  totalCommentsCount
  commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
  reviewThreads(first: 100) { nodes { isResolved } }
}`

const issueRow = `
fragment IssueRow on Issue {
  id number title url state updatedAt
  author { login }
  repository { nameWithOwner }
  commentCount: comments { totalCount }
}`

// row decodes either fragment.
type row struct {
	Typename   string    `json:"__typename"`
	ID         string    `json:"id"`
	Number     int       `json:"number"`
	Title      string    `json:"title"`
	URL        string    `json:"url"`
	State      string    `json:"state"`
	IsDraft    bool      `json:"isDraft"`
	UpdatedAt  time.Time `json:"updatedAt"`
	Author     *login    `json:"author"`
	Repository struct {
		NameWithOwner string `json:"nameWithOwner"`
	} `json:"repository"`
	ReviewDecision     string `json:"reviewDecision"`
	TotalCommentsCount int    `json:"totalCommentsCount"`
	Commits            struct {
		Nodes []struct {
			Commit struct {
				StatusCheckRollup *struct {
					State string `json:"state"`
				} `json:"statusCheckRollup"`
			} `json:"commit"`
		} `json:"nodes"`
	} `json:"commits"`
	ReviewThreads struct {
		Nodes []struct {
			IsResolved bool `json:"isResolved"`
		} `json:"nodes"`
	} `json:"reviewThreads"`
	CommentCount struct {
		TotalCount int `json:"totalCount"`
	} `json:"commentCount"`
}

type login struct {
	Login    string `json:"login"`
	Typename string `json:"__typename"`
}

func (l *login) name() string {
	if l == nil {
		return "ghost" // a deleted account, as GitHub shows it
	}
	return l.Login
}

func (r row) item(host string) model.GitHubItem {
	it := model.GitHubItem{
		Host: host, Repo: r.Repository.NameWithOwner, Number: r.Number,
		ID: r.ID, Pull: r.Typename != "Issue", Title: r.Title, URL: webURL(r.URL), State: strings.ToLower(r.State),
		Draft: r.IsDraft, Author: r.Author.name(), Updated: r.UpdatedAt, Review: strings.ToLower(r.ReviewDecision),
		Comments: r.TotalCommentsCount + r.CommentCount.TotalCount,
	}
	if n := r.Commits.Nodes; len(n) > 0 && n[0].Commit.StatusCheckRollup != nil {
		it.Checks = rollupState(n[0].Commit.StatusCheckRollup.State)
	}
	for _, t := range r.ReviewThreads.Nodes {
		if !t.IsResolved {
			it.Unresolved++
		}
	}
	return it
}

// rollupState is a rollup's state as Nushi says it: "success", "failure"
// (GitHub's FAILURE and ERROR) or "pending" (PENDING and EXPECTED).
func rollupState(s string) string {
	switch s {
	case "SUCCESS":
		return "success"
	case "FAILURE", "ERROR":
		return "failure"
	}
	return "pending"
}

// Inbox is what the GitHub view lists: pull requests whose review is
// asked of me (or my teams, with InboxFilter.Teams), my open pull
// requests, the open issues assigned to me; the latest 50 of each, by
// when they changed.
type Inbox struct {
	Review, Mine, Assigned []model.GitHubItem
	// Totals are how many each search found (more than 50 aren't listed).
	ReviewTotal, MineTotal, AssignedTotal int
}

// InboxFilter is which inbox: only Repos' (owner/name; none for all),
// and whether Review requested has pull requests asked of a team of mine
// too (else only those asking me by name).
type InboxFilter struct {
	Repos []string
	Teams bool
}

const inboxQuery = `query Inbox($review: String!, $mine: String!, $assigned: String!) {
  review: search(type: ISSUE, query: $review, first: 50) { issueCount nodes { __typename ...PullRow } }
  mine: search(type: ISSUE, query: $mine, first: 50) { issueCount nodes { __typename ...PullRow } }
  assigned: search(type: ISSUE, query: $assigned, first: 50) { issueCount nodes { __typename ...IssueRow } }
}` + pullRow + issueRow

// repoQualifiers is how many repositories a search names (repo:o/n
// each, any of them); past it, Inbox searches everywhere and keeps
// theirs, so the query stays under GitHub's 256 characters.
const repoQualifiers = 6

// inboxSearches are the inbox's three searches: review-requested:@me is
// me or a team of mine, user-review-requested:@me me by name.
func inboxSearches(f InboxFilter) map[string]any {
	open := "is:open archived:false sort:updated-desc"
	if len(f.Repos) <= repoQualifiers {
		for _, r := range f.Repos {
			open = open + " repo:" + r
		}
	}
	review := "user-review-requested:@me"
	if f.Teams {
		review = "review-requested:@me"
	}
	return map[string]any{
		"review":   "is:pr " + open + " " + review,
		"mine":     "is:pr " + open + " author:@me",
		"assigned": "is:issue " + open + " assignee:@me",
	}
}

// Inbox runs the three searches as one query (about two points).
func (c *Client) Inbox(ctx context.Context, f InboxFilter) (Inbox, error) {
	type search struct {
		IssueCount int   `json:"issueCount"`
		Nodes      []row `json:"nodes"`
	}
	var data struct{ Review, Mine, Assigned search }
	if _, err := c.graphql(ctx, inboxQuery, inboxSearches(f), &data); err != nil {
		return Inbox{}, err
	}
	items := func(s search) []model.GitHubItem {
		var out []model.GitHubItem
		for _, r := range s.Nodes {
			if r.ID != "" && (len(f.Repos) == 0 || slices.Contains(f.Repos, r.Repository.NameWithOwner)) { // not a node of another type
				out = append(out, r.item(c.Host))
			}
		}
		return out
	}
	return Inbox{Review: items(data.Review), Mine: items(data.Mine), Assigned: items(data.Assigned),
		ReviewTotal: data.Review.IssueCount, MineTotal: data.Mine.IssueCount, AssignedTotal: data.Assigned.IssueCount}, nil
}

const statusQuery = `query Status($ids: [ID!]!) {
  nodes(ids: $ids) { __typename ...PullRow ...IssueRow }
}` + pullRow + issueRow

// Status is how pull requests and issues are now, by their node ids, in
// one query (at most 100). One GitHub can't find (deleted, or no longer
// visible) is left out.
func (c *Client) Status(ctx context.Context, ids []string) (map[string]model.GitHubItem, error) {
	if len(ids) > 100 {
		return nil, errors.New("at most 100 at a time")
	}
	var data struct {
		Nodes []*row `json:"nodes"`
	}
	if _, err := c.graphql(ctx, statusQuery, map[string]any{"ids": ids}, &data); err != nil {
		return nil, err
	}
	out := map[string]model.GitHubItem{}
	for _, r := range data.Nodes {
		if r != nil && r.ID != "" {
			out[r.ID] = r.item(c.Host)
		}
	}
	return out, nil
}

// repoRE is a repository's owner/name, as GitHub allows them.
var repoRE = regexp.MustCompile(`^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})/[A-Za-z0-9._-]{1,100}$`)

// SplitRepo checks a repository's owner/name and splits it.
func SplitRepo(repo string) (owner, name string, err error) {
	if !repoRE.MatchString(repo) || strings.HasSuffix(repo, "/.") || strings.HasSuffix(repo, "/..") {
		return "", "", fmt.Errorf("%q isn't a repository's owner/name", repo)
	}
	owner, name, _ = strings.Cut(repo, "/")
	return owner, name, nil
}

// webURL is an address from GitHub's answer kept only if it's http or
// https: a check's or a status's is whatever the app or token that posted
// it said (any scheme), and none is trusted to open on the Mac. Others
// are blanked before they leave the daemon.
func webURL(u string) string {
	if !mdwrite.SafeImage(u) { // http and https, no mailto
		return ""
	}
	return u
}

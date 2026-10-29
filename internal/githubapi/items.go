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
	// Older are how many more each search finds without InboxFilter.Days
	// (0 when it has none, or the section is Wide).
	ReviewOlder, MineOlder, AssignedOlder int
}

// InboxFilter is which inbox: only Repos' (owner/name; none for all),
// and whether Review requested has pull requests asked of a team of mine
// too (else only those asking me by name); only what changed in the last
// Days (0 for any time), except the sections named in Wide ("review",
// "mine", "assigned"); never Hide's repositories (owner/name) or owners
// (a user's or an organization's name); only Owners' when any are named.
type InboxFilter struct {
	Repos  []string
	Teams  bool
	Days   int
	Hide   []string
	Owners []string
	Wide   []string
}

// sections are the inbox's sections, as InboxFilter.Wide names them.
var sections = []string{"review", "mine", "assigned"}

// ownerRE is a user's or an organization's name, as GitHub allows them.
var ownerRE = regexp.MustCompile(`^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$`)

// Check refuses a filter whose names could be anything else in a search:
// every repository must be owner/name and every owner a name, in
// GitHub's characters, so none can add a qualifier of its own.
func (f InboxFilter) Check() error {
	for _, r := range f.Repos {
		if _, _, err := SplitRepo(r); err != nil {
			return err
		}
	}
	for _, h := range f.Hide {
		if _, _, err := SplitRepo(h); err != nil && !ownerRE.MatchString(h) {
			return fmt.Errorf("%q isn't a repository or an owner", h)
		}
	}
	for _, o := range f.Owners {
		if !ownerRE.MatchString(o) {
			return fmt.Errorf("%q isn't a user's or an organization's name", o)
		}
	}
	if len(f.Owners) > maxOwners {
		return fmt.Errorf("at most %d owners", maxOwners)
	}
	for _, w := range f.Wide {
		if !slices.Contains(sections, w) {
			return fmt.Errorf("%q isn't a section of the inbox", w)
		}
	}
	if f.Days < 0 {
		return errors.New("a negative number of days")
	}
	return nil
}

// shows is whether the filter lets a repository's item in: the daemon's
// own check for what the search couldn't say (past repoQualifiers or
// hideQualifiers).
func (f InboxFilter) shows(repo string) bool {
	owner, _, _ := strings.Cut(repo, "/")
	return (len(f.Repos) == 0 || slices.Contains(f.Repos, repo)) &&
		!slices.Contains(f.Hide, repo) && !slices.Contains(f.Hide, owner) &&
		(len(f.Owners) == 0 || slices.Contains(f.Owners, owner))
}

// narrowed is the filter without the repositories and owners it both
// names and hides (GitHub drops repo:a/b given -repo:a/b too, and finds
// everyone's), and whether anything is left to search.
func (f InboxFilter) narrowed() (InboxFilter, bool) {
	keep := func(names []string) []string {
		var out []string
		for _, n := range names {
			owner, _, _ := strings.Cut(n, "/")
			if !slices.Contains(f.Hide, n) && !slices.Contains(f.Hide, owner) {
				out = append(out, n)
			}
		}
		return out
	}
	n := f
	n.Repos, n.Owners = keep(f.Repos), keep(f.Owners)
	n.Hide = slices.DeleteFunc(slices.Clone(f.Hide), func(h string) bool {
		return slices.Contains(f.Repos, h) || slices.Contains(f.Owners, h)
	})
	return n, (len(f.Repos) == 0 || len(n.Repos) > 0) && (len(f.Owners) == 0 || len(n.Owners) > 0)
}

const inboxSearch = `
  review: search(type: ISSUE, query: $review, first: 50) { issueCount nodes { __typename ...PullRow } }
  mine: search(type: ISSUE, query: $mine, first: 50) { issueCount nodes { __typename ...PullRow } }
  assigned: search(type: ISSUE, query: $assigned, first: 50) { issueCount nodes { __typename ...IssueRow } }`

const inboxQuery = `query Inbox($review: String!, $mine: String!, $assigned: String!) {` + inboxSearch + `
}` + pullRow + issueRow

// inboxDatedQuery also counts each search without its date: three
// searches of no rows, which cost nothing more (the query's cost stays 1
// to 2 points).
const inboxDatedQuery = `query Inbox($review: String!, $mine: String!, $assigned: String!, $reviewAll: String!, $mineAll: String!, $assignedAll: String!) {` + inboxSearch + `
  reviewAll: search(type: ISSUE, query: $reviewAll, first: 0) { issueCount }
  mineAll: search(type: ISSUE, query: $mineAll, first: 0) { issueCount }
  assignedAll: search(type: ISSUE, query: $assignedAll, first: 0) { issueCount }
}` + pullRow + issueRow

// repoQualifiers is how many repositories a search names (repo:o/n
// each, any of them); past it, Inbox searches everywhere and keeps
// theirs. hideQualifiers is how many it leaves out (-repo:, -user:);
// past it, the daemon leaves the rest out (they then take places of the
// 50). Qualifiers don't count toward GitHub's 256 characters: 120 were
// tried. maxOwners is how many owners it may be limited to (user:, any
// of them).
const (
	repoQualifiers = 6
	hideQualifiers = 50
	maxOwners      = 10
)

// inboxSearches are the inbox's three searches (and, with Days, each
// without its date: "reviewAll"…), today being the day Days counts back
// from: review-requested:@me is me or a team of mine,
// user-review-requested:@me me by name. Every name in them was checked
// (InboxFilter.Check).
func inboxSearches(f InboxFilter, today time.Time) map[string]any {
	q := []string{"is:open", "archived:false", "sort:updated-desc"}
	if len(f.Repos) <= repoQualifiers {
		for _, r := range f.Repos {
			q = append(q, "repo:"+r)
		}
	}
	for _, o := range f.Owners {
		q = append(q, "user:"+o)
	}
	for i, h := range f.Hide {
		if i == hideQualifiers {
			break
		}
		if strings.Contains(h, "/") {
			q = append(q, "-repo:"+h)
		} else {
			q = append(q, "-user:"+h)
		}
	}
	open := strings.Join(q, " ")
	review := "user-review-requested:@me"
	if f.Teams {
		review = "review-requested:@me"
	}
	all := map[string]string{
		"review":   "is:pr " + open + " " + review,
		"mine":     "is:pr " + open + " author:@me",
		"assigned": "is:issue " + open + " assignee:@me",
	}
	out := map[string]any{}
	for name, s := range all {
		out[name] = s
		if f.Days > 0 {
			out[name+"All"] = s
			if !slices.Contains(f.Wide, name) {
				since := today.UTC().AddDate(0, 0, -f.Days).Format(time.DateOnly)
				out[name] = s + " updated:>=" + since
			}
		}
	}
	return out
}

// Inbox runs the three searches as one query (about two points).
func (c *Client) Inbox(ctx context.Context, f InboxFilter) (Inbox, error) {
	if err := f.Check(); err != nil {
		return Inbox{}, err
	}
	type search struct {
		IssueCount int   `json:"issueCount"`
		Nodes      []row `json:"nodes"`
	}
	var data struct{ Review, Mine, Assigned, ReviewAll, MineAll, AssignedAll search }
	f, left := f.narrowed()
	if !left {
		return Inbox{}, nil // every repository or owner asked for is hidden
	}
	query := inboxQuery
	if f.Days > 0 {
		query = inboxDatedQuery
	}
	if _, err := c.graphql(ctx, query, inboxSearches(f, time.Now()), &data); err != nil {
		return Inbox{}, err
	}
	items := func(s search) []model.GitHubItem {
		var out []model.GitHubItem
		for _, r := range s.Nodes {
			if r.ID != "" && f.shows(r.Repository.NameWithOwner) { // not a node of another type
				out = append(out, r.item(c.Host))
			}
		}
		return out
	}
	older := func(dated, all search) int {
		if f.Days == 0 {
			return 0
		}
		return max(0, all.IssueCount-dated.IssueCount)
	}
	return Inbox{Review: items(data.Review), Mine: items(data.Mine), Assigned: items(data.Assigned),
		ReviewTotal: data.Review.IssueCount, MineTotal: data.Mine.IssueCount, AssignedTotal: data.Assigned.IssueCount,
		ReviewOlder: older(data.Review, data.ReviewAll), MineOlder: older(data.Mine, data.MineAll),
		AssignedOlder: older(data.Assigned, data.AssignedAll)}, nil
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

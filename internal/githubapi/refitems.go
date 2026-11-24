package githubapi

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// MaxItems is how many pull requests and issues Items asks for in one
// query (ADR 0117: about a point).
const MaxItems = 50

// itemPull and itemIssue are what a chip, a row, the inbox and the
// transcript's card show of a pull request and an issue, and the head of
// one whole (ADR 0117): every read of one spreads them (withItems).
// sizeFields are a pull request's size, branches and merge state, which
// the inbox doesn't ask: its rows show none of them, and GitHub works a
// merge state out for each pull request asked. countsField is the checks
// counted by state, which only Items asks for: an old Enterprise server
// refuses it, and is asked again without it (noCounts). An issue's
// comments are counted under an alias, as Issue asks its comments with
// other arguments (docs/facts/github.md).
const (
	sizeFields  = `additions deletions changedFiles mergeStateStatus baseRefName headRefName`
	countsField = `contexts(first: 0) { checkRunCountsByState { state count } statusContextCountsByState { state count } }`
	itemPull    = `
fragment ItemPull on PullRequest {
  id number title url state isDraft createdAt updatedAt
  author { login }
  repository { nameWithOwner }
  SIZE
  reviewDecision totalCommentsCount
  commits(last: 1) { nodes { commit { oid statusCheckRollup { state COUNTS } } } }
  reviewThreads(first: 100) { nodes { isResolved } }
}`
	itemIssue = `
fragment ItemIssue on Issue {
  id number title url state stateReason createdAt updatedAt
  author { login }
  repository { nameWithOwner }
  commentCount: comments { totalCount }
}`
)

// detail is how much of a pull request a read asks beyond its row.
type detail int

const (
	rowOnly detail = iota // what a list's row shows (the inbox)
	sized                 // and its size, branches and merge state (Pull)
	counted               // and its checks counted by state (Items)
)

// withItems is a query with the item fragments it spreads after it (a
// GraphQL document may hold only the fragments it uses), ItemPull with
// as much as d asks.
func withItems(query string, d detail) string {
	if strings.Contains(query, "...ItemPull") {
		size, counts := "", ""
		if d >= sized {
			size = sizeFields
		}
		if d == counted {
			counts = countsField
		}
		query += strings.NewReplacer("SIZE", size, "COUNTS", counts).Replace(itemPull)
	}
	if strings.Contains(query, "...ItemIssue") {
		query += itemIssue
	}
	return query
}

// itemNode decodes either fragment.
type itemNode struct {
	Typename           string    `json:"__typename"`
	ID                 string    `json:"id"`
	Number             int       `json:"number"`
	Title              text      `json:"title"`
	URL                string    `json:"url"`
	State              string    `json:"state"`
	StateReason        string    `json:"stateReason"`
	IsDraft            bool      `json:"isDraft"`
	CreatedAt          time.Time `json:"createdAt"`
	UpdatedAt          time.Time `json:"updatedAt"`
	Author             *login    `json:"author"`
	Additions          int       `json:"additions"`
	Deletions          int       `json:"deletions"`
	ChangedFiles       int       `json:"changedFiles"`
	MergeStateStatus   string    `json:"mergeStateStatus"`
	BaseRefName        string    `json:"baseRefName"`
	HeadRefName        string    `json:"headRefName"`
	ReviewDecision     string    `json:"reviewDecision"`
	TotalCommentsCount int       `json:"totalCommentsCount"`
	CommentCount       struct {
		TotalCount int `json:"totalCount"`
	} `json:"commentCount"`
	Repository struct {
		NameWithOwner string `json:"nameWithOwner"`
	} `json:"repository"`
	Commits struct {
		Nodes []struct {
			Commit struct {
				OID               string `json:"oid"`
				StatusCheckRollup *struct {
					State    string `json:"state"`
					Contexts struct {
						CheckRuns []stateCount `json:"checkRunCountsByState"`
						Statuses  []stateCount `json:"statusContextCountsByState"`
					} `json:"contexts"`
				} `json:"statusCheckRollup"`
			} `json:"commit"`
		} `json:"nodes"`
	} `json:"commits"`
	ReviewThreads struct {
		Nodes []struct {
			IsResolved bool `json:"isResolved"`
		} `json:"nodes"`
	} `json:"reviewThreads"`
}

type stateCount struct {
	State string `json:"state"`
	Count int    `json:"count"`
}

// plainTitle is a title from GitHub as one line of plain text.
func plainTitle(s text) string { return oneLine(plain(string(s), 1024)) }

// item is the node as Nushi has it, in repo (owner/name): Items passes
// the name it was asked by, the rest the node's own.
func (n itemNode) item(host, repo string) model.GitHubItem {
	it := model.GitHubItem{
		Host: host, Repo: repo, Number: n.Number,
		ID: n.ID, Pull: n.Typename == "PullRequest", Title: plainTitle(n.Title), URL: webURL(n.URL),
		State: strings.ToLower(n.State), Draft: n.IsDraft, Author: shown(n.Author.name()),
		Updated: n.UpdatedAt, Created: n.CreatedAt, Review: strings.ToLower(n.ReviewDecision),
		Additions: n.Additions, Deletions: n.Deletions, ChangedFiles: n.ChangedFiles,
		MergeState: strings.ToLower(n.MergeStateStatus), StateReason: strings.ToLower(n.StateReason),
		Base: n.BaseRefName, Head: n.HeadRefName,
		Comments: n.TotalCommentsCount + n.CommentCount.TotalCount,
	}
	if c := n.Commits.Nodes; len(c) > 0 && c[0].Commit.StatusCheckRollup != nil {
		r := c[0].Commit.StatusCheckRollup
		it.Checks = rollupState(r.State)
		it.ChecksOID = c[0].Commit.OID // which commit they're of (ADR 0138)
		for _, sc := range append(r.Contexts.CheckRuns, r.Contexts.Statuses...) {
			countCheck(&it.CheckCounts, sc)
		}
	}
	for _, t := range n.ReviewThreads.Nodes {
		if !t.IsResolved {
			it.Unresolved++
		}
	}
	return it
}

// countCheck adds a state's count to the counts: a check run's
// (CheckRunState and CheckConclusionState) or a commit status's
// (StatusState), in the rollup's upper case or Nushi's lower, by KindOf.
func countCheck(c *model.CheckCounts, sc stateCount) {
	switch KindOf(strings.ToLower(sc.State)) {
	case CheckPassed:
		c.Passed += sc.Count
	case CheckFailed:
		c.Failed += sc.Count
	case CheckSkipped:
		c.Skipped += sc.Count
	case CheckRunning:
		c.Running += sc.Count
	}
}

// Items are pull requests and issues by their numbers, on this client's
// host, in one GraphQL query (MaxItems at most): each repository an alias
// and each item one under it. One GitHub can't find for the token (a
// private repository, or none: GitHub doesn't say which) is unseen; the
// rest still answer.
func (c *Client) Items(ctx context.Context, refs []model.GitHubRef) ([]model.GitHubItem, []model.GitHubRef, error) {
	if len(refs) == 0 {
		return nil, nil, nil
	}
	if len(refs) > MaxItems {
		return nil, nil, fmt.Errorf("at most %d at a time", MaxItems)
	}
	type at struct{ repo, item string }
	repos := map[string]string{} // owner/name in lower case to its alias
	var order []string
	where := make([]at, len(refs))
	vars := map[string]any{}
	var params []string
	byRepo := map[string][]string{}
	for i, r := range refs {
		owner, name, err := SplitRepo(r.Repo)
		if err != nil || r.Number <= 0 {
			return nil, nil, fmt.Errorf("%s#%d isn't a pull request's or an issue's number", r.Repo, r.Number)
		}
		key := strings.ToLower(r.Repo)
		alias, ok := repos[key]
		if !ok {
			alias = fmt.Sprintf("r%d", len(repos))
			repos[key] = alias
			order = append(order, key)
			vars[alias+"o"], vars[alias+"n"] = owner, name
			params = append(params, fmt.Sprintf("$%so: String!, $%sn: String!", alias, alias))
		}
		item := fmt.Sprintf("i%d", i)
		vars[item] = r.Number
		params = append(params, fmt.Sprintf("$%s: Int!", item))
		where[i] = at{alias, item}
		byRepo[key] = append(byRepo[key], fmt.Sprintf("    %s: issueOrPullRequest(number: $%s) { __typename ...ItemPull ...ItemIssue }", item, item))
	}
	var b strings.Builder
	b.WriteString("query Items(" + strings.Join(params, ", ") + ") {\n")
	for _, key := range order {
		alias := repos[key]
		fmt.Fprintf(&b, "  %s: repository(owner: $%so, name: $%sn) {\n%s\n  }\n", alias, alias, alias, strings.Join(byRepo[key], "\n"))
	}
	b.WriteString("}")
	query := b.String()
	var data map[string]map[string]*itemNode
	err := c.itemsQuery(ctx, query, vars, &data)
	if err != nil {
		return nil, nil, err
	}
	var items []model.GitHubItem
	var unseen []model.GitHubRef
	for i, r := range refs {
		var n *itemNode
		if repo := data[where[i].repo]; repo != nil {
			n = repo[where[i].item]
		}
		if n == nil || n.ID == "" {
			unseen = append(unseen, model.GitHubRef{Host: c.Host, Repo: r.Repo, Number: r.Number})
			continue
		}
		items = append(items, n.item(c.Host, r.Repo))
	}
	return items, unseen, nil
}

// itemsQuery runs Items' query, without the checks' counts on a host that
// refused them (remembered for the client).
func (c *Client) itemsQuery(ctx context.Context, query string, vars map[string]any, out any) error {
	if !c.noCounts.Load() {
		_, err := c.graphql(ctx, withItems(query, counted), vars, out)
		var api *APIError
		if err == nil || !errors.As(err, &api) || !refusedCounts(api.Message) {
			return err
		}
		c.noCounts.Store(true)
		c.log.Info("this server refuses check counts: asked without them")
	}
	_, err := c.graphql(ctx, withItems(query, sized), vars, out)
	return err
}

// refusedCounts says GitHub's errors are a server not knowing the checks'
// counts (an Enterprise server older than them).
func refusedCounts(msg string) bool {
	return strings.Contains(msg, "CountsByState") || strings.Contains(msg, "contexts")
}

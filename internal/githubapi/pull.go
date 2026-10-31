package githubapi

import (
	"cmp"
	"context"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
)

const threadFields = `
fragment Thread on PullRequestReviewThread {
  id path line startLine originalLine originalStartLine diffSide subjectType
  isOutdated isResolved viewerCanReply viewerCanResolve viewerCanUnresolve
  comments(first: 50) { nodes { id url author { login __typename } authorAssociation body createdAt } }
}`

const pullQuery = `query PullRequest($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      ...PullRow
      body authorAssociation baseRefName headRefName baseRefOid headRefOid isCrossRepository
      headRepository { nameWithOwner }
      mergeable mergeStateStatus additions deletions changedFiles viewerCanUpdate
      ` + mergeFields + `
      commitCount: commits { totalCount }
      reviewRequests(first: 30) { nodes { asCodeOwner requestedReviewer { __typename ... on User { login } ... on Bot { login } ... on Mannequin { login } ... on Team { slug } } } }
      latestReviews(first: 30) { nodes { author { login } state } }
      comments(last: 100) { nodes { id url author { login __typename } authorAssociation body createdAt } }
      reviews(last: 100) { nodes { id url author { login __typename } authorAssociation body state submittedAt commit { oid } } }
      pending: reviews(first: 1, states: PENDING) { nodes { id comments { totalCount } } }
      threads: reviewThreads(first: 100) { pageInfo { hasNextPage endCursor } nodes { ...Thread } }
      last: commits(last: 1) { nodes { commit { statusCheckRollup { contexts(first: 100) { nodes {
        __typename
        ... on CheckRun { databaseId name status conclusion detailsUrl title summary startedAt completedAt
          isRequired(pullRequestNumber: $number)
          checkSuite { app { name } workflowRun { workflow { name } } }
          annotations(first: 10) { nodes { path title message annotationLevel location { start { line } end { line } } } } }
        ... on StatusContext { context state targetUrl description createdAt isRequired(pullRequestNumber: $number) }
      } } } } } }
    }
  }
}` + pullRow + threadFields

const threadsQuery = `query Threads($id: ID!, $after: String!) {
  node(id: $id) { ... on PullRequest {
    threads: reviewThreads(first: 100, after: $after) { pageInfo { hasNextPage endCursor } nodes { ...Thread } }
  } }
}` + threadFields

type said struct {
	ID                string    `json:"id"`
	URL               string    `json:"url"`
	Author            *login    `json:"author"`
	AuthorAssociation string    `json:"authorAssociation"`
	Body              string    `json:"body"`
	CreatedAt         time.Time `json:"createdAt"`
	State             string    `json:"state"`
	SubmittedAt       time.Time `json:"submittedAt"`
	Commit            *struct {
		OID string `json:"oid"`
	} `json:"commit"`
}

func (s said) comment() model.GitHubComment {
	return model.GitHubComment{ID: s.ID, Author: s.Author.name(), Association: s.AuthorAssociation, Body: Markdown(s.Body),
		URL: webURL(s.URL), Bot: s.Author != nil && s.Author.Typename == "Bot", Created: cmp.Or(s.SubmittedAt, s.CreatedAt),
		Review: strings.ToLower(s.State), Commit: s.commit()}
}

func (s said) commit() string {
	if s.Commit == nil {
		return ""
	}
	return s.Commit.OID
}

type thread struct {
	ID                 string `json:"id"`
	Path               string `json:"path"`
	Line               int    `json:"line"`
	StartLine          int    `json:"startLine"`
	OriginalLine       int    `json:"originalLine"`
	OriginalStartLine  int    `json:"originalStartLine"`
	DiffSide           string `json:"diffSide"`
	SubjectType        string `json:"subjectType"`
	IsOutdated         bool   `json:"isOutdated"`
	IsResolved         bool   `json:"isResolved"`
	ViewerCanReply     bool   `json:"viewerCanReply"`
	ViewerCanResolve   bool   `json:"viewerCanResolve"`
	ViewerCanUnresolve bool   `json:"viewerCanUnresolve"`
	Comments           struct {
		Nodes []said `json:"nodes"`
	} `json:"comments"`
}

type threadPage struct {
	PageInfo struct {
		HasNextPage bool   `json:"hasNextPage"`
		EndCursor   string `json:"endCursor"`
	} `json:"pageInfo"`
	Nodes []thread `json:"nodes"`
}

func (t thread) thread() model.GitHubThread {
	out := model.GitHubThread{ID: t.ID, Path: t.Path, Side: strings.ToLower(t.DiffSide), Line: t.Line, StartLine: t.StartLine,
		OriginalLine: t.OriginalLine, OriginalStartLine: t.OriginalStartLine, OnFile: t.SubjectType == "FILE",
		Outdated: t.IsOutdated, Resolved: t.IsResolved, CanReply: t.ViewerCanReply, CanResolve: t.ViewerCanResolve, CanUnresolve: t.ViewerCanUnresolve}
	for _, c := range t.Comments.Nodes {
		out.Comments = append(out.Comments, c.comment())
	}
	return out
}

type checkNode struct {
	Typename    string    `json:"__typename"`
	DatabaseID  int64     `json:"databaseId"`
	Name        string    `json:"name"`
	Status      string    `json:"status"`
	Conclusion  string    `json:"conclusion"`
	DetailsURL  string    `json:"detailsUrl"`
	Title       string    `json:"title"`
	Summary     string    `json:"summary"`
	StartedAt   time.Time `json:"startedAt"`
	CompletedAt time.Time `json:"completedAt"`
	IsRequired  bool      `json:"isRequired"`
	CheckSuite  struct {
		App *struct {
			Name string `json:"name"`
		} `json:"app"`
		WorkflowRun *struct {
			Workflow struct {
				Name string `json:"name"`
			} `json:"workflow"`
		} `json:"workflowRun"`
	} `json:"checkSuite"`
	Annotations struct {
		Nodes []struct {
			Path            string `json:"path"`
			Title           string `json:"title"`
			Message         string `json:"message"`
			AnnotationLevel string `json:"annotationLevel"`
			Location        struct {
				Start struct {
					Line int `json:"line"`
				} `json:"start"`
				End struct {
					Line int `json:"line"`
				} `json:"end"`
			} `json:"location"`
		} `json:"nodes"`
	} `json:"annotations"`
	// A commit status's.
	Context     string    `json:"context"`
	State       string    `json:"state"`
	TargetURL   string    `json:"targetUrl"`
	Description string    `json:"description"`
	CreatedAt   time.Time `json:"createdAt"`
}

func (n checkNode) check() model.GitHubCheck {
	if n.Typename == "StatusContext" {
		state := strings.ToLower(n.State)
		if state == "expected" {
			state = "pending"
		}
		return model.GitHubCheck{Name: n.Context, State: state, URL: webURL(n.TargetURL), Summary: n.Description, Required: n.IsRequired, Started: n.CreatedAt}
	}
	c := model.GitHubCheck{ID: n.DatabaseID, Name: n.Name, State: "pending", URL: webURL(n.DetailsURL), Title: n.Title, Summary: Markdown(n.Summary),
		Required: n.IsRequired, Started: n.StartedAt, Completed: n.CompletedAt}
	if n.Status == "COMPLETED" {
		c.State = strings.ToLower(n.Conclusion)
	}
	if a := n.CheckSuite.App; a != nil {
		c.App = a.Name
	}
	if w := n.CheckSuite.WorkflowRun; w != nil {
		c.Workflow = w.Workflow.Name
	}
	for _, a := range n.Annotations.Nodes {
		c.Annotations = append(c.Annotations, model.GitHubAnnotation{Path: a.Path, Level: strings.ToLower(a.AnnotationLevel),
			Title: a.Title, Message: Brief(a.Message), Line: a.Location.Start.Line, EndLine: a.Location.End.Line})
	}
	return c
}

// Pull is a pull request whole (about two points): its header, the
// conversation, its review threads (paged past 100), and its head's
// checks.
func (c *Client) Pull(ctx context.Context, repo string, number int) (model.GitHubPull, error) {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return model.GitHubPull{}, err
	}
	var data struct {
		Repository *struct {
			PullRequest *struct {
				row
				Body              string `json:"body"`
				AuthorAssociation string `json:"authorAssociation"`
				BaseRefName       string `json:"baseRefName"`
				HeadRefName       string `json:"headRefName"`
				BaseRefOid        string `json:"baseRefOid"`
				HeadRefOid        string `json:"headRefOid"`
				IsCrossRepository bool   `json:"isCrossRepository"`
				HeadRepository    *struct {
					NameWithOwner string `json:"nameWithOwner"`
				} `json:"headRepository"`
				Mergeable        string `json:"mergeable"`
				MergeStateStatus string `json:"mergeStateStatus"`
				Additions        int    `json:"additions"`
				Deletions        int    `json:"deletions"`
				ChangedFiles     int    `json:"changedFiles"`
				ViewerCanUpdate  bool   `json:"viewerCanUpdate"`
				mergeNode
				CommitCount struct {
					TotalCount int `json:"totalCount"`
				} `json:"commitCount"`
				ReviewRequests struct {
					Nodes []struct {
						AsCodeOwner       bool `json:"asCodeOwner"`
						RequestedReviewer *struct {
							Typename string `json:"__typename"`
							Login    string `json:"login"`
							Slug     string `json:"slug"`
						} `json:"requestedReviewer"`
					} `json:"nodes"`
				} `json:"reviewRequests"`
				LatestReviews struct {
					Nodes []said `json:"nodes"`
				} `json:"latestReviews"`
				Comments struct {
					Nodes []said `json:"nodes"`
				} `json:"comments"`
				Reviews struct {
					Nodes []said `json:"nodes"`
				} `json:"reviews"`
				Pending struct {
					Nodes []struct {
						ID       string `json:"id"`
						Comments struct {
							TotalCount int `json:"totalCount"`
						} `json:"comments"`
					} `json:"nodes"`
				} `json:"pending"`
				Threads threadPage `json:"threads"`
				Last    struct {
					Nodes []struct {
						Commit struct {
							StatusCheckRollup *struct {
								Contexts struct {
									Nodes []checkNode `json:"nodes"`
								} `json:"contexts"`
							} `json:"statusCheckRollup"`
						} `json:"commit"`
					} `json:"nodes"`
				} `json:"last"`
			} `json:"pullRequest"`
		} `json:"repository"`
	}
	if _, err := c.graphql(ctx, pullQuery, map[string]any{"owner": owner, "name": name, "number": number}, &data); err != nil {
		return model.GitHubPull{}, err
	}
	if data.Repository == nil || data.Repository.PullRequest == nil {
		return model.GitHubPull{}, ErrNotFound
	}
	p := data.Repository.PullRequest
	out := model.GitHubPull{GitHubItem: p.item(c.Host), Body: Markdown(p.Body), Association: p.AuthorAssociation,
		Base: p.BaseRefName, Head: p.HeadRefName, BaseOID: p.BaseRefOid, HeadOID: p.HeadRefOid, CrossRepo: p.IsCrossRepository,
		Mergeable: strings.ToLower(p.Mergeable), MergeState: strings.ToLower(p.MergeStateStatus), Additions: p.Additions,
		Deletions: p.Deletions, ChangedFiles: p.ChangedFiles, Commits: p.CommitCount.TotalCount, CanComment: p.ViewerCanUpdate, Merge: p.merge()}
	if p.HeadRepository != nil {
		out.HeadRepo = p.HeadRepository.NameWithOwner
	}
	for _, r := range p.ReviewRequests.Nodes {
		if x := r.RequestedReviewer; x != nil {
			out.Reviewers = append(out.Reviewers, model.GitHubReviewer{Login: cmp.Or(x.Login, x.Slug), State: "requested", Team: x.Typename == "Team",
				CodeOwner: r.AsCodeOwner})
		}
	}
	for _, r := range p.LatestReviews.Nodes {
		if !slices.ContainsFunc(out.Reviewers, func(x model.GitHubReviewer) bool { return x.Login == r.Author.name() && !x.Team }) {
			out.Reviewers = append(out.Reviewers, model.GitHubReviewer{Login: r.Author.name(), State: strings.ToLower(r.State)})
		}
	}
	for _, s := range p.Comments.Nodes {
		out.Conversation = append(out.Conversation, s.comment())
	}
	for _, s := range p.Reviews.Nodes {
		if strings.TrimSpace(s.Body) != "" && s.State != "PENDING" {
			out.Conversation = append(out.Conversation, s.comment())
		}
	}
	slices.SortStableFunc(out.Conversation, func(a, b model.GitHubComment) int { return a.Created.Compare(b.Created) })
	if n := p.Pending.Nodes; len(n) > 0 {
		out.PendingReview, out.PendingComments = n[0].ID, n[0].Comments.TotalCount
	}
	page := p.Threads
	for {
		for _, t := range page.Nodes {
			out.Threads = append(out.Threads, t.thread())
		}
		if !page.PageInfo.HasNextPage || len(out.Threads) >= 1000 {
			break
		}
		var more struct {
			Node struct {
				Threads threadPage `json:"threads"`
			} `json:"node"`
		}
		if _, err := c.graphql(ctx, threadsQuery, map[string]any{"id": p.ID, "after": page.PageInfo.EndCursor}, &more); err != nil {
			return out, err
		}
		page = more.Node.Threads
	}
	if n := p.Last.Nodes; len(n) > 0 && n[0].Commit.StatusCheckRollup != nil {
		for _, x := range n[0].Commit.StatusCheckRollup.Contexts.Nodes {
			out.Runs = append(out.Runs, x.check())
		}
	}
	return out, nil
}

const issueQuery = `query Issue($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) {
      __typename ...IssueRow body authorAssociation viewerCanUpdate
      labels(first: 20) { nodes { name } }
      assignees(first: 10) { nodes { login } }
      comments(last: 100) { nodes { id url author { login __typename } authorAssociation body createdAt } }
    }
  }
}` + issueRow

// Issue is an issue whole: its text, labels, assignees and the latest
// 100 comments.
func (c *Client) Issue(ctx context.Context, repo string, number int) (model.GitHubIssue, error) {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return model.GitHubIssue{}, err
	}
	var data struct {
		Repository *struct {
			Issue *struct {
				row
				Body              string `json:"body"`
				AuthorAssociation string `json:"authorAssociation"`
				Labels            struct {
					Nodes []struct {
						Name string `json:"name"`
					} `json:"nodes"`
				} `json:"labels"`
				Assignees struct {
					Nodes []login `json:"nodes"`
				} `json:"assignees"`
				Comments struct {
					Nodes []said `json:"nodes"`
				} `json:"comments"`
			} `json:"issue"`
		} `json:"repository"`
	}
	if _, err := c.graphql(ctx, issueQuery, map[string]any{"owner": owner, "name": name, "number": number}, &data); err != nil {
		return model.GitHubIssue{}, err
	}
	if data.Repository == nil || data.Repository.Issue == nil {
		return model.GitHubIssue{}, ErrNotFound
	}
	is := data.Repository.Issue
	out := model.GitHubIssue{GitHubItem: is.item(c.Host), Body: Markdown(is.Body), Association: is.AuthorAssociation}
	for _, l := range is.Labels.Nodes {
		out.Labels = append(out.Labels, l.Name)
	}
	for _, a := range is.Assignees.Nodes {
		out.Assignees = append(out.Assignees, a.Login)
	}
	for _, s := range is.Comments.Nodes {
		out.Conversation = append(out.Conversation, s.comment())
	}
	return out, nil
}

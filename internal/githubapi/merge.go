package githubapi

import (
	"context"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// mergeFields is what a pull request's query asks for its Merge control
// (ADR 0069). All of it is single objects and scalars, which cost no points.
// The alias repo is because PullRow's repository decodes into row.
const mergeFields = `canBeRebased viewerCanMergeAsAdmin viewerCanEnableAutoMerge viewerCanDisableAutoMerge isMergeQueueEnabled
      autoMergeRequest { enabledAt mergeMethod enabledBy { login } }
      mergeQueueEntry { position state estimatedTimeToMerge enqueuer { login } }
      mergeQueue { configuration { mergeMethod } }
      baseRef { refUpdateRule { requiresConversationResolution requiresLinearHistory } }
      repo: repository { mergeCommitAllowed squashMergeAllowed rebaseMergeAllowed autoMergeAllowed deleteBranchOnMerge viewerDefaultMergeMethod viewerPermission }`

// mergeNode decodes mergeFields.
type mergeNode struct {
	CanBeRebased              bool `json:"canBeRebased"`
	ViewerCanMergeAsAdmin     bool `json:"viewerCanMergeAsAdmin"`
	ViewerCanEnableAutoMerge  bool `json:"viewerCanEnableAutoMerge"`
	ViewerCanDisableAutoMerge bool `json:"viewerCanDisableAutoMerge"`
	IsMergeQueueEnabled       bool `json:"isMergeQueueEnabled"`
	AutoMergeRequest          *struct {
		EnabledAt   time.Time `json:"enabledAt"`
		MergeMethod string    `json:"mergeMethod"`
		EnabledBy   *login    `json:"enabledBy"`
	} `json:"autoMergeRequest"`
	MergeQueueEntry *struct {
		Position             int    `json:"position"`
		State                string `json:"state"`
		EstimatedTimeToMerge int    `json:"estimatedTimeToMerge"`
		Enqueuer             *login `json:"enqueuer"`
	} `json:"mergeQueueEntry"`
	MergeQueue *struct {
		Configuration *struct {
			MergeMethod string `json:"mergeMethod"`
		} `json:"configuration"`
	} `json:"mergeQueue"`
	BaseRef *struct {
		RefUpdateRule *struct {
			RequiresConversationResolution bool `json:"requiresConversationResolution"`
			RequiresLinearHistory          bool `json:"requiresLinearHistory"`
		} `json:"refUpdateRule"`
	} `json:"baseRef"`
	Repo struct {
		MergeCommitAllowed       bool   `json:"mergeCommitAllowed"`
		SquashMergeAllowed       bool   `json:"squashMergeAllowed"`
		RebaseMergeAllowed       bool   `json:"rebaseMergeAllowed"`
		AutoMergeAllowed         bool   `json:"autoMergeAllowed"`
		DeleteBranchOnMerge      bool   `json:"deleteBranchOnMerge"`
		ViewerDefaultMergeMethod string `json:"viewerDefaultMergeMethod"`
		ViewerPermission         string `json:"viewerPermission"`
	} `json:"repo"`
}

func (n mergeNode) merge() model.GitHubMerge {
	r := n.Repo
	out := model.GitHubMerge{Default: strings.ToLower(r.ViewerDefaultMergeMethod), Bypass: n.ViewerCanMergeAsAdmin, CanRebase: n.CanBeRebased,
		AutoAllowed: r.AutoMergeAllowed, CanEnableAuto: n.ViewerCanEnableAutoMerge, CanDisableAuto: n.ViewerCanDisableAutoMerge,
		Queue: n.IsMergeQueueEnabled, DeleteBranch: r.DeleteBranchOnMerge}
	switch r.ViewerPermission {
	case "WRITE", "MAINTAIN", "ADMIN":
		out.Can = true
	}
	var linear bool
	if n.BaseRef != nil && n.BaseRef.RefUpdateRule != nil {
		linear = n.BaseRef.RefUpdateRule.RequiresLinearHistory
		out.Conversations = n.BaseRef.RefUpdateRule.RequiresConversationResolution
	}
	if r.MergeCommitAllowed && !linear {
		out.Methods = append(out.Methods, "merge")
	}
	if r.SquashMergeAllowed {
		out.Methods = append(out.Methods, "squash")
	}
	if r.RebaseMergeAllowed {
		out.Methods = append(out.Methods, "rebase")
	}
	if a := n.AutoMergeRequest; a != nil {
		out.Auto = &model.GitHubAutoMerge{By: shown(a.EnabledBy.name()), Method: strings.ToLower(a.MergeMethod), Enabled: a.EnabledAt}
	}
	if e := n.MergeQueueEntry; e != nil {
		out.Entry = &model.GitHubQueueEntry{Position: e.Position, State: strings.ToLower(e.State), By: shown(e.Enqueuer.name()), Eta: e.EstimatedTimeToMerge}
	}
	if q := n.MergeQueue; q != nil && q.Configuration != nil {
		out.QueueMethod = strings.ToLower(q.Configuration.MergeMethod)
	}
	return out
}

const mergeTextQuery = `query MergeText($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      mergeTitle: viewerMergeHeadlineText(mergeType: MERGE)
      mergeBody: viewerMergeBodyText(mergeType: MERGE)
      squashTitle: viewerMergeHeadlineText(mergeType: SQUASH)
      squashBody: viewerMergeBodyText(mergeType: SQUASH)
    }
  }
}`

// The most of a commit's text that's read from GitHub or sent back.
const (
	MaxCommitTitle = 1 << 10
	MaxCommitBody  = 64 << 10
)

// MergeText is the commit text GitHub would use, for the viewer: a merge
// commit's and a squash's. It comes from whoever wrote the title and the
// commits, bounded and without control characters.
type MergeText struct {
	MergeTitle, MergeBody, SquashTitle, SquashBody string
}

// MergeText asks what GitHub would write on the commit.
func (c *Client) MergeText(ctx context.Context, repo string, number int) (MergeText, error) {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return MergeText{}, err
	}
	var data struct {
		Repository *struct {
			PullRequest *struct {
				MergeTitle  string `json:"mergeTitle"`
				MergeBody   string `json:"mergeBody"`
				SquashTitle string `json:"squashTitle"`
				SquashBody  string `json:"squashBody"`
			} `json:"pullRequest"`
		} `json:"repository"`
	}
	if _, err := c.graphql(ctx, mergeTextQuery, map[string]any{"owner": owner, "name": name, "number": number}, &data); err != nil {
		return MergeText{}, err
	}
	if data.Repository == nil || data.Repository.PullRequest == nil {
		return MergeText{}, ErrNotFound
	}
	p := data.Repository.PullRequest
	return MergeText{MergeTitle: plain(p.MergeTitle, MaxCommitTitle), MergeBody: plain(p.MergeBody, MaxCommitBody),
		SquashTitle: plain(p.SquashTitle, MaxCommitTitle), SquashBody: plain(p.SquashBody, MaxCommitBody)}, nil
}

// MergeInput is a merge or auto-merge the user confirmed. HeadOID is the
// head the view showed: GitHub refuses when the pull request has moved on.
// Title and Body are the commit's, for "merge" and "squash"; a rebase has
// none, and a merge queue picks its own (Queue leaves all three out).
type MergeInput struct {
	Pull, HeadOID, Method, Title, Body string
	Queue                              bool
}

func (m MergeInput) vars() map[string]any {
	v := map[string]any{"pull": m.Pull, "head": m.HeadOID}
	if m.Queue {
		return v
	}
	v["method"] = strings.ToUpper(m.Method)
	if m.Method != "rebase" {
		v["title"], v["body"] = m.Title, m.Body
	}
	return v
}

const mergeMutation = `mutation Merge($pull: ID!, $head: GitObjectID!, $method: PullRequestMergeMethod!, $title: String, $body: String) {
  mergePullRequest(input: {pullRequestId: $pull, expectedHeadOid: $head, mergeMethod: $method, commitHeadline: $title, commitBody: $body}) { pullRequest { state } }
}`

const autoMutation = `mutation EnableAuto($pull: ID!, $head: GitObjectID!, $method: PullRequestMergeMethod, $title: String, $body: String) {
  enablePullRequestAutoMerge(input: {pullRequestId: $pull, expectedHeadOid: $head, mergeMethod: $method, commitHeadline: $title, commitBody: $body}) { pullRequest { id } }
}`

const noAutoMutation = `mutation DisableAuto($pull: ID!) {
  disablePullRequestAutoMerge(input: {pullRequestId: $pull}) { pullRequest { id } }
}`

const enqueueMutation = `mutation Enqueue($pull: ID!, $head: GitObjectID!) {
  enqueuePullRequest(input: {pullRequestId: $pull, expectedHeadOid: $head}) { mergeQueueEntry { id } }
}`

const dequeueMutation = `mutation Dequeue($pull: ID!) {
  dequeuePullRequest(input: {id: $pull}) { mergeQueueEntry { id } }
}`

// Merge merges a pull request, only at m.HeadOID.
func (c *Client) Merge(ctx context.Context, m MergeInput) error {
	_, err := c.graphql(ctx, mergeMutation, m.vars(), new(any))
	return err
}

// EnableAutoMerge has GitHub merge the pull request once its requirements
// are met, or add it to its merge queue (m.Queue), only at m.HeadOID.
func (c *Client) EnableAutoMerge(ctx context.Context, m MergeInput) error {
	_, err := c.graphql(ctx, autoMutation, m.vars(), new(any))
	return err
}

// DisableAutoMerge turns a pull request's auto-merge off.
func (c *Client) DisableAutoMerge(ctx context.Context, pull string) error {
	_, err := c.graphql(ctx, noAutoMutation, map[string]any{"pull": pull}, new(any))
	return err
}

// Enqueue adds a pull request to its base's merge queue, at its end (never
// GitHub's jump to the front), only at head.
func (c *Client) Enqueue(ctx context.Context, pull, head string) error {
	_, err := c.graphql(ctx, enqueueMutation, map[string]any{"pull": pull, "head": head}, new(any))
	return err
}

// Dequeue takes a pull request out of its base's merge queue.
func (c *Client) Dequeue(ctx context.Context, pull string) error {
	_, err := c.graphql(ctx, dequeueMutation, map[string]any{"pull": pull}, new(any))
	return err
}

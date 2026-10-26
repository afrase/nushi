package githubapi

import (
	"cmp"
	"context"
	"errors"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// The writes are GraphQL mutations, each one request (GitHub counts five
// points of its secondary limit for one), a second apart.

const saidFields = `{ id url author { login __typename } authorAssociation body createdAt }`

const replyMutation = `mutation Reply($thread: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $thread, body: $body}) { comment ` + saidFields + ` }
}`

// Reply adds a reply to a review thread.
func (c *Client) Reply(ctx context.Context, thread, body string) (model.GitHubComment, error) {
	var data struct {
		AddPullRequestReviewThreadReply struct {
			Comment said `json:"comment"`
		} `json:"addPullRequestReviewThreadReply"`
	}
	if _, err := c.graphql(ctx, replyMutation, map[string]any{"thread": thread, "body": body}, &data); err != nil {
		return model.GitHubComment{}, err
	}
	return data.AddPullRequestReviewThreadReply.Comment.comment(), nil
}

const resolveMutation = `mutation Resolve($thread: ID!) {
  resolveReviewThread(input: {threadId: $thread}) { thread { isResolved } }
}`

const unresolveMutation = `mutation Unresolve($thread: ID!) {
  unresolveReviewThread(input: {threadId: $thread}) { thread { isResolved } }
}`

// Resolve resolves a review thread, or unresolves it.
func (c *Client) Resolve(ctx context.Context, thread string, resolve bool) error {
	doc := resolveMutation
	if !resolve {
		doc = unresolveMutation
	}
	_, err := c.graphql(ctx, doc, map[string]any{"thread": thread}, new(any))
	return err
}

const commentMutation = `mutation Comment($subject: ID!, $body: String!) {
  addComment(input: {subjectId: $subject, body: $body}) { commentEdge { node ` + saidFields + ` } }
}`

// Comment adds a comment to a pull request's or an issue's conversation
// (subject is its node id).
func (c *Client) Comment(ctx context.Context, subject, body string) (model.GitHubComment, error) {
	var data struct {
		AddComment struct {
			CommentEdge struct {
				Node said `json:"node"`
			} `json:"commentEdge"`
		} `json:"addComment"`
	}
	if _, err := c.graphql(ctx, commentMutation, map[string]any{"subject": subject, "body": body}, &data); err != nil {
		return model.GitHubComment{}, err
	}
	return data.AddComment.CommentEdge.Node.comment(), nil
}

// Draft is a comment of a review not yet sent: on Line (from StartLine,
// if it's more than one) of Path's Side ("left" for the base, "right" for
// the head).
type Draft struct {
	Path, Side, Body string
	Line, StartLine  int
}

// Review is a review to submit: Event is "comment", "approve" or
// "request_changes".
type Review struct {
	Pull, HeadOID string // the pull request's node id, and the head the drafts are on
	// Pending is my review already pending on GitHub (made in the
	// browser), which the drafts join; "" makes one.
	Pending     string
	Event, Body string
	Drafts      []Draft
}

const reviewMutation = `mutation Review($pull: ID!, $commit: GitObjectID!, $event: PullRequestReviewEvent!, $body: String, $threads: [DraftPullRequestReviewThread]) {
  addPullRequestReview(input: {pullRequestId: $pull, commitOID: $commit, event: $event, body: $body, threads: $threads}) { pullRequestReview { id } }
}`

const threadMutation = `mutation Thread($review: ID!, $path: String!, $line: Int!, $side: DiffSide!, $startLine: Int, $startSide: DiffSide, $body: String!) {
  addPullRequestReviewThread(input: {pullRequestReviewId: $review, path: $path, line: $line, side: $side, startLine: $startLine, startSide: $startSide, body: $body}) { thread { id } }
}`

const submitMutation = `mutation Submit($review: ID!, $event: PullRequestReviewEvent!, $body: String) {
  submitPullRequestReview(input: {pullRequestReviewId: $review, event: $event, body: $body}) { pullRequestReview { id } }
}`

// SubmitReview sends a review with its drafts as threads: one mutation,
// or, when I have a review pending on GitHub, a thread each into it and
// then its submission. GitHub refuses a draft whose lines aren't in the
// diff, and an approval of my own pull request.
func (c *Client) SubmitReview(ctx context.Context, r Review) error {
	event := strings.ToUpper(r.Event)
	switch event {
	case "COMMENT", "APPROVE", "REQUEST_CHANGES":
	default:
		return errors.New("a review comments, approves or requests changes")
	}
	if event != "APPROVE" && strings.TrimSpace(r.Body) == "" && len(r.Drafts) == 0 && r.Pending == "" {
		return errors.New("an empty review")
	}
	var body any
	if r.Body != "" {
		body = r.Body
	}
	if r.Pending == "" {
		threads := make([]map[string]any, 0, len(r.Drafts))
		for _, d := range r.Drafts {
			threads = append(threads, d.vars())
		}
		_, err := c.graphql(ctx, reviewMutation, map[string]any{"pull": r.Pull, "commit": r.HeadOID, "event": event, "body": body, "threads": threads}, new(any))
		return err
	}
	for _, d := range r.Drafts {
		vars := d.vars()
		vars["review"] = r.Pending
		if _, err := c.graphql(ctx, threadMutation, vars, new(any)); err != nil {
			return err
		}
	}
	_, err := c.graphql(ctx, submitMutation, map[string]any{"review": r.Pending, "event": event, "body": body}, new(any))
	return err
}

func (d Draft) vars() map[string]any {
	side := strings.ToUpper(cmp.Or(d.Side, "right"))
	v := map[string]any{"path": d.Path, "line": d.Line, "side": side, "body": d.Body}
	if d.StartLine > 0 && d.StartLine < d.Line {
		v["startLine"], v["startSide"] = d.StartLine, side
	}
	return v
}

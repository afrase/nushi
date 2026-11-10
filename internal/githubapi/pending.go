package githubapi

import (
	"context"
	"errors"
	"fmt"
	"maps"
	"net/http"
	"strings"
	"unicode"
)

// A submission into my review pending on GitHub adds a thread a draft,
// then submits: steps GitHub can refuse one at a time. It reads the
// review first and adds only the drafts not in it yet, so sending the
// same review again after a failure never posts a comment twice, and
// nothing is ever taken back (docs/facts/github.md).

const pendingQuery = `query PendingReview($review: ID!, $after: String) {
  node(id: $review) { ... on PullRequestReview {
    state body
    comments(first: 100, after: $after) { pageInfo { hasNextPage endCursor } nodes { path line startLine body replyTo { id } } }
  } }
}`

// maxPendingPages bounds the pages of a review's comments read: past
// them the submission fails rather than guess.
const maxPendingPages = 30

// spot is where an inline comment is and what it says, as a draft and the
// comment it made compare. GitHub gives a comment no side (a thread has
// it, and a review lists comments, not threads).
type spot struct {
	path        string
	line, start int // start is 0 for one line
	body        string
}

func (d Draft) spot() spot {
	start := d.StartLine
	if start >= d.Line {
		start = 0
	}
	return spot{d.Path, d.Line, max(start, 0), sameText(d.Body)}
}

// sameText is s as compared with what GitHub gives back: its line endings
// LF, its trailing space gone.
func sameText(s string) string {
	return strings.TrimRightFunc(strings.ReplaceAll(s, "\r\n", "\n"), unicode.IsSpace)
}

// pending is my review on GitHub as read: its state (PENDING until
// submitted), its body, and how many of its inline comments are at each
// spot (replies aren't drafts of mine, so they're left out).
type pending struct {
	state, body string
	have        map[spot]int
}

// readPending reads review r whole; a review GitHub doesn't give is an
// error.
func (c *Client) readPending(ctx context.Context, r string) (pending, error) {
	p := pending{have: map[spot]int{}}
	var after any
	for range maxPendingPages {
		var data struct {
			Node *struct {
				State    string `json:"state"`
				Body     string `json:"body"`
				Comments struct {
					PageInfo struct {
						HasNextPage bool   `json:"hasNextPage"`
						EndCursor   string `json:"endCursor"`
					} `json:"pageInfo"`
					Nodes []struct {
						Path      string    `json:"path"`
						Line      *int      `json:"line"`
						StartLine *int      `json:"startLine"`
						Body      string    `json:"body"`
						ReplyTo   *struct{} `json:"replyTo"`
					} `json:"nodes"`
				} `json:"comments"`
			} `json:"node"`
		}
		partial, err := c.graphql(ctx, pendingQuery, map[string]any{"review": r, "after": after}, &data)
		switch {
		case err != nil:
			return p, err
		case len(partial) > 0: // a page with errors may be missing comments
			return p, refusal(http.StatusOK, messages(partial))
		case data.Node == nil || data.Node.State == "":
			return p, errors.New("GitHub has no such review: reload the pull request")
		}
		p.state, p.body = data.Node.State, data.Node.Body
		for _, n := range data.Node.Comments.Nodes {
			if n.ReplyTo != nil || n.Line == nil {
				continue
			}
			d := Draft{Path: n.Path, Line: *n.Line, Body: n.Body}
			if n.StartLine != nil {
				d.StartLine = *n.StartLine
			}
			p.have[d.spot()]++
		}
		page := data.Node.Comments.PageInfo
		if !page.HasNextPage {
			return p, nil
		}
		after = page.EndCursor
	}
	return p, errors.New("too many comments in the review pending on GitHub to check")
}

// missing is what of drafts the review doesn't hold yet: one comment
// stands for one draft, so twins need two.
func (p pending) missing(drafts []Draft) []Draft {
	have := maps.Clone(p.have)
	var out []Draft
	for _, d := range drafts {
		if k := d.spot(); have[k] > 0 {
			have[k]--
		} else {
			out = append(out, d)
		}
	}
	return out
}

// joinPending adds the drafts the review doesn't hold yet to my pending
// review r and submits it. A review already submitted (by an earlier
// submission GitHub didn't answer, or on github.com) is this one when it
// holds every draft and says what this one says; else nothing is added.
func (c *Client) joinPending(ctx context.Context, r Review, event string, body any) error {
	p, err := c.readPending(ctx, r.Pending)
	if err != nil {
		return fmt.Errorf("can't read your review pending on GitHub: %w", err)
	}
	missing := p.missing(r.Drafts)
	if p.state != "PENDING" {
		if len(missing) == 0 && (strings.TrimSpace(r.Body) == "" || sameText(p.body) == sameText(r.Body)) {
			return nil
		}
		return errors.New("your review was submitted on GitHub meanwhile: reload the pull request")
	}
	held := len(r.Drafts) - len(missing)
	for _, d := range missing {
		vars := d.vars()
		vars["review"] = r.Pending
		if _, err := c.graphql(ctx, threadMutation, vars, new(any)); err != nil {
			return heldPending(err, held, len(r.Drafts))
		}
		held++
	}
	_, err = c.graphql(ctx, submitMutation, map[string]any{"review": r.Pending, "event": event, "body": body}, new(any))
	return heldPending(err, held, len(r.Drafts))
}

// heldPending is err saying that n of a review's total inline comments
// are in the pending review on GitHub, so the user knows a retry is safe.
func heldPending(err error, n, total int) error {
	if err == nil || n == 0 {
		return err
	}
	what, them := fmt.Sprintf("%d of this review's %d inline comments is", n, total), "it"
	switch {
	case total == 1:
		what = "This review's inline comment is"
	case n == total:
		what, them = fmt.Sprintf("All %d of this review's inline comments are", n), "them"
	case n > 1:
		what, them = fmt.Sprintf("%d of this review's %d inline comments are", n, total), "them"
	}
	sep := ". "
	if strings.HasSuffix(err.Error(), ".") {
		sep = " "
	}
	return fmt.Errorf("%w%s%s in your pending review on GitHub now; sending the review again won't add %s twice", err, sep, what, them)
}

package githubapi

import (
	"context"
	"errors"
	"fmt"
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
    comments(first: 100, after: $after) { pageInfo { hasNextPage endCursor } nodes { path line startLine originalLine originalStartLine body replyTo { id } } }
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
// submitted), its body, and its inline comments (replies aren't drafts of
// mine, so they're left out).
type pending struct {
	state, body string
	held        []held
}

// held is an inline comment of the review at the spot it was made at and
// the one it is at now, which a push moves (zero when it left it no line).
type held struct{ made, now spot }

// readPending reads review r whole; a review GitHub doesn't give is an
// error.
func (c *Client) readPending(ctx context.Context, r string) (pending, error) {
	var p pending
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
						Path              string    `json:"path"`
						Line              *int      `json:"line"`
						StartLine         *int      `json:"startLine"`
						OriginalLine      *int      `json:"originalLine"`
						OriginalStartLine *int      `json:"originalStartLine"`
						Body              string    `json:"body"`
						ReplyTo           *struct{} `json:"replyTo"`
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
			if n.ReplyTo == nil {
				p.held = append(p.held, held{at(n.Path, n.OriginalLine, n.OriginalStartLine, n.Body), at(n.Path, n.Line, n.StartLine, n.Body)})
			}
		}
		page := data.Node.Comments.PageInfo
		if !page.HasNextPage {
			return p, nil
		}
		after = page.EndCursor
	}
	return p, errors.New("too many comments in the review pending on GitHub to check")
}

// at is the spot of a comment on line (from start) as GitHub gives them:
// none when it has no line.
func at(path string, line, start *int, body string) spot {
	if line == nil {
		return spot{}
	}
	d := Draft{Path: path, Line: *line, Body: body}
	if start != nil {
		d.StartLine = *start
	}
	return d.spot()
}

// missing is what of drafts the review doesn't hold yet: a comment at
// the draft's spot, where it was made or where it is now, stands for one
// draft, so twins need two.
func (p pending) missing(drafts []Draft) []Draft {
	used := make([]bool, len(p.held))
	var out []Draft
next:
	for _, d := range drafts {
		k := d.spot()
		for i, h := range p.held {
			if !used[i] && (h.made == k || h.now == k) {
				used[i] = true
				continue next
			}
		}
		out = append(out, d)
	}
	return out
}

// submittedStates is the state each event leaves a review in.
var submittedStates = map[string]string{"COMMENT": "COMMENTED", "APPROVE": "APPROVED", "REQUEST_CHANGES": "CHANGES_REQUESTED"}

// submittedAs is whether the review was submitted as event with text
// (none says nothing).
func (p pending) submittedAs(event, text string) bool {
	return p.state == submittedStates[event] && (strings.TrimSpace(text) == "" || sameText(p.body) == sameText(text))
}

// joinPending adds the drafts the review doesn't hold yet to my pending
// review r and submits it. A review already submitted (by an earlier
// submission GitHub didn't answer, or on github.com) is this one when it
// holds every draft, whatever it was submitted as: its comments are sent,
// and kept drafts would be posted again after a reload. With no drafts
// the event and text are all a call says, so the review must have been
// submitted as them. Else nothing is added.
func (c *Client) joinPending(ctx context.Context, r Review, event string, body any) error {
	p, err := c.readPending(ctx, r.Pending)
	if err != nil {
		return fmt.Errorf("can't read your review pending on GitHub: %w", err)
	}
	missing := p.missing(r.Drafts)
	if p.state != "PENDING" {
		if len(missing) > 0 || len(r.Drafts) == 0 && !p.submittedAs(event, r.Body) {
			return errors.New("your review was submitted on GitHub meanwhile: reload the pull request")
		}
		return nil
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

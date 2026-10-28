package githubapi

import (
	"context"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// HeadPull is a pull request found by its head branch.
type HeadPull struct {
	Number     int
	ID         string // its node id
	Title, URL string
	State      string // "open", "closed" or "merged"
	Draft      bool
	Created    time.Time
}

// PullsByHead are repo's pull requests whose head is head ("owner:branch"),
// open or not, the newest first (ten at most), and how long GitHub asks to
// wait before asking again (its X-Poll-Interval; 0 when it says nothing).
// It's REST with the last answer's ETag: asked again unchanged, GitHub
// answers 304, which costs nothing.
func (c *Client) PullsByHead(ctx context.Context, repo, head string) ([]HeadPull, time.Duration, error) {
	owner, name, err := SplitRepo(repo)
	if err != nil {
		return nil, 0, err
	}
	var r []struct {
		Number   int    `json:"number"`
		NodeID   string `json:"node_id"`
		Title    string `json:"title"`
		HTMLURL  string `json:"html_url"`
		State    string `json:"state"`
		Draft    bool   `json:"draft"`
		MergedAt string `json:"merged_at"`
		Created  string `json:"created_at"`
		Head     struct {
			Ref string `json:"ref"`
		} `json:"head"`
	}
	q := url.Values{"head": {head}, "state": {"all"}, "sort": {"created"}, "direction": {"desc"}, "per_page": {"10"}}
	h, err := c.get(ctx, "/repos/{}/{}/pulls", []string{owner, name}, q, &r)
	if err != nil {
		return nil, 0, err
	}
	_, branch, _ := strings.Cut(head, ":")
	var out []HeadPull
	for _, p := range r {
		if p.Head.Ref != branch { // GitHub ignores a head it can't parse and lists every pull request
			continue
		}
		state := p.State
		if p.MergedAt != "" {
			state = "merged"
		}
		created, _ := time.Parse(time.RFC3339, p.Created)
		out = append(out, HeadPull{Number: p.Number, ID: p.NodeID, Title: p.Title, URL: webURL(p.HTMLURL), State: state, Draft: p.Draft, Created: created})
	}
	var wait time.Duration
	if s, err := strconv.Atoi(h.Get("X-Poll-Interval")); err == nil && s > 0 {
		wait = time.Duration(min(s, 3600)) * time.Second
	}
	return out, wait, nil
}

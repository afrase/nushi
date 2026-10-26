package githubapi

import (
	"context"
	"strings"
	"time"
)

// User is who a token is: login, name, and a classic or OAuth token's
// scopes (a fine-grained token has none to show: its access is per
// repository).
type User struct {
	Login, Name string
	Scopes      []string
}

// Viewer asks GitHub who the token is.
func (c *Client) Viewer(ctx context.Context) (User, error) {
	var u struct {
		Login string `json:"login"`
		Name  string `json:"name"`
	}
	h, err := c.get(ctx, "/user", nil, nil, &u)
	if err != nil {
		return User{}, err
	}
	out := User{Login: u.Login, Name: u.Name}
	for s := range strings.SplitSeq(h.Get("X-Oauth-Scopes"), ",") {
		if s = strings.TrimSpace(s); s != "" {
			out.Scopes = append(out.Scopes, s)
		}
	}
	return out, nil
}

// RateLimits asks GitHub for every bucket (a request that costs nothing),
// and keeps them as Budget's.
func (c *Client) RateLimits(ctx context.Context) ([]Bucket, error) {
	var r struct {
		Resources map[string]struct {
			Limit     int   `json:"limit"`
			Remaining int   `json:"remaining"`
			Reset     int64 `json:"reset"`
		} `json:"resources"`
	}
	if _, err := c.get(ctx, "/rate_limit", nil, nil, &r); err != nil {
		return nil, err
	}
	for name, b := range r.Resources {
		c.lim.set(Bucket{Name: name, Limit: b.Limit, Remaining: b.Remaining, Reset: time.Unix(b.Reset, 0)})
	}
	return c.Budget(), nil
}

// TokenKind is what kind of token a token is, from its prefix: "classic"
// (a personal access token), "fine-grained", "oauth" (an OAuth app's, as
// gh's login), "app" (a GitHub App's on a user's behalf), or "".
func TokenKind(token string) string {
	switch {
	case strings.HasPrefix(token, "ghp_"):
		return "classic"
	case strings.HasPrefix(token, "github_pat_"):
		return "fine-grained"
	case strings.HasPrefix(token, "gho_"):
		return "oauth"
	case strings.HasPrefix(token, "ghu_"):
		return "app"
	}
	return ""
}

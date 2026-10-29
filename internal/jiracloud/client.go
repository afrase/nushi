// Package jiracloud is a thin client of the Jira Cloud REST API (v3 and
// the Agile API), for the endpoints Nushi uses, with an email and an API
// token over Basic auth. A classic token goes to the site; a scoped one
// only works through Atlassian's gateway, api.atlassian.com/ex/jira/<cloud
// id>. Rich text comes and goes as Markdown (internal/adf).
//
// Its shape borrows from ctreminiom/go-atlassian and ankitpokhrel/jira-cli
// (both MIT): /search/jql with nextPageToken, the gateway for scoped
// tokens, the error bodies.
package jiracloud

import (
	"bytes"
	"cmp"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"math/rand/v2"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// Gateway is where a scoped token's requests go, followed by the site's
// cloud id.
var Gateway = "https://api.atlassian.com/ex/jira/"

// Client calls one site as one user.
type Client struct {
	Site    string // https://<name>.atlassian.net, for browse links
	CloudID string // set for a scoped token, whose calls go through Gateway
	auth    string
	http    *http.Client
	log     *slog.Logger
	// wait sleeps before a retry; tests make it instant.
	wait func(context.Context, time.Duration) error

	mu         sync.Mutex
	acceptance *string // the site's acceptance criteria field id, once looked up
}

// New makes a client of site for email's token; with cloudID, a scoped
// token's, through the gateway. transport may be nil.
func New(site, cloudID, email, token string, transport http.RoundTripper) *Client {
	return &Client{
		Site:    strings.TrimRight(site, "/"),
		CloudID: cloudID,
		auth:    "Basic " + base64.StdEncoding.EncodeToString([]byte(email+":"+token)),
		http:    &http.Client{Transport: transport, Timeout: 30 * time.Second},
		log:     slog.Default().With("site", strings.TrimPrefix(strings.TrimRight(site, "/"), "https://")),
		wait:    sleep,
	}
}

// Connect checks email's token on site: as a classic token on the site
// itself, else as a scoped one through the gateway (Jira refuses a scoped
// token on the site with 401). It returns the client that worked and who
// the token is.
func Connect(ctx context.Context, site, email, token string, transport http.RoundTripper) (*Client, model.JiraUser, error) {
	u, err := url.Parse(strings.TrimSpace(site))
	if err != nil || u.Scheme != "https" || u.Host == "" || u.Path != "" && u.Path != "/" {
		return nil, model.JiraUser{}, fmt.Errorf("%q isn't a site's address, such as https://example.atlassian.net", site)
	}
	site = "https://" + u.Host
	c := New(site, "", email, token, transport)
	me, err := c.Myself(ctx)
	if !errors.Is(err, ErrUnauthorized) {
		return c, me, err
	}
	var tenant struct {
		CloudID string `json:"cloudId"`
	}
	if c.do(ctx, http.MethodGet, "/_edge/tenant_info", nil, nil, nil, &tenant) != nil || tenant.CloudID == "" {
		return nil, me, err // the first answer says more
	}
	scoped := New(site, tenant.CloudID, email, token, transport)
	if me, err = scoped.Myself(ctx); err != nil {
		return nil, me, err
	}
	return scoped, me, nil
}

var (
	// ErrUnauthorized is Jira refusing the email and token.
	ErrUnauthorized = errors.New("Jira refused the email and API token: wrong, revoked or expired")
	// ErrNotFound is an issue (or anything else) the user can't see.
	ErrNotFound = errors.New("not found, or you can't see it")
)

// RateLimitedError is Jira asking to wait, past the retries.
type RateLimitedError struct{ After time.Duration }

func (e *RateLimitedError) Error() string {
	return fmt.Sprintf("Jira asks to wait %s before more requests", e.After.Round(time.Second))
}

// retries is how often a request Jira refused for now (429, 503) is sent
// again, after Retry-After (at most maxWait).
const (
	retries = 2
	maxWait = 20 * time.Second
)

// do sends a request. path is a template whose {} are filled with args,
// escaped; it alone is logged, with the status and how long it took,
// never the query, the body or the answer. A JSON body and answer are
// optional.
func (c *Client) do(ctx context.Context, method, path string, args []string, query url.Values, body, out any) error {
	resp, err := c.send(ctx, method, path, args, query, body)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	if out == nil {
		_, _ = io.Copy(io.Discard, resp.Body)
		return nil
	}
	return json.NewDecoder(io.LimitReader(resp.Body, 32<<20)).Decode(out)
}

// send makes the request, retrying while Jira asks to wait, and returns a
// 2xx response; any other is an error.
func (c *Client) send(ctx context.Context, method, path string, args []string, query url.Values, body any) (*http.Response, error) {
	u := c.Site + fill(path, args)
	if c.CloudID != "" && !strings.HasPrefix(path, "/_edge") {
		u = Gateway + c.CloudID + fill(path, args)
	}
	if len(query) > 0 {
		u += "?" + query.Encode()
	}
	var payload []byte
	if body != nil {
		var err error
		if payload, err = json.Marshal(body); err != nil {
			return nil, err
		}
	}
	for try := 0; ; try++ {
		req, err := http.NewRequestWithContext(ctx, method, u, bytes.NewReader(payload)) //nolint:gosec // the site the user added, or Atlassian's gateway
		if err != nil {
			return nil, err
		}
		req.Header.Set("Authorization", c.auth)
		req.Header.Set("Accept", "application/json")
		if body != nil {
			req.Header.Set("Content-Type", "application/json")
		}
		start := time.Now()
		resp, err := c.http.Do(req) //nolint:gosec // as above
		if err != nil {
			err = cmp.Or(errors.Unwrap(err), err) // url.Error's message has the URL, a JQL query in it
			c.log.Warn("jira request failed", "method", method, "path", path, "took", time.Since(start).Round(time.Millisecond), "err", err)
			return nil, fmt.Errorf("can't reach %s: %w", c.Site, err)
		}
		c.log.Debug("jira", "method", method, "path", path, "status", resp.StatusCode, "took", time.Since(start).Round(time.Millisecond))
		if resp.StatusCode/100 == 2 {
			return resp, nil
		}
		err = c.failure(resp)
		_ = resp.Body.Close()
		var limited *RateLimitedError
		// A write is tried again only after a 429: a 503 (from a proxy,
		// say) may come after Jira did it, and a comment would go twice.
		again := method == http.MethodGet || resp.StatusCode == http.StatusTooManyRequests
		if !errors.As(err, &limited) || !again || try == retries || limited.After > maxWait {
			if resp.StatusCode >= 500 || limited != nil {
				c.log.Warn("jira refused", "method", method, "path", path, "status", resp.StatusCode)
			}
			return nil, err
		}
		if err := c.wait(ctx, limited.After); err != nil {
			return nil, err
		}
	}
}

// failure is the error a response that isn't 2xx stands for.
func (c *Client) failure(resp *http.Response) error {
	switch resp.StatusCode {
	case http.StatusUnauthorized:
		return ErrUnauthorized
	case http.StatusNotFound:
		return ErrNotFound
	case http.StatusTooManyRequests, http.StatusServiceUnavailable:
		return &RateLimitedError{After: retryAfter(resp.Header.Get("Retry-After"))}
	}
	var e struct {
		ErrorMessages []string          `json:"errorMessages"`
		Errors        map[string]string `json:"errors"`
	}
	_ = json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&e) // a body that isn't Jira's error says nothing
	msgs := e.ErrorMessages
	for field, msg := range e.Errors {
		msgs = append(msgs, field+": "+msg)
	}
	if len(msgs) == 0 {
		return fmt.Errorf("Jira answered %s", resp.Status)
	}
	return errors.New(strings.Join(msgs, "; "))
}

// retryAfter reads Retry-After (seconds, or a date), with Atlassian's
// advice of jitter (0.7 to 1.3 times); 5 s when it's missing.
func retryAfter(v string) time.Duration {
	d := 5 * time.Second
	if s, err := strconv.Atoi(strings.TrimSpace(v)); err == nil && s >= 0 {
		d = time.Duration(s) * time.Second
	} else if t, err := http.ParseTime(v); err == nil {
		d = max(time.Until(t), 0)
	}
	return time.Duration(float64(d) * (0.7 + 0.6*rand.Float64())) //nolint:gosec // jitter, not a secret
}

func fill(path string, args []string) string {
	for _, a := range args {
		path = strings.Replace(path, "{}", url.PathEscape(a), 1)
	}
	return path
}

func sleep(ctx context.Context, d time.Duration) error {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-t.C:
		return nil
	}
}

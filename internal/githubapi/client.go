// Package githubapi is a thin client of GitHub's API for what Nushi uses:
// GraphQL for anything shaped like a pull request (lists, a pull request
// whole, review threads, checks, review writes), REST where GraphQL has
// nothing or REST is cheaper (who the token is, the rate limits, an
// Actions job's log, a comparison's merge base). One client is one host
// (github.com or an Enterprise server) and one token.
//
// Every request goes through the rate limits' gate (limits.go): a few at
// a time, none in a bucket GitHub said is spent, polls held back while
// one runs low, writes one at a time and a second apart. REST reads send
// the ETag they got last (a 304 costs nothing). The log has each
// request's method, path template or GraphQL operation, status, time and
// what's left of its bucket; never the token, a query's variables or a
// body.
package githubapi

import (
	"bytes"
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
)

// Version is the REST API version Nushi's types follow (GitHub's default,
// supported until 2028-03-10).
const Version = "2022-11-28"

// Endpoints are a host's REST base, GraphQL endpoint and web address:
// api.github.com for github.com, api.<host> for a GHE.com tenancy, and
// <host>/api/v3 and /api/graphql for an Enterprise server.
func Endpoints(host string) (rest, graphql, web string) {
	switch {
	case host == "github.com":
		return "https://api.github.com", "https://api.github.com/graphql", "https://github.com"
	case strings.HasSuffix(host, ".ghe.com"):
		return "https://api." + host, "https://api." + host + "/graphql", "https://" + host
	}
	return "https://" + host + "/api/v3", "https://" + host + "/api/graphql", "https://" + host
}

// Client calls one host as one token's user.
type Client struct {
	Host string
	Web  string // https://github.com, for links
	rest string
	gql  string
	auth string
	http *http.Client
	// plain fetches a log from where GitHub redirects: no token goes there.
	plain *http.Client
	log   *slog.Logger
	lim   *limits
	etags *etags
}

// New makes a client of host for token; transport may be nil.
func New(host, token string, transport http.RoundTripper) *Client {
	rest, gql, web := Endpoints(host)
	noRedirect := func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	return &Client{
		Host: host, Web: web, rest: rest, gql: gql,
		auth:  "Bearer " + token,
		http:  &http.Client{Transport: transport, Timeout: 30 * time.Second, CheckRedirect: noRedirect},
		plain: &http.Client{Transport: transport, Timeout: 60 * time.Second, CheckRedirect: noRedirect},
		log:   slog.Default().With("host", host),
		lim:   newLimits(),
		etags: newEtags(),
	}
}

var (
	// ErrUnauthorized is GitHub refusing the token.
	ErrUnauthorized = errors.New("GitHub refused the token: wrong, revoked or expired")
	// ErrNotFound is something that isn't there, or that the token can't
	// see (GitHub says 404 for both).
	ErrNotFound = errors.New("not found, or the token can't see it")
)

// APIError is GitHub refusing a request, in its words.
type APIError struct {
	Status  int
	Message string
}

func (e *APIError) Error() string { return "GitHub: " + e.Message }

// get is a REST GET of path, a template whose {} are filled with args
// (escaped). It sends the ETag of the last answer and takes a 304 as that
// answer again. It returns the answer's headers. A repository that moved
// (a 301) is an error.
func (c *Client) get(ctx context.Context, path string, args []string, query url.Values, out any) (http.Header, error) {
	u := c.rest + fill(path, args)
	if len(query) > 0 {
		u += "?" + query.Encode()
	}
	a, err := c.send(ctx, http.MethodGet, path, u, "core", nil, false)
	if err != nil {
		return nil, err
	}
	switch {
	case a.status == http.StatusNotModified:
		a.body = c.etags.body(u)
	case a.status/100 == 3:
		return nil, &APIError{Status: a.status, Message: "it moved to " + a.header.Get("Location")}
	default:
		c.etags.keep(u, a.header.Get("ETag"), a.body)
	}
	if out == nil {
		return a.header, nil
	}
	return a.header, json.Unmarshal(a.body, out)
}

// graphqlError is one of a GraphQL answer's errors.
type graphqlError struct {
	Type    string `json:"type"`
	Message string `json:"message"`
	Path    []any  `json:"path"`
}

// opRE finds a GraphQL document's operation and its name.
var opRE = regexp.MustCompile(`^\s*(query|mutation)\s+([A-Za-z_]\w*)`)

// graphql runs a GraphQL document (one named operation) with vars,
// decoding its data into out. Errors with no data are an error; an answer
// with both (an alias that found nothing) keeps the data and returns the
// errors as partial.
func (c *Client) graphql(ctx context.Context, doc string, vars map[string]any, out any) (partial []graphqlError, err error) {
	m := opRE.FindStringSubmatch(doc)
	if m == nil {
		return nil, errors.New("a GraphQL document needs a named operation")
	}
	payload, err := json.Marshal(map[string]any{"query": doc, "variables": vars, "operationName": m[2]})
	if err != nil {
		return nil, err
	}
	a, err := c.send(ctx, http.MethodPost, m[2], c.gql, "graphql", payload, m[1] == "mutation")
	if err != nil {
		return nil, err
	}
	var answer struct {
		Data   json.RawMessage `json:"data"`
		Errors []graphqlError  `json:"errors"`
	}
	if err := json.Unmarshal(a.body, &answer); err != nil {
		return nil, err
	}
	for _, e := range answer.Errors {
		if e.Type == "RATE_LIMITED" {
			return nil, c.lim.spent("graphql", a.header)
		}
	}
	if len(answer.Data) == 0 || string(answer.Data) == "null" {
		if len(answer.Errors) == 0 {
			return nil, errors.New("GitHub answered no data")
		}
		return nil, &APIError{Status: a.status, Message: messages(answer.Errors)}
	}
	if err := json.Unmarshal(answer.Data, out); err != nil {
		return nil, err
	}
	if m[1] == "mutation" && len(answer.Errors) > 0 {
		return nil, &APIError{Status: a.status, Message: messages(answer.Errors)}
	}
	return answer.Errors, nil
}

func messages(errs []graphqlError) string {
	msgs := make([]string, 0, len(errs))
	for _, e := range errs {
		msgs = append(msgs, e.Message)
	}
	return strings.Join(msgs, "; ")
}

// answer is a response read whole.
type answer struct {
	status int
	header http.Header
	body   []byte
}

// send makes a request through the gate and returns a 2xx (or a 304)
// answer, read whole while the request holds its place; any other is an
// error. what is the path template or the operation, the only thing of
// the request that's logged.
func (c *Client) send(ctx context.Context, method, what, u, bucket string, payload []byte, write bool) (*answer, error) {
	release, err := c.lim.enter(ctx, bucket, write)
	if err != nil {
		return nil, err
	}
	defer release()
	req, err := http.NewRequestWithContext(ctx, method, u, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", c.auth)
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-Github-Api-Version", Version)
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if tag := c.etags.tag(u); method == http.MethodGet && tag != "" {
		req.Header.Set("If-None-Match", tag)
	}
	start := time.Now()
	resp, err := c.http.Do(req)
	var body []byte
	if err == nil {
		body, err = io.ReadAll(io.LimitReader(resp.Body, 64<<20))
		_ = resp.Body.Close()
	}
	took := time.Since(start).Round(time.Millisecond)
	if err != nil {
		err = cmp.Or(errors.Unwrap(err), err) // url.Error's message has the URL, a query in it
		c.log.Warn("github request failed", "method", method, "what", what, "took", took, "err", err)
		return nil, fmt.Errorf("can't reach %s: %w", c.Host, err)
	}
	b := c.lim.saw(bucket, resp.Header)
	c.log.Debug("github", "method", method, "what", what, "status", resp.StatusCode, "took", took, "bucket", b.Name, "left", b.Remaining)
	if resp.StatusCode/100 == 2 || resp.StatusCode/100 == 3 { // a 304, or a log's link
		return &answer{status: resp.StatusCode, header: resp.Header, body: body}, nil
	}
	err = c.failure(resp, b.Name, body)
	if resp.StatusCode >= 500 || errors.As(err, new(*RateLimitedError)) {
		c.log.Warn("github refused", "method", method, "what", what, "status", resp.StatusCode, "bucket", b.Name)
	}
	return nil, err
}

// failure is the error an answer that isn't 2xx stands for.
func (c *Client) failure(resp *http.Response, bucket string, body []byte) error {
	var e struct {
		Message string `json:"message"`
		Errors  []struct {
			Message string `json:"message"`
			Code    string `json:"code"`
		} `json:"errors"`
	}
	_ = json.Unmarshal(body, &e) // a body that isn't GitHub's error says nothing
	switch resp.StatusCode {
	case http.StatusUnauthorized:
		return ErrUnauthorized
	case http.StatusNotFound:
		return ErrNotFound
	case http.StatusForbidden, http.StatusTooManyRequests:
		if resp.Header.Get("X-Ratelimit-Remaining") == "0" || resp.Header.Get("Retry-After") != "" ||
			strings.Contains(strings.ToLower(e.Message), "rate limit") {
			return c.lim.spent(bucket, resp.Header)
		}
	}
	msgs := []string{cmp.Or(e.Message, "answered "+resp.Status)}
	for _, x := range e.Errors {
		msgs = append(msgs, cmp.Or(x.Message, x.Code))
	}
	return &APIError{Status: resp.StatusCode, Message: strings.Join(msgs, "; ")}
}

func fill(path string, args []string) string {
	for _, a := range args {
		path = strings.Replace(path, "{}", url.PathEscape(a), 1)
	}
	return path
}

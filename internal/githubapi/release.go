package githubapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"slices"
	"sync"
	"time"
)

// Releases asks for a public repository's releases without a token
// (nothing of the user's is sent), each question with its last answer's
// ETag: asked again unchanged, GitHub answers 304, which costs nothing.
type Releases struct {
	Repo      string            // "owner/name"
	Base      string            // REST's base; "" for api.github.com
	Transport http.RoundTripper // nil: http.DefaultTransport

	mu     sync.Mutex
	latest asked[string]
	tags   asked[[]string]
}

// asked is what GitHub last gave to one question, with its ETag.
type asked[T any] struct {
	etag string
	got  T
}

// Latest is the tag ("v0.1.17") of the repository's latest release
// (GitHub's: the newest that is neither a draft nor a pre-release);
// ErrNotFound when it has none.
func (r *Releases) Latest(ctx context.Context) (string, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var body struct {
		Tag string `json:"tag_name"`
	}
	fresh, err := r.get(ctx, "/releases/latest", &r.latest.etag, &body)
	if err != nil {
		return "", err
	}
	if fresh {
		r.latest.got = body.Tag
	}
	return r.latest.got, nil
}

// Tags is the tags of the repository's newest releases (GitHub's first
// ten, the newest first), pre-releases among them, drafts not: what a
// beta version is looked for in.
func (r *Releases) Tags(ctx context.Context) ([]string, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var body []struct {
		Tag   string `json:"tag_name"`
		Draft bool   `json:"draft"`
	}
	fresh, err := r.get(ctx, "/releases?per_page=10", &r.tags.etag, &body)
	if err != nil {
		return nil, err
	}
	if fresh {
		r.tags.got = nil
		for _, b := range body {
			if !b.Draft {
				r.tags.got = append(r.tags.got, b.Tag)
			}
		}
	}
	return slices.Clone(r.tags.got), nil
}

// get asks GitHub for path under the repository, with etag when it has
// one, and reads a new answer into out, keeping its ETag; fresh is false
// when GitHub says the last answer stands (304).
func (r *Releases) get(ctx context.Context, path string, etag *string, out any) (fresh bool, err error) {
	owner, name, err := SplitRepo(r.Repo)
	if err != nil {
		return false, err
	}
	base := r.Base
	if base == "" {
		base, _ = endpoints("github.com")
	}
	u := base + "/repos/" + url.PathEscape(owner) + "/" + url.PathEscape(name) + path
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, http.NoBody)
	if err != nil {
		return false, err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-Github-Api-Version", Version)
	if *etag != "" {
		req.Header.Set("If-None-Match", *etag)
	}
	resp, err := (&http.Client{Transport: r.Transport, Timeout: 30 * time.Second}).Do(req)
	if err != nil {
		if ue, ok := errors.AsType[*url.Error](err); ok {
			err = ue.Err // its message has the URL
		}
		return false, fmt.Errorf("can't reach GitHub: %w", err)
	}
	defer resp.Body.Close() //nolint:errcheck // read-only
	switch {
	case resp.StatusCode == http.StatusNotModified && *etag != "":
		return false, nil
	case resp.StatusCode == http.StatusNotFound:
		return false, ErrNotFound
	case resp.StatusCode != http.StatusOK:
		return false, fmt.Errorf("GitHub answered %s", resp.Status)
	}
	// Ten releases with their notes and files' records are a few hundred kB.
	if err := json.NewDecoder(io.LimitReader(resp.Body, 4<<20)).Decode(out); err != nil {
		return false, fmt.Errorf("reading GitHub's answer: %w", err)
	}
	*etag = resp.Header.Get("ETag")
	return true, nil
}

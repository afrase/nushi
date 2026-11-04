package githubapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sync"
	"time"
)

// Releases asks for a public repository's latest release without a token
// (nothing of the user's is sent), with the last answer's ETag: asked
// again unchanged, GitHub answers 304, which costs nothing.
type Releases struct {
	Repo string       // "owner/name"
	Base string       // REST's base; "" for api.github.com
	HTTP *http.Client // nil: a client of its own

	mu   sync.Mutex
	etag string
	last string // the tag GitHub gave with etag
}

// Latest is the tag ("v0.1.17") of the repository's latest release
// (GitHub's: the newest that is neither a draft nor a pre-release);
// ErrNotFound when it has none.
func (r *Releases) Latest(ctx context.Context) (string, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	owner, name, err := SplitRepo(r.Repo)
	if err != nil {
		return "", err
	}
	base := r.Base
	if base == "" {
		base, _, _ = endpoints("github.com")
	}
	u := base + "/repos/" + url.PathEscape(owner) + "/" + url.PathEscape(name) + "/releases/latest"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, http.NoBody)
	if err != nil {
		return "", err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-Github-Api-Version", Version)
	if r.etag != "" {
		req.Header.Set("If-None-Match", r.etag)
	}
	hc := r.HTTP
	if hc == nil {
		hc = &http.Client{Timeout: 30 * time.Second}
	}
	resp, err := hc.Do(req)
	if err != nil {
		if ue, ok := errors.AsType[*url.Error](err); ok {
			err = ue.Err // its message has the URL
		}
		return "", fmt.Errorf("can't reach GitHub: %w", err)
	}
	defer resp.Body.Close() //nolint:errcheck // read-only
	switch {
	case resp.StatusCode == http.StatusNotModified && r.etag != "":
		return r.last, nil
	case resp.StatusCode == http.StatusNotFound:
		return "", ErrNotFound
	case resp.StatusCode != http.StatusOK:
		return "", fmt.Errorf("GitHub answered %s", resp.Status)
	}
	var body struct {
		Tag string `json:"tag_name"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&body); err != nil {
		return "", fmt.Errorf("reading GitHub's answer: %w", err)
	}
	r.last = body.Tag
	r.etag = resp.Header.Get("ETag")
	return r.last, nil
}

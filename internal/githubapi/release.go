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

// Release is a repository's published release.
type Release struct {
	Tag       string // "v0.1.17"
	Published time.Time
}

// Releases asks for a public repository's latest release without a token
// (nothing of the user's is sent), with the last answer's ETag: asked
// again unchanged, GitHub answers 304, which costs nothing.
type Releases struct {
	Repo string       // "owner/name"
	Base string       // REST's base; "" for api.github.com
	HTTP *http.Client // nil: a client of its own

	mu   sync.Mutex
	etag string
	last Release
}

// Latest is the repository's latest release (GitHub's: the newest that is
// neither a draft nor a pre-release); ErrNotFound when it has none.
func (r *Releases) Latest(ctx context.Context) (Release, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	owner, name, err := SplitRepo(r.Repo)
	if err != nil {
		return Release{}, err
	}
	base := r.Base
	if base == "" {
		base, _, _ = Endpoints("github.com")
	}
	u := base + "/repos/" + url.PathEscape(owner) + "/" + url.PathEscape(name) + "/releases/latest"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, http.NoBody)
	if err != nil {
		return Release{}, err
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
		return Release{}, fmt.Errorf("can't reach GitHub: %w", err)
	}
	defer resp.Body.Close() //nolint:errcheck // read-only
	switch {
	case resp.StatusCode == http.StatusNotModified && r.etag != "":
		return r.last, nil
	case resp.StatusCode == http.StatusNotFound:
		return Release{}, ErrNotFound
	case resp.StatusCode != http.StatusOK:
		return Release{}, fmt.Errorf("GitHub answered %s", resp.Status)
	}
	var body struct {
		Tag       string    `json:"tag_name"`
		Published time.Time `json:"published_at"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&body); err != nil {
		return Release{}, fmt.Errorf("reading GitHub's answer: %w", err)
	}
	r.last = Release{Tag: body.Tag, Published: body.Published}
	r.etag = resp.Header.Get("ETag")
	return r.last, nil
}

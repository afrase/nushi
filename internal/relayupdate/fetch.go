package relayupdate

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
)

// maxRedirects is how many hops a request follows: GitHub sends a
// download to its storage host in one.
const maxRedirects = 5

// errRateLimited is GitHub's API refusing for its rate: without a token it
// allows an address 60 requests an hour, and an office or a VPN shares one.
var errRateLimited = errors.New("GitHub is limiting requests from this address; try again later")

// NewClient is the client an update asks through: rt (nil: Go's default
// transport, which takes the environment's proxy), following https
// redirects only, a few at most.
func NewClient(rt http.RoundTripper) *http.Client {
	if rt == nil {
		rt = http.DefaultTransport
		if t, ok := rt.(*http.Transport); ok {
			rt = t.Clone()
		}
	}
	return &http.Client{Transport: rt, CheckRedirect: httpsOnly}
}

// httpsOnly refuses a redirect that leaves https, or one too many.
func httpsOnly(req *http.Request, via []*http.Request) error {
	if len(via) > maxRedirects {
		return fmt.Errorf("more than %d redirects", maxRedirects)
	}
	if req.URL.Scheme != "https" {
		return fmt.Errorf("refused a redirect to %s: not https", req.URL.Redacted())
	}
	return nil
}

// release is what GitHub says of a release, the parts an update reads.
type release struct {
	Tag        string  `json:"tag_name"`
	Draft      bool    `json:"draft"`
	Prerelease bool    `json:"prerelease"`
	Assets     []asset `json:"assets"`
}

// asset is a file attached to a release.
type asset struct {
	Name string `json:"name"`
	URL  string `json:"browser_download_url"`
	Size int64  `json:"size"`
}

// find is the asset of that exact name, or false.
func (r release) find(name string) (asset, bool) {
	for _, a := range r.Assets {
		if a.Name == name {
			return a, true
		}
	}
	return asset{}, false
}

// statusError is an answer other than 200.
type statusError struct {
	url  string
	code int
}

func (e statusError) Error() string {
	return fmt.Sprintf("%s answered %d %s", e.url, e.code, http.StatusText(e.code))
}

// latest asks GitHub for the repository's newest stable release, and
// refuses an answer that isn't one.
func (u *Updater) latest(ctx context.Context) (release, version, error) {
	body, err := u.get(ctx, u.API+"/repos/"+Repo+"/releases/latest", "application/vnd.github+json", u.limits.json)
	if se := (statusError{}); errors.As(err, &se) && (se.code == http.StatusForbidden || se.code == http.StatusTooManyRequests) {
		return release{}, version{}, errRateLimited
	}
	if err != nil {
		return release{}, version{}, fmt.Errorf("asking GitHub for the latest release: %w", err)
	}
	var r release
	if err := json.Unmarshal(body, &r); err != nil {
		return release{}, version{}, fmt.Errorf("reading GitHub's latest release: %w", err)
	}
	v, ok := parseTag(r.Tag)
	switch {
	case r.Draft || r.Prerelease:
		return release{}, version{}, fmt.Errorf("GitHub's latest release, %q, is a draft or a pre-release: refused", r.Tag)
	case !ok:
		return release{}, version{}, fmt.Errorf("GitHub's latest release has the tag %q, not vX.Y.Z: refused", r.Tag)
	}
	return r, v, nil
}

// download fetches an asset from the address GitHub gave for it, at most
// limit bytes.
func (u *Updater) download(ctx context.Context, a asset, limit int64) ([]byte, error) {
	if a.Size > limit {
		return nil, fmt.Errorf("%s is %d bytes, more than the %d an update takes", a.Name, a.Size, limit)
	}
	body, err := u.get(ctx, a.URL, "application/octet-stream", limit)
	if err != nil {
		return nil, fmt.Errorf("downloading %s: %w", a.Name, err)
	}
	return body, nil
}

// get reads the body at an https address, at most limit bytes, sending
// nothing but the request: no token, no cookie.
func (u *Updater) get(ctx context.Context, address, accept string, limit int64) ([]byte, error) {
	if to, err := url.Parse(address); err != nil || to.Scheme != "https" {
		return nil, fmt.Errorf("refused %q: not an https address", address)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, address, http.NoBody)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "nushi-relay/"+u.Version)
	req.Header.Set("Accept", accept)
	resp, err := u.Client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close() //nolint:errcheck // a read body's close has nothing to say
	if resp.StatusCode != http.StatusOK {
		return nil, statusError{url: address, code: resp.StatusCode}
	}
	if resp.ContentLength > limit {
		return nil, fmt.Errorf("the answer is %d bytes, more than %d", resp.ContentLength, limit)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, limit+1))
	if err != nil {
		return nil, err
	}
	if int64(len(body)) > limit {
		return nil, fmt.Errorf("the answer is more than %d bytes", limit)
	}
	return body, nil
}

package githubapi

import (
	"context"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"math"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// What Releases does when the API refuses it for its rate: the same
// questions asked of the repository's pages on github.com, which the
// API's limit doesn't count and which need no token either
// (docs/facts/github.md, "Releases without the API"; ADR 0061).

// NetworkLimitedError is GitHub refusing a request made without a token
// because of how many came from this address (an office's or a VPN's is
// shared), with how long GitHub said to wait; 0 when it didn't say.
type NetworkLimitedError struct {
	Wait time.Duration
}

func (e *NetworkLimitedError) Error() string {
	const what = "GitHub is limiting requests from this network. "
	minutes := int(math.Ceil(e.Wait.Minutes()))
	switch {
	case e.Wait <= 0 || e.Wait > 2*time.Hour: // a primary limit resets within the hour
		return what + "Try again later."
	case minutes <= 1:
		return what + "Try again in about a minute."
	}
	return fmt.Sprintf(what+"Try again in about %d minutes.", minutes)
}

func networkLimited(err error) bool {
	return errors.As(err, new(*NetworkLimitedError))
}

func (r *Releases) clock() time.Time {
	if r.now != nil {
		return r.now()
	}
	return time.Now()
}

// rateRefusal is resp as a refusal for rate, nil when it's any other:
// a 429, or a 403 that says so (nothing left of the limit, a time to
// wait, or GitHub's message; a secondary limit may have neither header).
// A proxy's 403 says none of it.
func rateRefusal(resp *http.Response, now time.Time) *NetworkLimitedError {
	if resp.StatusCode != http.StatusForbidden && resp.StatusCode != http.StatusTooManyRequests {
		return nil
	}
	h := resp.Header
	spent, retry := h.Get("X-Ratelimit-Remaining") == "0", h.Get("Retry-After")
	if resp.StatusCode == http.StatusForbidden && !spent && retry == "" {
		said, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
		if !strings.Contains(strings.ToLower(string(said)), "rate limit") {
			return nil
		}
	}
	e := &NetworkLimitedError{}
	if s, err := strconv.Atoi(retry); err == nil && s > 0 {
		e.Wait = time.Duration(s) * time.Second
	} else if at, err := strconv.ParseInt(h.Get("X-Ratelimit-Reset"), 10, 64); err == nil && spent {
		e.Wait = time.Unix(at, 0).Sub(now)
	}
	return e
}

// viaPages is ask's answer in place of the API's refusal, refused: that
// refusal when the pages fail too, since it's the one that says when to
// try again. A repository without a release is an answer.
func viaPages[T any](ctx context.Context, refused error, ask func(context.Context) (T, error)) (T, error) {
	got, err := ask(ctx)
	if err == nil || errors.Is(err, ErrNotFound) {
		return got, err
	}
	slog.Debug("GitHub's pages didn't answer for the API", "err", err)
	var none T
	return none, refused
}

// webLatest is Latest from the repository's /releases/latest page, which
// redirects to the latest release's page: the tag is the end of the
// Location, which is read and never followed.
func (r *Releases) webLatest(ctx context.Context) (string, error) {
	resp, repo, err := r.page(ctx, "/releases/latest", "text/html")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close() //nolint:errcheck // read-only
	if resp.StatusCode < 300 || resp.StatusCode > 399 {
		return "", fmt.Errorf("GitHub's page answered %s", resp.Status)
	}
	to, err := resp.Location()
	if err != nil {
		return "", fmt.Errorf("GitHub's page redirects nowhere: %w", err)
	}
	if tag, ok := releaseTag(repo, to); ok {
		return tag, nil
	}
	if sameSite(repo, to) && strings.EqualFold(to.EscapedPath(), repo.EscapedPath()+"/releases") {
		return "", ErrNotFound // a repository with no release yet goes to its list
	}
	return "", errors.New("GitHub's page redirects somewhere that isn't a release")
}

// feedEntries is how many of a feed's entries are read: GitHub gives
// ten, as many as Tags asks the API for.
const feedEntries = 10

// webTags is Tags from the repository's releases.atom, whose entries
// each link to a release's page, pre-releases among them, drafts not.
// It also lists a tag that has no release (yet), which can't be told
// apart there.
func (r *Releases) webTags(ctx context.Context) ([]string, error) {
	resp, repo, err := r.page(ctx, "/releases.atom", "application/atom+xml")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close() //nolint:errcheck // read-only
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GitHub's feed answered %s", resp.Status)
	}
	// A feed, and nothing else that parses as XML (a sign-in page); ten
	// releases with their notes are tens of kB. encoding/xml reads no
	// external or declared entities.
	var feed struct {
		XMLName xml.Name `xml:"http://www.w3.org/2005/Atom feed"`
		Entries []struct {
			Links []struct {
				Rel  string `xml:"rel,attr"`
				Href string `xml:"href,attr"`
			} `xml:"link"`
		} `xml:"entry"`
	}
	if err := xml.NewDecoder(io.LimitReader(resp.Body, 4<<20)).Decode(&feed); err != nil {
		return nil, fmt.Errorf("reading GitHub's feed: %w", err)
	}
	var tags []string
	for _, e := range feed.Entries[:min(len(feed.Entries), feedEntries)] {
		for _, l := range e.Links {
			if l.Rel != "alternate" && l.Rel != "" {
				continue
			}
			if to, err := url.Parse(l.Href); err == nil {
				if tag, ok := releaseTag(repo, to); ok {
					tags = append(tags, tag)
					break
				}
			}
		}
	}
	return tags, nil
}

// page asks for path under the repository's page on github.com, with
// nothing but what kind of answer is wanted, and follows no redirect;
// repo is the repository's own address there.
func (r *Releases) page(ctx context.Context, path, accept string) (resp *http.Response, repo *url.URL, err error) {
	owner, name, err := SplitRepo(r.Repo)
	if err != nil {
		return nil, nil, err
	}
	web := r.Web
	if web == "" {
		web = "https://github.com"
	}
	repo, err = url.Parse(web + "/" + url.PathEscape(owner) + "/" + url.PathEscape(name))
	if err != nil {
		return nil, nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, repo.String()+path, http.NoBody)
	if err != nil {
		return nil, nil, err
	}
	req.Header.Set("Accept", accept)
	client := &http.Client{Transport: r.Transport, Timeout: 30 * time.Second,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	resp, err = client.Do(req)
	if err != nil {
		if ue, ok := errors.AsType[*url.Error](err); ok {
			err = ue.Err // its message has the URL
		}
		return nil, nil, fmt.Errorf("can't reach GitHub: %w", err)
	}
	return resp, repo, nil
}

// sameSite says whether to is on the host repo is on, by the same scheme.
func sameSite(repo, to *url.URL) bool {
	return to.Scheme == repo.Scheme && strings.EqualFold(to.Host, repo.Host) && to.User == nil
}

// releaseTag is the tag of the release whose page to is, when it is one
// of repo's (<repo>/releases/tag/<tag>, on the same host): a link to any
// other host or repository names no tag.
func releaseTag(repo, to *url.URL) (tag string, ok bool) {
	if !sameSite(repo, to) {
		return "", false
	}
	path, prefix := to.EscapedPath(), repo.EscapedPath()+"/releases/tag/"
	if len(path) <= len(prefix) || !strings.EqualFold(path[:len(prefix)], prefix) {
		return "", false
	}
	tag, err := url.PathUnescape(path[len(prefix):])
	if err != nil || len(tag) > 128 || strings.ContainsAny(tag, "/\\") || strings.ContainsFunc(tag, func(c rune) bool { return c < ' ' || c == 0x7f }) {
		return "", false
	}
	return tag, true
}

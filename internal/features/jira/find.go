package jira

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"sync"
	"unicode"

	"github.com/afrase/nushi/internal/model"
)

// Found is an issue the New chat dialog offers: its site, and the branch
// a worktree for it would be on.
type Found struct {
	Site   string
	Issue  model.JiraIssue
	Branch string
}

// Finding is what Find found: the issues, or, for a link to a site that
// isn't connected, that site's address.
type Finding struct {
	Issues      []Found
	UnknownSite string
}

// findLimit is how many issues a search brings from each site.
const findLimit = 20

// recentJQL is the issues the user looked at last, for an empty search.
const recentJQL = "issue in issueHistory() ORDER BY lastViewed DESC"

// Find is what text names: an issue's link (matched to a connected site
// by its address; one issue from each site that matches), an issue's key
// (on site, the one used last, else the first), or words of issues on
// every site (their summary, description or comments); nothing typed is
// the issues looked at last.
func (s *Service) Find(ctx context.Context, text, site string) (Finding, error) {
	sites, err := s.store.JiraSites()
	if err != nil {
		return Finding{}, err
	}
	if len(sites) == 0 {
		return Finding{}, errors.New("no Jira site: add one in Settings › Jira")
	}
	text = strings.TrimSpace(text)
	if origin, path, key, ok := parseLink(text); ok {
		matched := matchSites(sites, origin, path)
		if len(matched) == 0 {
			return Finding{UnknownSite: origin}, nil
		}
		found, err := s.search(ctx, matched, "key = "+key, 1)
		return Finding{Issues: found}, err
	}
	if key := strings.ToUpper(text); CheckKey(key) == nil {
		on := sites[:1]
		for _, x := range sites {
			if SiteID(x) == site {
				on = []model.JiraSite{x}
			}
		}
		found, err := s.search(ctx, on, "key = "+key, 1)
		return Finding{Issues: found}, err
	}
	jql := recentJQL
	if text != "" {
		jql = textJQL(text)
	}
	found, err := s.search(ctx, sites, jql, findLimit)
	return Finding{Issues: found}, err
}

// search runs jql on each site at once, keeping each site's order and the
// sites' order. It fails only when every site did, with the first's error.
func (s *Service) search(ctx context.Context, sites []model.JiraSite, jql string, limit int) ([]Found, error) {
	got := make([][]model.JiraIssue, len(sites))
	errs := make([]error, len(sites))
	var wg sync.WaitGroup
	for i, site := range sites {
		wg.Go(func() {
			c, err := s.client(site, false)
			if err == nil {
				got[i], err = c.Search(ctx, jql, limit)
			}
			if err != nil {
				errs[i] = fmt.Errorf("%s: %w", SiteID(site), err)
			}
		})
	}
	wg.Wait()
	var out []Found
	for i, issues := range got {
		for _, is := range issues {
			out = append(out, Found{Site: SiteID(sites[i]), Issue: is, Branch: Branch(is.Key, is.Summary)})
		}
	}
	for _, err := range errs {
		if err != nil && out == nil {
			if len(sites) == 1 {
				return nil, errors.Unwrap(err) // the site is plain from what was asked
			}
			return nil, err
		}
	}
	return out, nil
}

// textJQL is a search for issues with every word of text, each as the
// start of a word in their summary, description or comments. Only letters
// and digits are kept, so nothing typed reaches JQL as syntax.
func textJQL(text string) string {
	words := strings.FieldsFunc(text, func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) })
	if len(words) == 0 {
		return recentJQL
	}
	clauses := make([]string, 0, 6)
	for _, w := range words[:min(len(words), 6)] {
		clauses = append(clauses, `text ~ "`+w+`*"`)
	}
	return strings.Join(clauses, " AND ") + " ORDER BY updated DESC"
}

// parseLink reads an issue's link: its site's address (scheme and host),
// its path, and the issue's key, from /browse/KEY or /issues/KEY anywhere
// in the path (after a path prefix of the site's), or a board's
// ?selectedIssue=KEY.
func parseLink(text string) (origin, path, key string, ok bool) {
	u, err := url.Parse(text)
	if err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Host == "" {
		return "", "", "", false
	}
	segs := strings.Split(u.Path, "/")
	for i, seg := range segs[:len(segs)-1] {
		if k := strings.ToUpper(segs[i+1]); (seg == "browse" || seg == "issues") && CheckKey(k) == nil {
			key = k
		}
	}
	if CheckKey(key) != nil {
		key = strings.ToUpper(u.Query().Get("selectedIssue"))
	}
	if CheckKey(key) != nil {
		return "", "", "", false
	}
	return originOf(u), u.Path, key, true
}

// originOf is a URL's scheme and host, lowercase, without a default port.
func originOf(u *url.URL) string {
	scheme, host := strings.ToLower(u.Scheme), strings.ToLower(u.Hostname())
	defaultPort := map[string]string{"https": "443", "http": "80"}[scheme]
	if p := u.Port(); p != "" && p != defaultPort {
		host += ":" + p
	}
	return scheme + "://" + host
}

// matchSites are the sites at origin whose own path (a Data Center site
// may have one, such as /jira) starts path.
func matchSites(sites []model.JiraSite, origin, path string) []model.JiraSite {
	var out []model.JiraSite
	for _, site := range sites {
		u, err := url.Parse(site.URL)
		if err != nil || originOf(u) != origin {
			continue
		}
		prefix := strings.TrimRight(u.Path, "/")
		if path == prefix || strings.HasPrefix(path, prefix+"/") {
			out = append(out, site)
		}
	}
	return out
}

// Branch is a branch's name for work on an issue: its key, uppercase so
// Jira links it, then its summary as a slug of 40 characters at most, cut
// between words ("SCRUM-5-fix-the-login").
func Branch(key, summary string) string {
	if slug := model.Slug(summary, 40); slug != "" {
		return key + "-" + slug
	}
	return key
}

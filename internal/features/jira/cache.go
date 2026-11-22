package jira

import (
	"log/slog"
	"strconv"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// What each list and issue showed last is kept, a file a site, so the
// view shows it at once while Jira is asked again. It is the user's own
// data: kept in the data folder (0600), never logged.
const cacheArea = "jira"

// listKey is a list's key in its site's cache.
func listKey(site model.JiraSite, list, jql string) string {
	switch list {
	case Mine:
		return "list mine"
	case Sprint:
		return "list sprint " + strconv.FormatInt(site.Board, 10)
	}
	return "jql " + jql
}

func issueKey(key string) string { return "issue " + key }

// keep caches v, c's answer, under key for the site with id, as it is
// now; only while c is still the site's client, checked and written under
// the lock: an answer to a token replaced or removed meanwhile (whose
// forget has run or is about to) would show another account's issues.
// GitHub's inbox keeps its answers the same way.
func (s *Service) keep(id string, c Client, key string, v any) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.clients[id] != c {
		return
	}
	if err := s.store.Cache(cacheArea, id, key, v); err != nil {
		slog.Warn("keeping a jira answer", "site", id, "err", err)
	}
}

// forget drops a site's cache.
func (s *Service) forget(id string) {
	if err := s.store.ForgetCache(cacheArea, id); err != nil {
		slog.Warn("dropping jira's cache", "site", id, "err", err)
	}
}

// CachedList is what a list showed last and when (zero when never),
// without asking Jira or the keychain.
func (s *Service) CachedList(id, list, jql string) (List, time.Time, error) {
	site, err := s.site(id)
	if err != nil {
		return List{}, time.Time{}, err
	}
	var l List
	at, err := s.store.Cached(cacheArea, id, listKey(site, list, jql), &l)
	return l, at, err
}

// CachedIssue is an issue as it showed last and when (zero when never).
func (s *Service) CachedIssue(id, key string) (model.JiraIssue, time.Time, error) {
	if err := CheckKey(key); err != nil {
		return model.JiraIssue{}, time.Time{}, err
	}
	if _, err := s.site(id); err != nil {
		return model.JiraIssue{}, time.Time{}, err
	}
	var is model.JiraIssue
	at, err := s.store.Cached(cacheArea, id, issueKey(key), &is)
	return is, at, err
}

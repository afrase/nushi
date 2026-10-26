// Package jira is Jira in Nushi: the sites added (their tokens in the
// keychain), the lists and the issue view's reads, and the writes the
// user asks for. Nothing reaches Jira on its own: every call here is a
// request from the app or, scoped to its issue, from a chat's agent.
package jira

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/url"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// Client is a Jira site as the feature uses it (internal/jiracloud's for
// Jira Cloud; Data Center's would be another). Text goes both ways as
// Markdown.
type Client interface { //nolint:interfacebloat // the Jira calls the feature makes, which a site's kind fills
	Myself(ctx context.Context) (model.JiraUser, error)
	Search(ctx context.Context, jql string, limit int) ([]model.JiraIssue, error)
	Boards(ctx context.Context) ([]model.JiraBoard, error)
	ActiveSprint(ctx context.Context, board int64) (int64, string, error)
	JQL(ctx context.Context) (model.JiraJQL, error)
	Suggestions(ctx context.Context, field, prefix string) ([]model.JiraOption, error)
	Issue(ctx context.Context, key string) (model.JiraIssue, error)
	Transitions(ctx context.Context, key string) ([]model.JiraTransition, error)
	Transition(ctx context.Context, key string, t model.JiraTransition, values map[string]string) error
	AddComment(ctx context.Context, key, markdown string) (model.JiraComment, error)
	Attachment(ctx context.Context, id string, thumbnail bool) ([]byte, string, error)
}

// Sites is how the feature reaches a site: Connect checks a token (and
// says who it is and, for a scoped token, the cloud id), Open makes a
// client of a site added before.
type Sites struct {
	Connect func(ctx context.Context, site, email, token string) (Client, model.JiraSite, error)
	Open    func(site model.JiraSite, token string) Client
}

// Tokens keeps API tokens (internal/keychain). A read without prompt
// never shows macOS's dialog.
type Tokens interface {
	Set(account, label string, secret []byte) error
	Get(account string, prompt bool) ([]byte, error)
	Delete(account string) error
}

// Keys says what a keychain error means (internal/keychain's kinds): the
// user's OK is needed (AllowToken asks), the daemon must start again to
// reach the keychain (its error says so), or the token is gone.
type Keys struct {
	NeedsOK, Restart, Missing func(error) bool
}

// ErrNeedsOK is a token the keychain gives only once the user allows it
// (a new build of Nushi): AllowToken asks.
var ErrNeedsOK = errors.New("this build of Nushi needs your OK to read the Jira token from the keychain: Settings › Jira › Allow")

// Store keeps the sites, the writes agents made, and what each list and
// issue showed last (the cache: area "jira", a file a site).
type Store interface {
	JiraSites() ([]model.JiraSite, error)
	SaveJiraSites([]model.JiraSite) error
	JiraWrites() ([]model.JiraWrite, error)
	SaveJiraWrites([]model.JiraWrite) error
	Cached(area, name, key string) (time.Time, json.RawMessage, error)
	Cache(area, name, key string, at time.Time, data json.RawMessage) error
	ForgetCache(area, name string) error
}

// Service is Jira's feature.
type Service struct {
	sites  Sites
	tokens Tokens
	store  Store
	keys   Keys

	mu      sync.Mutex
	clients map[string]Client // by site id, once its token was read
	jql     map[string]jqlCache
	sprints map[string]sprintRef // a site's board's active sprint, as found last
}

type jqlCache struct {
	at  time.Time
	jql model.JiraJQL
}

// New makes the service.
func New(sites Sites, tokens Tokens, store Store, keys Keys) *Service {
	return &Service{sites: sites, tokens: tokens, store: store, keys: keys, clients: map[string]Client{}, jql: map[string]jqlCache{}, sprints: map[string]sprintRef{}}
}

// SiteID is a site's id in Nushi: its host.
func SiteID(site model.JiraSite) string {
	u, err := url.Parse(site.URL)
	if err != nil {
		return site.URL
	}
	return u.Host
}

// account is a site's token's name in the keychain.
func account(site model.JiraSite) string { return site.Email + " on " + SiteID(site) }

// SiteState is a site with how its token is.
type SiteState struct {
	model.JiraSite
	// Problem says why Nushi can't use the site now ("" when it can, or
	// hasn't tried yet).
	Problem string
	// NeedsOK says the keychain wants the user's OK (AllowToken);
	// Restart that the daemon can't reach the keychain until it starts
	// again.
	NeedsOK, Restart bool
}

// Sites lists the sites added, each with what Nushi knows of its token
// (read from the keychain without a prompt).
func (s *Service) Sites() ([]SiteState, error) {
	sites, err := s.store.JiraSites()
	if err != nil {
		return nil, err
	}
	out := make([]SiteState, 0, len(sites))
	for _, site := range sites {
		st := SiteState{JiraSite: site}
		if _, err := s.client(site, false); err != nil {
			st.Problem, st.NeedsOK, st.Restart = err.Error(), errors.Is(err, ErrNeedsOK), s.keys.Restart(err)
		}
		out = append(out, st)
	}
	return out, nil
}

// AddSite checks email's token on site and keeps it: the token in the
// keychain, the site in the list (replacing one of the same host).
// expires is when the token expires, if the user knows (zero if not).
func (s *Service) AddSite(ctx context.Context, site, email, token string, expires time.Time) (model.JiraSite, error) {
	email, token = strings.TrimSpace(email), strings.TrimSpace(token)
	if email == "" || token == "" {
		return model.JiraSite{}, errors.New("an email and an API token are needed")
	}
	c, got, err := s.sites.Connect(ctx, site, email, token)
	if err != nil {
		return model.JiraSite{}, err
	}
	got.Email, got.Expires = email, expires
	id := SiteID(got)
	if err := s.tokens.Set(account(got), "Nushi: Jira API token for "+id, []byte(token)); err != nil {
		return model.JiraSite{}, fmt.Errorf("keeping the token in the keychain: %w", err)
	}
	err = s.change(func(sites []model.JiraSite) []model.JiraSite {
		i := slices.IndexFunc(sites, func(x model.JiraSite) bool { return SiteID(x) == id })
		if i < 0 {
			return append(sites, got)
		}
		got.Board, got.BoardName, got.Searches = sites[i].Board, sites[i].BoardName, sites[i].Searches
		if sites[i].Email != got.Email {
			_ = s.tokens.Delete(account(sites[i])) // the old email's token goes; nothing uses it now
		}
		sites[i] = got
		return sites
	})
	if err != nil {
		return model.JiraSite{}, err
	}
	s.mu.Lock()
	s.clients[id] = c
	s.mu.Unlock()
	s.forget(id) // what another token showed
	slog.Info("jira site added", "site", id, "scoped", got.CloudID != "")
	return got, nil
}

// RemoveSite forgets a site and deletes its token from the keychain.
func (s *Service) RemoveSite(id string) error {
	site, err := s.site(id)
	if err != nil {
		return err
	}
	if err := s.tokens.Delete(account(site)); err != nil {
		return fmt.Errorf("deleting the token from the keychain: %w", err)
	}
	s.mu.Lock()
	delete(s.clients, id)
	delete(s.jql, id)
	s.mu.Unlock()
	s.forget(id)
	slog.Info("jira site removed", "site", id)
	return s.change(func(sites []model.JiraSite) []model.JiraSite {
		return slices.DeleteFunc(sites, func(x model.JiraSite) bool { return SiteID(x) == id })
	})
}

// AllowToken reads a site's token with macOS's prompt, which asks the
// user to let this build of Nushi read it.
func (s *Service) AllowToken(id string) error {
	site, err := s.site(id)
	if err != nil {
		return err
	}
	_, err = s.client(site, true)
	return err
}

// SetBoard picks the board whose active sprint is the site's sprint list.
func (s *Service) SetBoard(id string, board model.JiraBoard) error {
	return s.update(id, func(site *model.JiraSite) { site.Board, site.BoardName = board.ID, board.Name })
}

// SetSearches keeps the site's saved searches.
func (s *Service) SetSearches(id string, searches []model.JiraSearch) error {
	return s.update(id, func(site *model.JiraSite) { site.Searches = searches })
}

func (s *Service) update(id string, change func(*model.JiraSite)) error {
	if _, err := s.site(id); err != nil {
		return err
	}
	return s.change(func(sites []model.JiraSite) []model.JiraSite {
		for i := range sites {
			if SiteID(sites[i]) == id {
				change(&sites[i])
			}
		}
		return sites
	})
}

func (s *Service) change(f func([]model.JiraSite) []model.JiraSite) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	sites, err := s.store.JiraSites()
	if err != nil {
		return err
	}
	return s.store.SaveJiraSites(f(sites))
}

func (s *Service) site(id string) (model.JiraSite, error) {
	sites, err := s.store.JiraSites()
	if err != nil {
		return model.JiraSite{}, err
	}
	for _, site := range sites {
		if SiteID(site) == id {
			return site, nil
		}
	}
	return model.JiraSite{}, fmt.Errorf("no Jira site %q: add it in Settings › Jira", id)
}

// client is a site's client, its token read from the keychain the first
// time (with macOS's prompt only when asked).
func (s *Service) client(site model.JiraSite, prompt bool) (Client, error) {
	id := SiteID(site)
	s.mu.Lock()
	c := s.clients[id]
	s.mu.Unlock()
	if c != nil {
		return c, nil
	}
	token, err := s.tokens.Get(account(site), prompt)
	switch {
	case err == nil:
	case s.keys.NeedsOK(err):
		return nil, ErrNeedsOK
	case s.keys.Restart(err):
		return nil, err // says what to do
	case s.keys.Missing(err):
		return nil, fmt.Errorf("the Jira token for %s isn't in the keychain any more: add the site again in Settings › Jira", id)
	default:
		return nil, fmt.Errorf("reading the Jira token from the keychain: %w", err)
	}
	c = s.sites.Open(site, string(token))
	clear(token)
	s.mu.Lock()
	s.clients[id] = c
	s.mu.Unlock()
	return c, nil
}

// clientOf is the client of the site with id.
func (s *Service) clientOf(id string) (Client, model.JiraSite, error) {
	site, err := s.site(id)
	if err != nil {
		return nil, site, err
	}
	c, err := s.client(site, false)
	return c, site, err
}

// Browse is an issue's page in the browser ("" for a site not added).
func (s *Service) Browse(id, key string) string {
	site, err := s.site(id)
	if err != nil {
		return ""
	}
	return strings.TrimRight(site.URL, "/") + "/browse/" + url.PathEscape(key)
}

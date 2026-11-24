package github

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/githubapi"
)

// How long an inbox is taken as current: two windows asking, or a
// window asking again soon, cost nothing more.
const inboxFresh = 20 * time.Second

type inboxCache struct {
	at    time.Time
	inbox githubapi.Inbox
}

// Inbox is the host's inbox, in repos if any are given, and when GitHub
// said so. A poll that fails keeps what GitHub said last, with the error
// (shown as stale); with nothing kept, the error alone.
type Inbox struct {
	githubapi.Inbox
	At    time.Time
	Stale error
}

// Inbox asks the host for its inbox (f says which); poll says the app
// asks on its timer, so a rate limit running low holds it back (the last
// inbox stays). An answer from a token replaced while it was asked is
// dropped: it may be another account's.
func (s *Service) Inbox(ctx context.Context, name string, f githubapi.InboxFilter, poll bool) (Inbox, error) {
	if h, ok := normalHost(name); ok {
		name = h // as the token's host is kept, and dropped
	}
	key := fmt.Sprint(name, " ", inboxKey(f))
	s.mu.Lock()
	kept, ok := s.inboxes[key]
	s.mu.Unlock()
	if ok && time.Since(kept.at) < inboxFresh {
		return Inbox{Inbox: kept.inbox, At: kept.at}, nil
	}
	h, err := s.host(ctx, name, false)
	if err != nil {
		return Inbox{}, err
	}
	if poll {
		ctx = githubapi.Poll(ctx)
	}
	in, err := h.c.Inbox(ctx, f)
	now := time.Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	current := s.clients[name] == h
	switch {
	case err != nil && current:
		if kept, ok := s.inboxes[key]; ok { // read again: a token change drops it
			return Inbox{Inbox: kept.inbox, At: kept.at, Stale: err}, nil
		}
		return Inbox{}, err
	case err != nil:
		return Inbox{}, err
	case !current:
		return Inbox{}, fmt.Errorf("the token for %s changed: ask again", name)
	}
	s.keep(name, inboxKey(f), in) // under s.mu, so a forget can't come between
	s.inboxes[key] = inboxCache{at: now, inbox: in}
	return Inbox{Inbox: in, At: now}, nil
}

// The inbox GitHub gave last is kept per host, filter and all, so the
// view shows it at once while GitHub is asked again: the user's own data,
// in the data folder (0600), never logged.
const cacheArea = "github"

// The key names every part of the filter, so one filter's inbox never
// shows as another's.
func inboxKey(f githubapi.InboxFilter) string {
	return fmt.Sprint("inbox ", f.Teams, " ", strings.Join(f.Repos, " "), " days ", f.Days, " wide ", strings.Join(f.Wide, " "),
		" hide ", strings.Join(f.Hide, " "), " owners ", strings.Join(f.Owners, " "))
}

func (s *Service) keep(name, key string, v any) {
	if err := s.Store.Cache(cacheArea, name, key, v); err != nil {
		slog.Warn("keeping a github answer", "host", name, "err", err)
	}
}

// forget drops what the host's token was shown, on disk and here (its
// inboxes, its items): another token may be another account's.
// s.mu is held.
func (s *Service) forget(name string) {
	if err := s.Store.ForgetCache(cacheArea, name); err != nil {
		slog.Warn("dropping github's cache", "host", name, "err", err)
	}
	for key := range s.inboxes {
		if strings.HasPrefix(key, name+" ") {
			delete(s.inboxes, key)
		}
	}
	for k := range s.items {
		if strings.HasPrefix(k, name+"/") {
			delete(s.items, k)
		}
	}
}

// CachedInbox is the host's inbox (f says which) as GitHub gave it last,
// At zero when never, without asking GitHub or the keychain.
func (s *Service) CachedInbox(name string, f githubapi.InboxFilter) (Inbox, error) {
	name, _, err := s.known(name)
	if err != nil {
		return Inbox{}, err
	}
	var in Inbox
	in.At, err = s.Store.Cached(cacheArea, name, inboxKey(f), &in.Inbox)
	if err != nil || in.At.IsZero() {
		return Inbox{}, err // a part read of a broken answer isn't shown
	}
	return in, nil
}

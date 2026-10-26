package github

import (
	"context"
	"slices"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// How long an answer is taken as current: two windows asking, or a
// window asking again soon, cost nothing more.
const (
	inboxFresh = 20 * time.Second
	stateFresh = 30 * time.Second
)

type inboxCache struct {
	at    time.Time
	inbox githubapi.Inbox
}

type stateCache struct {
	at   time.Time
	item model.GitHubItem
}

// Inbox is the host's inbox, in repos if any are given, and when GitHub
// said so. A poll that fails keeps what GitHub said last, with the error
// (shown as stale); with nothing kept, the error alone.
type Inbox struct {
	githubapi.Inbox
	At    time.Time
	Stale error
}

// Inbox asks the host for its inbox; poll says the app asks on its timer,
// so a rate limit running low holds it back (the last inbox stays).
func (s *Service) Inbox(ctx context.Context, name string, repos []string, poll bool) (Inbox, error) {
	key := name + " " + strings.Join(repos, " ")
	s.mu.Lock()
	kept, ok := s.inboxes[key]
	s.mu.Unlock()
	if ok && time.Since(kept.at) < inboxFresh {
		return Inbox{Inbox: kept.inbox, At: kept.at}, nil
	}
	c, err := s.client(name)
	if err != nil {
		return Inbox{}, err
	}
	if poll {
		ctx = githubapi.Poll(ctx)
	}
	in, err := c.Inbox(ctx, repos)
	if err != nil {
		if ok {
			return Inbox{Inbox: kept.inbox, At: kept.at, Stale: err}, nil
		}
		return Inbox{}, err
	}
	now := time.Now()
	s.mu.Lock()
	s.inboxes[key] = inboxCache{at: now, inbox: in}
	for _, it := range slices.Concat(in.Review, in.Mine, in.Assigned) {
		s.states[it.ID] = stateCache{at: now, item: it}
	}
	s.mu.Unlock()
	return Inbox{Inbox: in, At: now}, nil
}

// States are chats' items as they are now, by node id: the ones asked for
// in the last 30 s as they were, the rest in one query a host. An item
// GitHub can't give now keeps its last known state; one never known is
// left out.
func (s *Service) States(ctx context.Context, items []model.ChatGitHub, poll bool) map[string]model.GitHubItem {
	out := map[string]model.GitHubItem{}
	ask := map[string][]string{} // by host
	s.mu.Lock()
	for _, it := range items {
		kept, ok := s.states[it.ID]
		if ok {
			out[it.ID] = kept.item
		}
		if (!ok || time.Since(kept.at) >= stateFresh) && !slices.Contains(ask[it.Host], it.ID) && len(ask[it.Host]) < 100 {
			ask[it.Host] = append(ask[it.Host], it.ID)
		}
	}
	s.mu.Unlock()
	if poll {
		ctx = githubapi.Poll(ctx)
	}
	for name, ids := range ask {
		c, err := s.client(name)
		if err != nil {
			continue
		}
		got, err := c.Status(ctx, ids)
		if err != nil {
			continue // the last known state stays
		}
		now := time.Now()
		s.mu.Lock()
		for id, it := range got {
			s.states[id] = stateCache{at: now, item: it}
			out[id] = it
		}
		s.mu.Unlock()
	}
	return out
}

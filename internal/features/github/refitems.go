package github

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
)

// How long Items takes an item as current (ADR 0117): an open one 30 s, a
// merged or closed one (which rarely changes) and one GitHub didn't show
// 10 minutes; at most keptItems are kept.
const (
	itemOpenFresh = 30 * time.Second
	itemDoneFresh = 10 * time.Minute
	keptItems     = 1000
)

// itemCache is an item as GitHub said last, or that it didn't show it.
type itemCache struct {
	at     time.Time
	item   model.GitHubItem
	unseen bool
}

func (k itemCache) fresh(now time.Time) bool {
	ttl := itemOpenFresh
	if k.unseen || k.item.State == "merged" || k.item.State == "closed" {
		ttl = itemDoneFresh
	}
	return now.Sub(k.at) < ttl
}

// refKey is an item's key: host, repository (any case, as GitHub's) and
// number.
func refKey(r model.GitHubRef) string {
	return fmt.Sprintf("%s/%s#%d", r.Host, strings.ToLower(r.Repo), r.Number)
}

// Known says Nushi gives host a token: github.com, a host gh is signed in
// to, or one given a token in Settings. A link to another host gets no
// request (ADR 0117).
func (s *Service) Known(host string) bool {
	_, _, err := s.known(host)
	return err == nil
}

// Items are pull requests and issues by their numbers (ADR 0117): what's
// current from the cache, the rest asked of each host in queries of 50.
// Unseen are those GitHub doesn't show the token. An error is a host that
// couldn't be asked (none for one Nushi doesn't know, whose items are left
// out): its items as last known still answer. needsSignIn says a host has
// no token.
func (s *Service) Items(ctx context.Context, refs []model.GitHubRef, poll bool) (items []model.GitHubItem, unseen []model.GitHubRef, needsSignIn bool, err error) {
	items, unseen, hosts, ask := s.keptItems(refs)
	if poll {
		ctx = githubapi.Poll(ctx)
	}
	var errs []error
	for _, name := range hosts {
		if !s.Known(name) {
			continue // a host someone's text named: never asked
		}
		h, err := s.host(ctx, name, false)
		if err != nil {
			needsSignIn = true // no token, or one Settings › GitHub must allow
			errs = append(errs, err)
			continue
		}
		list := ask[name]
		for len(list) > 0 {
			part := list[:min(len(list), githubapi.MaxItems)]
			list = list[len(part):]
			got, missing, err := h.c.Items(ctx, part)
			if err != nil {
				errs = append(errs, err)
				break
			}
			if !s.keepItems(name, h, got, missing) {
				break // the token changed meanwhile: perhaps another account's
			}
			items, unseen = merged(items, unseen, got, missing)
		}
	}
	return items, unseen, needsSignIn, errors.Join(errs...)
}

// keptItems are what the cache has of refs (each once), and those to ask
// for, by host, the hosts in the order first named.
func (s *Service) keptItems(refs []model.GitHubRef) (items []model.GitHubItem, unseen []model.GitHubRef, hosts []string, ask map[string][]model.GitHubRef) {
	now := time.Now()
	ask = map[string][]model.GitHubRef{}
	seen := map[string]bool{}
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, r := range refs {
		name, ok := normalHost(r.Host)
		if !ok {
			continue
		}
		r.Host = name
		k := refKey(r)
		if seen[k] {
			continue
		}
		seen[k] = true
		kept, ok := s.items[k]
		switch {
		case ok && kept.unseen:
			unseen = append(unseen, r)
		case ok:
			items = append(items, kept.item)
		}
		if ok && kept.fresh(now) {
			continue
		}
		if _, ok := ask[name]; !ok {
			hosts = append(hosts, name)
		}
		ask[name] = append(ask[name], r)
	}
	return items, unseen, hosts, ask
}

// keepItems keeps what a host said, and feeds the chats' states; false
// when the host's token changed while it was asked.
func (s *Service) keepItems(name string, h *host, got []model.GitHubItem, missing []model.GitHubRef) bool {
	now := time.Now()
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.clients[name] != h {
		return false
	}
	for _, it := range got {
		s.items[refKey(it.GitHubRef)] = itemCache{at: now, item: it}
		s.states[it.ID] = stateCache{at: now, item: it}
	}
	for _, r := range missing {
		s.items[refKey(r)] = itemCache{at: now, unseen: true}
	}
	for len(s.items) > keptItems {
		var oldest string
		var at time.Time
		for k, v := range s.items {
			if oldest == "" || v.at.Before(at) {
				oldest, at = k, v.at
			}
		}
		delete(s.items, oldest)
	}
	return true
}

// merged is items and unseen with what a host just said in place of what
// was kept of them.
func merged(items []model.GitHubItem, unseen []model.GitHubRef, got []model.GitHubItem, missing []model.GitHubRef) ([]model.GitHubItem, []model.GitHubRef) {
	fresh := map[string]bool{}
	for _, it := range got {
		fresh[refKey(it.GitHubRef)] = true
	}
	for _, r := range missing {
		fresh[refKey(r)] = true
	}
	var outItems []model.GitHubItem
	for _, it := range items {
		if !fresh[refKey(it.GitHubRef)] {
			outItems = append(outItems, it)
		}
	}
	var outUnseen []model.GitHubRef
	for _, r := range unseen {
		if !fresh[refKey(r)] {
			outUnseen = append(outUnseen, r)
		}
	}
	return append(outItems, got...), append(outUnseen, missing...)
}

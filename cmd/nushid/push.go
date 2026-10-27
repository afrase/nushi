package main

import (
	"context"
	"net/http"
	"net/url"

	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/sysproxy"
	"github.com/afrase/nushi/internal/webpush"
)

// usePush gives remote access Web Push (ADR 0054): the daemon's VAPID key,
// made once and kept in vapid.json (0600), and the chats' agents' names.
func usePush(st *store.Store, r *remote.Service, chatSvc *chats.Service, kinds []chats.Kind) error {
	k, ok, err := st.VAPIDKey()
	if err != nil {
		return err
	}
	fresh := !ok || len(k.Private) != 32 || len(k.Public) != 65
	if fresh {
		keys, err := webpush.NewKeys()
		if err != nil {
			return err
		}
		k = model.VAPIDKey{Private: keys.Private, Public: keys.Public}
		if err := st.SaveVAPIDKey(k); err != nil {
			return err
		}
	}
	keys := webpush.Keys{Private: k.Private, Public: k.Public}
	titles := map[string]string{}
	for _, kind := range kinds {
		titles[kind.Name] = kind.Title
	}
	// Through the Mac's proxy, as the relay link goes (a company network).
	client := &http.Client{Timeout: webpush.Timeout, Transport: &http.Transport{Proxy: func(req *http.Request) (*url.URL, error) {
		proxies, err := sysproxy.For(req.URL)
		if err != nil || len(proxies) == 0 {
			return nil, err
		}
		return proxies[0], nil // nil: direct
	}}, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	r.UsePush(remote.Push{
		Key: keys.PublicKey(),
		Send: func(ctx context.Context, subject string, s webpush.Subscription, m webpush.Message) error {
			return (&webpush.Sender{Keys: keys, Subject: subject, Client: client}).Send(ctx, s, m)
		},
		Agent: func(chatID string) (string, bool) {
			sessions, err := chatSvc.List()
			if err != nil {
				return "", false
			}
			for _, s := range sessions {
				if s.ID == chatID {
					return titles[s.Agent], titles[s.Agent] != ""
				}
			}
			return "", false
		},
	}, fresh)
	return nil
}

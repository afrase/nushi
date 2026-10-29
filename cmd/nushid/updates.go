package main

import (
	"context"
	"net/http"
	"time"

	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/features/updates"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
)

// nushiRepo is where Nushi's releases are published (ADR 0055).
const nushiRepo = "afrase/nushi"

// startUpdates checks GitHub for a newer release of Nushi than this
// daemon's, at once and every 2 hours while the setting is on, without a
// token (the repository is public), through the system's proxy as
// GitHub's other calls.
func startUpdates(st *store.Store, publish func(model.Event)) *updates.Service {
	releases := &githubapi.Releases{Repo: nushiRepo, HTTP: &http.Client{Transport: proxiedTransport(), Timeout: 30 * time.Second}}
	latest := func(ctx context.Context) (string, time.Time, error) {
		r, err := releases.Latest(ctx)
		return r.Tag, r.Published, err
	}
	s := updates.New(latest, st, api.Release, "https://github.com/"+nushiRepo, publish)
	go s.Run(context.Background()) // as long as the daemon
	return s
}

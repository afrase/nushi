package main

import (
	"context"
	"os"

	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/features/updates"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/homebrew"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
)

// nushiRepo is where Nushi's releases are published (ADR 0055).
const nushiRepo = "afrase/nushi"

// startUpdates checks GitHub for a newer release of Nushi than this
// daemon's, at once and every 2 hours while the setting is on, without a
// token (the repository is public), through the system's proxy as
// GitHub's other calls. A Nushi that follows beta versions (a beta
// itself, or Homebrew's nushi@beta) looks among the newest releases,
// pre-releases too (ADR 0108). A Nushi that Homebrew installed has it
// install the newer one when the app asks (ADR 0109), in environ, the
// login shell's environment as agents get it.
func startUpdates(st *store.Store, publish func(model.Event), environ func() []string, home string) *updates.Service {
	releases := &githubapi.Releases{Repo: nushiRepo, Transport: proxiedTransport()}
	s := updates.New(releases.Latest, st, api.Release, "https://github.com/"+nushiRepo, publish)
	exe, _ := os.Executable() // "": not a cask's app, so nothing to upgrade
	brew := homebrew.New(environ, exe, home)
	s.Tags, s.Beta, s.Brew = releases.Tags, brew.Beta, brew
	go s.Run(context.Background()) // as long as the daemon
	return s
}

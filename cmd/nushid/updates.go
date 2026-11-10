package main

import (
	"context"
	"os"
	"path/filepath"

	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/features/updates"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
)

// nushiRepo is where Nushi's releases are published (ADR 0055).
const nushiRepo = "afrase/nushi"

// caskrooms are where Homebrew keeps its casks: under /opt/homebrew, or
// /usr/local on an Intel Mac (the app's update_toast.dart looks there too).
var caskrooms = []string{"/opt/homebrew/Caskroom", "/usr/local/Caskroom"}

// startUpdates checks GitHub for a newer release of Nushi than this
// daemon's, at once and every 2 hours while the setting is on, without a
// token (the repository is public), through the system's proxy as
// GitHub's other calls. A Nushi that follows beta versions (a beta
// itself, or Homebrew's nushi@beta) looks among the newest releases,
// pre-releases too (ADR 0108).
func startUpdates(st *store.Store, publish func(model.Event)) *updates.Service {
	releases := &githubapi.Releases{Repo: nushiRepo, Transport: proxiedTransport()}
	s := updates.New(releases.Latest, st, api.Release, "https://github.com/"+nushiRepo, publish)
	s.Tags = releases.Tags
	s.Beta = func() bool { return betaCask(caskrooms) }
	go s.Run(context.Background()) // as long as the daemon
	return s
}

// betaCask says whether Homebrew's nushi@beta cask is installed: one of
// rooms has its folder. Asked at each check, so installing it needs no
// restart.
func betaCask(rooms []string) bool {
	for _, room := range rooms {
		if _, err := os.Stat(filepath.Join(room, "nushi@beta")); err == nil {
			return true
		}
	}
	return false
}

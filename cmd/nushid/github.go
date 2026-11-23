package main

import (
	"context"
	"os"

	"github.com/afrase/nushi/internal/features/github"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/keychain"
	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/store"
)

// newGitHub is GitHub through internal/githubapi (ADR 0045): a host's
// token is gh's login's (ghLogin: the hosts in gh's hosts.yml, a host's
// token from `gh auth token`, gh found on the login shell's PATH), or one
// pasted into Settings, kept in the login keychain. A daemon on another
// data folder keeps its pasted tokens under a test service name.
func newGitHub(st *store.Store, dev bool, shellEnv *shellenv.Env) *github.Service {
	service := "Nushi GitHub"
	if dev {
		service = "Nushi GitHub (test)"
	}
	transport := proxiedTransport()
	gh := ghLogin{env: os.Environ, lookPath: shellEnv.LookPath}
	return github.New(github.Deps{
		Gh: github.Gh{
			Token:  gh.Token,
			Hosts:  gh.Hosts,
			Reload: func() {}, // Hosts reads gh's hosts.yml afresh each time
		},
		Tokens: keychain.Keychain{Service: service},
		Store:  st,
		Open:   func(host, token string) github.Client { return githubapi.New(host, token, transport) },
		Keys:   github.Keys{NeedsOK: is(keychain.ErrNeedsOK), Restart: is(keychain.ErrRestart), Missing: is(keychain.ErrNotFound), Word: keychain.Word},
		Remotes: func(ctx context.Context, folder string) (map[string]string, error) {
			rs, err := git.Remotes(ctx, folder)
			out := map[string]string{}
			for _, r := range rs {
				out[r.Name] = r.URL
			}
			return out, err
		},
		Fetch:         git.Fetch,
		CheckBranch:   git.CheckBranch,
		Head:          git.Head,
		DefaultBranch: git.DefaultBase,
	})
}

package main

import (
	"context"
	"errors"
	"net/http"

	"github.com/cli/go-gh/v2/pkg/auth"

	"github.com/afrase/nushi/internal/features/github"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/keychain"
	"github.com/afrase/nushi/internal/store"
)

// newGitHub is GitHub through internal/githubapi (ADR 0045): a host's
// token is gh's login's, read in this process through go-gh (from the
// environment, gh's config, or `gh auth token`), or one pasted into
// Settings, kept in the login keychain. A daemon on another data folder
// keeps its pasted tokens under a test service name.
func newGitHub(st *store.Store, dev bool) *github.Service {
	service := "Nushi GitHub"
	if dev {
		service = "Nushi GitHub (test)"
	}
	transport := http.DefaultTransport.(*http.Transport).Clone() //nolint:forcetypeassert // net/http's default is a *Transport
	transport.Proxy = proxy
	return github.New(github.Deps{
		Gh: github.Gh{
			Token: func(host string) (string, string) {
				token, source := auth.TokenForHost(host)
				if source == "oauth_token" || source == "default" {
					source = "gh" // gh's config, or nothing
				}
				return token, source
			},
			Hosts: auth.KnownHosts,
		},
		Tokens:  keychain.Keychain{Service: service},
		Store:   st,
		Open:    func(host, token string) github.Client { return githubapi.New(host, token, transport) },
		NeedsOK: func(err error) bool { return errors.Is(err, keychain.ErrNeedsOK) },
		Remotes: func(ctx context.Context, folder string) (map[string]string, error) {
			rs, err := git.Remotes(ctx, folder)
			out := map[string]string{}
			for _, r := range rs {
				out[r.Name] = r.URL
			}
			return out, err
		},
	})
}

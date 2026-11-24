package main

import (
	"context"
	"errors"
	"net/http"

	"github.com/afrase/nushi/internal/features/jira"
	"github.com/afrase/nushi/internal/jiracloud"
	"github.com/afrase/nushi/internal/keychain"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/sysproxy"
)

// newJira is Jira Cloud through internal/jiracloud, its tokens in the
// login keychain. A daemon on another data folder (NUSHI_DATA, for
// development and tests) keeps its tokens under a test service name.
func newJira(st *store.Store, dev bool) *jira.Service {
	service := "Nushi Jira"
	if dev {
		service = "Nushi Jira (test)"
	}
	transport := proxiedTransport()
	sites := jira.Sites{
		Connect: func(ctx context.Context, site, email, token string) (jira.Client, model.JiraSite, error) {
			c, me, err := jiracloud.Connect(ctx, site, email, token, transport)
			if err != nil {
				return nil, model.JiraSite{}, err
			}
			return c, model.JiraSite{URL: c.Site, CloudID: c.CloudID, AccountID: me.AccountID, Name: me.Name}, nil
		},
		Open: func(site model.JiraSite, token string) jira.Client {
			return jiracloud.New(site.URL, site.CloudID, site.Email, token, transport)
		},
	}
	return jira.New(sites, keychain.Keychain{Service: service}, st, jira.Keys{NeedsOK: is(keychain.ErrNeedsOK), Restart: is(keychain.ErrRestart), Missing: is(keychain.ErrNotFound), Word: keychain.Word})
}

// proxiedTransport is net/http's default transport through sysproxy's
// proxy (a company network): the environment's HTTPS_PROXY or HTTP_PROXY
// with NO_PROXY, else on the Mac scutil's settings or PAC file as macOS
// would pick them, on Linux ALL_PROXY, elsewhere a direct connection. The
// environment is the login shell's on Linux, the daemon's own on the Mac
// and Windows. Jira's, GitHub's, Web Push's and the update check's.
func proxiedTransport() *http.Transport {
	t := http.DefaultTransport.(*http.Transport).Clone() //nolint:forcetypeassert // net/http's default is a *Transport
	t.Proxy = sysproxy.Proxy
	return t
}

// is says an error is target.
func is(target error) func(error) bool { return func(err error) bool { return errors.Is(err, target) } }

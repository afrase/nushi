package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/cli/go-gh/v2/pkg/auth"
	"github.com/cli/go-gh/v2/pkg/config"

	"github.com/afrase/nushi/internal/features/github"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/keychain"
	"github.com/afrase/nushi/internal/procgroup"
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
	transport := proxiedTransport()
	return github.New(github.Deps{
		Gh: github.Gh{
			Token:  ghToken,
			Hosts:  auth.KnownHosts,
			Reload: func() { _ = config.Reload(nil) }, // a config gh can't read leaves the last one
		},
		Tokens:  keychain.Keychain{Service: service},
		Store:   st,
		Open:    func(host, token string) github.Client { return githubapi.New(host, token, transport) },
		NeedsOK: is(keychain.ErrNeedsOK),
		Restart: is(keychain.ErrRestart),
		Missing: is(keychain.ErrNotFound),
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

// ghToken is go-gh's TokenForHost with gh's config read again (go-gh
// reads it once a process: a login after the daemon started went unseen)
// and `gh auth token` given 10 s, its process group killed with it: the
// environment's token, else gh's config's, else the one gh keeps in the
// keychain. A `gh auth token` the request or the 10 s cut short is an
// error, not gh having no token.
func ghToken(ctx context.Context, host string) (string, string, error) {
	_ = config.Reload(nil)
	if token, source := auth.TokenFromEnvOrConfig(host); token != "" {
		if source == "oauth_token" {
			source = "gh" // gh's config
		}
		return token, source, nil
	}
	gh := os.Getenv("GH_PATH")
	if gh == "" {
		gh, _ = exec.LookPath("gh")
	}
	if gh == "" {
		return "", "gh", nil
	}
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, gh, "auth", "token", "--secure-storage", "--hostname", host) //nolint:gosec // gh for a known host; the token comes on stdout
	procgroup.Bound(cmd)
	out, err := cmd.Output()
	if ctx.Err() != nil {
		return "", "gh", fmt.Errorf("asking gh for %s's token: %w", host, ctx.Err())
	}
	if err != nil {
		return "", "gh", nil
	}
	return strings.TrimSpace(string(out)), "gh", nil
}

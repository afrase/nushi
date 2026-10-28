package main

import (
	"context"
	"errors"
	"net/http"
	"os"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/jira"
	"github.com/afrase/nushi/internal/features/tools"
	"github.com/afrase/nushi/internal/jiracloud"
	"github.com/afrase/nushi/internal/keychain"
	"github.com/afrase/nushi/internal/mcpserver"
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
	return jira.New(sites, keychain.Keychain{Service: service}, st, jira.Keys{NeedsOK: is(keychain.ErrNeedsOK), Restart: is(keychain.ErrRestart), Missing: is(keychain.ErrNotFound)})
}

// mcpTools gives a chat's sessions the MCP server of Nushi's tools for it
// (ADR 0043), when it has any: this nushid as `tools-mcp`, with the
// daemon's socket and the chat's key in its environment.
func mcpTools(t *tools.Service, socket string) chats.Tools {
	exe, err := os.Executable()
	if err != nil {
		return nil
	}
	return func(chat, agent string, issue *model.ChatIssue) []acp.MCPServer {
		g := tools.Grant{Chat: chat, Agent: agent, Issue: issue}
		if !t.HasTools(g) {
			return nil
		}
		return []acp.MCPServer{{Stdio: &acp.MCPServerStdio{Name: "nushi", Command: exe, Args: []string{mcpserver.Command},
			Env: []acp.EnvVariable{{Name: mcpserver.SocketEnv, Value: socket}, {Name: mcpserver.KeyEnv, Value: t.Key(g)}}}}}
	}
}

// proxiedTransport is net/http's default transport through the system's
// proxy, as macOS would pick it (a company network): Jira's, GitHub's and
// Web Push's.
func proxiedTransport() *http.Transport {
	t := http.DefaultTransport.(*http.Transport).Clone() //nolint:forcetypeassert // net/http's default is a *Transport
	t.Proxy = sysproxy.Proxy
	return t
}

// is says an error is target.
func is(target error) func(error) bool { return func(err error) bool { return errors.Is(err, target) } }

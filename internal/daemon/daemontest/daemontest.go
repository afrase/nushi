// Package daemontest is internal/daemon's leaves as fakes for tests: no
// login shell, agent CLI, keychain, network or relay is reached, nothing a
// crashed daemon left is swept, and the log's level stays as the test set
// it. The chats' kinds and the terminals' shell are the test's.
package daemontest

import (
	"context"
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"

	"github.com/afrase/nushi/internal/daemon"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/github"
	"github.com/afrase/nushi/internal/features/jira"
	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/updates"
	"github.com/afrase/nushi/internal/githubapi"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/tools"
	"github.com/afrase/nushi/relay"
)

// The tools server the fake Tools names in a session/new: a program and
// a socket that are never run or dialled.
const (
	ToolsCommand = "/daemontest/nushid"
	ToolsSocket  = "/daemontest/nushid.sock"
)

// errOffline is every call a fake would make outside the test.
var errOffline = errors.New("daemontest: nothing outside the test is reached")

// Leaves are the fakes. The zero value but Dir is ready: no kinds, and
// terminals that don't start.
type Leaves struct {
	Dir        string           // the data folder, for the processes' record
	ChatKinds  []chats.Kind     // Kinds
	Terminal   terminals.Start  // Shell's starter
	ShellName  string           // and what it names the shell
	ChatTiming chats.Timing     // Timing
	OnDevices  func(url string) // told the devices' API's address once it serves
}

var _ daemon.Leaves = (*Leaves)(nil)

// Agents knows no agents, and starts them with the test's own
// environment, never the login shell's.
func (l *Leaves) Agents(*store.Store) ([]knownagents.Agent, *agents.Service) {
	return nil, agents.New(nil, nil, shellenv.Off(os.Environ()), "", nil)
}

// Jira has no sites, and a keychain that holds nothing.
func (l *Leaves) Jira(st *store.Store) *jira.Service {
	return jira.New(jira.Sites{
		Connect: func(context.Context, string, string, string) (jira.Client, model.JiraSite, error) {
			return nil, model.JiraSite{}, errOffline
		},
	}, keychain{}, st, jira.Keys{Missing: isOffline})
}

// Remote dials no relay: every dial fails.
func (l *Leaves) Remote(st *store.Store, publish func(model.Event)) (*remote.Service, error) {
	dialer := &relay.Dialer{Proxies: func(*url.URL) ([]*url.URL, error) { return nil, errOffline }}
	return remote.New(st, dialer, func(c net.Conn) { _ = c.Close() }, func() func() { return func() {} }, publish)
}

// Kinds are ChatKinds.
func (l *Leaves) Kinds([]knownagents.Agent, *agents.Service) []chats.Kind { return l.ChatKinds }

// Processes reads this computer's, as the dev servers' tests need, and
// keeps the record in Dir without sweeping it first.
func (l *Leaves) Processes() (daemon.Processes, *proctree.Record) {
	return proctree.Tree{}, proctree.NewRecord(filepath.Join(l.Dir, "processes.json"))
}

// Tools names ToolsCommand and ToolsSocket.
func (l *Leaves) Tools(t *tools.Service) chats.Tools {
	return daemon.MCPTools(t, ToolsCommand, ToolsSocket)
}

// Timing is ChatTiming.
func (l *Leaves) Timing() chats.Timing { return l.ChatTiming }

// Shell is Terminal and ShellName; without a Terminal no terminal starts.
func (l *Leaves) Shell(*agents.Service) (terminals.Start, string) {
	if l.Terminal == nil {
		return func(string, string, int, int, func()) (terminals.Shell, error) { return nil, errOffline }, l.ShellName
	}
	return l.Terminal, l.ShellName
}

// Debug leaves the log's level as the test set it.
func (l *Leaves) Debug(bool) {}

// Updates finds no release, and never looks on its own.
func (l *Leaves) Updates(st *store.Store, publish func(model.Event), _ func() []string) *updates.Service {
	return updates.New(func(context.Context) (string, error) { return "", errOffline }, st, "", "", publish)
}

// GitHub has no gh login and no tokens, and reaches no host.
func (l *Leaves) GitHub(st *store.Store) *github.Service {
	return github.New(github.Deps{
		Gh: github.Gh{
			Token: func(context.Context, string) (string, string, error) { return "", "", errOffline },
			Hosts: func() []string { return nil },
		},
		Tokens: keychain{},
		Store:  st,
		Open:   func(host, token string) github.Client { return githubapi.New(host, token, offline{}) },
		Keys:   github.Keys{Missing: isOffline},
		Remotes: func(context.Context, string) (map[string]string, error) {
			return map[string]string{}, nil
		},
		Fetch:         func(context.Context, string, string, string) error { return errOffline },
		CheckBranch:   func(string) error { return nil },
		Head:          func(context.Context, string) (string, string) { return "", "" },
		DefaultBranch: func(context.Context, string) string { return "" },
	})
}

// Push sends nothing.
func (l *Leaves) Push() http.RoundTripper { return offline{} }

// ServeDevices serves the devices' API on localhost, and tells OnDevices
// where.
func (l *Leaves) ServeDevices(devices http.Handler) func() {
	srv := httptest.NewServer(devices)
	if l.OnDevices != nil {
		l.OnDevices(srv.URL)
	}
	return func() {
		srv.CloseClientConnections()
		srv.Close()
	}
}

// keychain holds no token and keeps none.
type keychain struct{}

func (keychain) Set(string, string, []byte) error { return errOffline }
func (keychain) Get(string, bool) ([]byte, error) { return nil, errOffline }
func (keychain) Delete(string) error              { return nil }
func isOffline(err error) bool                    { return errors.Is(err, errOffline) }

// offline is a transport that never connects.
type offline struct{}

func (offline) RoundTrip(*http.Request) (*http.Response, error) { return nil, errOffline }

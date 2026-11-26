package main

import (
	"log"
	"net/http"
	"os"

	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/daemon"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/github"
	"github.com/afrase/nushi/internal/features/jira"
	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/updates"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/logs"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/shellenv"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/sysproxy"
	"github.com/afrase/nushi/internal/tools"
	"github.com/afrase/nushi/relay"
)

// leaves are the daemon's real leaves (daemon.Leaves): the user's login
// shell and agents' CLIs, the keychain, GitHub, Jira and the update check
// through the system's proxy, the relay, this computer's processes and
// the log's level.
type leaves struct {
	dir      string // the data folder
	home     string
	dev      bool // a daemon on another data folder: its tokens under test names
	errorLog *log.Logger
	shellEnv *shellenv.Env // the login shell's environment, read and applied before the daemon starts
	channels *channels     // paired devices' channels, made with remote access
}

var _ daemon.Leaves = (*leaves)(nil)

func (l *leaves) Agents(st *store.Store) ([]knownagents.Agent, *agents.Service) {
	known := knownagents.All("", st.GoAgent)     // Claude's projects folder as the environment has it each time
	sysproxy.UseShellEnviron(l.shellEnv.Environ) // Linux only; before the relay, Jira, GitHub or Web Push asks
	return known, newAgents(l.dir, known, l.shellEnv)
}

func (l *leaves) Jira(st *store.Store) *jira.Service { return newJira(st, l.dev) }

func (l *leaves) Remote(st *store.Store, publish func(model.Event)) (*remote.Service, error) {
	l.channels = newChannels()
	return remote.New(st, &relay.Dialer{Proxies: sysproxy.For}, l.channels.serve, keepAwake, publish)
}

func (l *leaves) Kinds(known []knownagents.Agent, a *agents.Service) []chats.Kind {
	return chatKinds(l.dir, known, a)
}

func (l *leaves) Processes() (daemon.Processes, *proctree.Record) {
	return proctree.Tree{}, newRecord(l.dir)
}

// Tools runs this nushid as a chat's tools server, on the daemon's socket.
func (l *leaves) Tools(t *tools.Service) chats.Tools {
	exe, err := os.Executable()
	if err != nil {
		return nil
	}
	return daemon.MCPTools(t, exe, socketPath(l.dir))
}

func (l *leaves) Timing() chats.Timing { return chats.Timing{} }

// Shell is the login shell's starter; each terminal names its own shell
// (terminal.Terminal's Name).
func (l *leaves) Shell(a *agents.Service) (terminals.Start, string) { return shellStarter(a), "" }

func (l *leaves) Debug(on bool) { logs.SetDebug(on) }

func (l *leaves) Updates(st *store.Store, publish func(model.Event), environ func() []string) *updates.Service {
	return startUpdates(st, publish, environ, l.home)
}

func (l *leaves) GitHub(st *store.Store) *github.Service { return newGitHub(st, l.dev, l.shellEnv) }

func (l *leaves) Push() http.RoundTripper { return proxiedTransport() }

// ServeDevices serves the API on each paired device's channel (ADR 0034).
func (l *leaves) ServeDevices(devices http.Handler) func() {
	srv := &http.Server{Handler: devices, ConnContext: api.DeviceConn, Protocols: new(http.Protocols), ErrorLog: l.errorLog} //nolint:gosec // served only over paired devices' Noise channels
	srv.Protocols.SetUnencryptedHTTP2(true)
	// Serve returns once srv.Close closes channels.
	go func() { _ = srv.Serve(l.channels) }()
	return func() { _ = srv.Close() }
}

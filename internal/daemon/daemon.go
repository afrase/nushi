// Package daemon builds nushid's services and wires them together: the
// one composition of the daemon, which cmd/nushid runs with the real
// leaves and internal/e2e with fakes (Leaves), so the tests run the
// daemon that ships.
package daemon

import (
	"context"
	"net/http"
	"path/filepath"
	"sync"

	"github.com/afrase/nushi/internal/api"
	"github.com/afrase/nushi/internal/events"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/github"
	"github.com/afrase/nushi/internal/features/jira"
	"github.com/afrase/nushi/internal/features/memory"
	"github.com/afrase/nushi/internal/features/preview"
	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/features/restart"
	"github.com/afrase/nushi/internal/features/servers"
	"github.com/afrase/nushi/internal/features/terminals"
	"github.com/afrase/nushi/internal/features/updates"
	"github.com/afrase/nushi/internal/git"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/proctree"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/tools"
	"github.com/afrase/nushi/internal/transcripts"
)

// Leaves are the daemon's parts that reach outside it: the login shell,
// the agents' CLIs, the keychain, the network, the relay, this computer's
// processes and the process's log level. Their caller builds each when
// Start asks for it, in the order Start asks (the order the daemon has
// always started in), from what Start built before it; main's are real
// (cmd/nushid), the e2e tests' fakes (internal/daemon/daemontest).
type Leaves interface { //nolint:interfacebloat // every part that reaches outside the daemon, which main and the fakes each give as one set
	// Agents are the agents Nushi knows and the agents feature, with the
	// login shell's environment they start with.
	Agents(st *store.Store) ([]knownagents.Agent, *agents.Service)
	// Jira is Jira Cloud, its tokens in the keychain.
	Jira(st *store.Store) *jira.Service
	// Remote is remote access: the relay and the paired devices.
	Remote(st *store.Store, publish func(model.Event)) (*remote.Service, error)
	// Kinds are the agents as chats run them, the first the default.
	Kinds(known []knownagents.Agent, agents *agents.Service) []chats.Kind
	// Processes reads and stops this computer's processes; the record
	// keeps what a clean stop of each agent and dev server ends, once
	// what a crashed daemon left was stopped (proctree.Sweep).
	Processes() (Processes, *proctree.Record)
	// Tools gives a chat's sessions the MCP server of Nushi's tools
	// (MCPTools).
	Tools(t *tools.Service) chats.Tools
	// Timing is how long chats wait and how often they look.
	Timing() chats.Timing
	// Shell starts a terminal's shell, and names it ("": each terminal
	// names its own).
	Shell(agents *agents.Service) (start terminals.Start, name string)
	// Debug sets the log's level from the debug setting, at startup and
	// when a change turns it.
	Debug(on bool)
	// Updates checks for a newer release of Nushi.
	Updates(st *store.Store, publish func(model.Event), environ func() []string) *updates.Service
	// GitHub is GitHub, through gh's login or tokens in the keychain.
	GitHub(st *store.Store) *github.Service
	// Push is the transport Web Push goes through.
	Push() http.RoundTripper
	// ServeDevices serves the API for paired devices' channels until stop.
	ServeDevices(devices http.Handler) (stop func())
}

// Processes are this computer's processes as the chats and the dev
// servers read and stop them (proctree.Tree).
type Processes interface {
	chats.Processes
	servers.Procs
}

// Daemon is the daemon's services, started.
type Daemon struct {
	Chats   *chats.Service
	Restart *restart.Service
	Tools   *tools.Service
	Hub     *events.Hub
	// Socket is the API for this computer's app, behind the token, with
	// the chats' tools under /tools/.
	Socket http.Handler

	closeChats func()
	close      func()
}

// CloseChats ends the terminals and the dev servers, then the chats, then
// usage, once. The terminals and the dev servers end first: a restart
// found none running a moment ago, and ending them before the agents
// (which take up to stopGrace) leaves none the time to start. Usage is
// written last: the chats' last turns end as they close. main runs it
// while the socket still answers (prompts refused, to be sent again), so
// a new daemon never reopens sessions this one's agents are still ending
// (ADR 0056).
func (d *Daemon) CloseChats() { d.closeChats() }

// Close stops remote access and the devices' server, then CloseChats if
// it hasn't run, then what follows the events. Calling it again does
// nothing.
func (d *Daemon) Close() { d.close() }

// Start builds the daemon on its data folder dir from the leaves, the API
// behind token, and starts it. What runs on its own (the chats' loops,
// what follows the events) runs until Close or ctx's end.
func Start(ctx context.Context, dir, token string, l Leaves) (*Daemon, error) {
	hub := &events.Hub{}
	st := store.New(dir)
	known, agentSvc := l.Agents(st)
	copies, err := transcripts.Open(filepath.Join(dir, "transcripts"))
	if err != nil {
		return nil, err
	}
	jiraSvc := l.Jira(st)
	shows := preview.New(hub.Publish)
	serverTools := &servers.AgentTools{}
	toolSvc := tools.New(jiraSvc.Tools(), shows, serverTools)
	remoteSvc, err := l.Remote(st, hub.Publish)
	if err != nil {
		return nil, err
	}
	kinds := l.Kinds(known, agentSvc)
	usageSvc, closeUsage := openUsage(filepath.Join(dir, "nushi.db"), st) //nolint:contextcheck // the database opens on its own context, as main's always did: ctx ends the daemon's loops, not the open
	procs, record := l.Processes()
	follow, unfollow := context.WithCancel(ctx)
	chatSvc := chats.New(ctx, kinds, chats.Options{Remembered: st, Sessions: st, Worktrees: git.Worktrees{},
		Scratch: filepath.Join(dir, "scratch"), Uploads: filepath.Join(dir, "uploads"), Publish: hub.Publish, Tools: l.Tools(toolSvc),
		Viewers: remoteSvc, Processes: procs, Record: record, Copies: copies, CopiesOn: st.KeepTranscripts, CopyDays: st.TranscriptDays,
		Sleep: st, Timing: l.Timing(), Meter: usageSvc})
	shows.UseChats(chatSvc)
	shell, shellName := l.Shell(agentSvc)
	termSvc := terminals.New(shell, shellName, chatSvc, hub.Publish)
	chatSvc.UseTerminals(termSvc)
	go hub.Follow(follow, termSvc.Follow)
	srvSvc := newServers(record, chatSvc, agentSvc, procs, hub.Publish)
	chatSvc.UseServers(srvSvc)
	serverTools.Use(srvSvc)
	go hub.Follow(follow, srvSvc.Follow)
	agentSvc.UseChats(chatSvc)
	// The API, on the socket for the app (with the token) and on each
	// paired device's channel (ADR 0034).
	l.Debug(st.DebugLog())
	updateSvc := l.Updates(st, hub.Publish, agentSvc.Environ)
	restarts := restart.New(chatSvc, restart.Together{termSvc, srvSvc, updateSvc})
	sv := api.Services{Settings: settings{st, l.Debug}, ChatFiles: st, Chats: chatSvc, Agents: agentSvc, MCP: newMCP(known, agentSvc, chatSvc.MCPChanged),
		Skills: newSkills(known), Terms: termSvc, Trust: newTrust(known, st), Hub: hub, Memory: memory.New(chatSvc), Restart: restarts,
		Jira: jiraSvc, Remote: remoteSvc, Servers: srvSvc}
	sv.GitHub = l.GitHub(st)
	chatSvc.UseGitHub(sv.GitHub)
	sv.Updates = updateSvc
	sv.Usage = usageSvc
	if err := usePush(st, remoteSvc, chatSvc, kinds, l.Push()); err != nil {
		unfollow()
		return nil, err
	}
	go hub.Follow(follow, remoteSvc.Follow)
	socket, devices := api.Handlers(sv, toolSvc, token)
	stopDevices := l.ServeDevices(devices)
	closeChats := sync.OnceFunc(func() { termSvc.CloseAll(); srvSvc.CloseAll(); chatSvc.Close(); closeUsage() })
	return &Daemon{Chats: chatSvc, Restart: restarts, Tools: toolSvc, Hub: hub, Socket: socket, closeChats: closeChats,
		close: sync.OnceFunc(func() {
			remoteSvc.Close()
			stopDevices() // stopping: nothing is left to tell
			closeChats()
			unfollow()
		})}, nil
}

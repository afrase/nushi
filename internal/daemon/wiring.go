package daemon

import (
	"context"
	"log/slog"
	"net/http"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/database"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/chats"
	"github.com/afrase/nushi/internal/features/mcp"
	"github.com/afrase/nushi/internal/features/remote"
	"github.com/afrase/nushi/internal/features/servers"
	"github.com/afrase/nushi/internal/features/skills"
	"github.com/afrase/nushi/internal/features/trust"
	"github.com/afrase/nushi/internal/features/usage"
	"github.com/afrase/nushi/internal/knownagents"
	"github.com/afrase/nushi/internal/mcpserver"
	"github.com/afrase/nushi/internal/model"
	"github.com/afrase/nushi/internal/skillfile"
	"github.com/afrase/nushi/internal/store"
	"github.com/afrase/nushi/internal/terminal"
	"github.com/afrase/nushi/internal/tools"
	"github.com/afrase/nushi/internal/webpush"
)

// MCPTools gives a chat's sessions the MCP server of Nushi's tools for it
// (ADR 0043), when it has any: exe (nushid) as `tools-mcp`, with the
// daemon's socket and the chat's key in its environment.
func MCPTools(t *tools.Service, exe, socket string) chats.Tools {
	return func(chat, agent string, issue *model.ChatIssue) []acp.MCPServer {
		g := tools.Grant{Chat: chat, Agent: agent, Issue: issue}
		if !t.HasTools(g) {
			return nil
		}
		return []acp.MCPServer{{Stdio: &acp.MCPServerStdio{Name: chats.ToolsServer, Command: exe, Args: []string{mcpserver.Command},
			Env: []acp.EnvVariable{{Name: mcpserver.SocketEnv, Value: socket}, {Name: mcpserver.KeyEnv, Value: t.Key(g)}}}}}
	}
}

// settings are the store's settings, with the log's level following a
// change that turns the debug log: through Leaves.Debug, which sets it at
// startup too, so the level is set in one place.
type settings struct {
	*store.Store
	debug func(on bool)
}

// ChangeSettings makes the change, then sets the log's level if it turned
// the debug log.
func (s settings) ChangeSettings(c model.SettingsChange) error {
	was := s.DebugLog()
	if err := s.Store.ChangeSettings(c); err != nil {
		return err
	}
	if c.DebugLog != nil && *c.DebugLog != was {
		s.debug(*c.DebugLog)
	}
	return nil
}

// newMCP is the MCP servers of each agent whose config Nushi knows
// (knownagents.Agent.MCP), each checked by running the agent as a chat's
// would be.
func newMCP(known []knownagents.Agent, agentSvc *agents.Service, changed mcp.Changed) map[string]*mcp.Service {
	services := map[string]*mcp.Service{}
	for _, a := range known {
		if a.MCP == nil {
			continue
		}
		name := a.Agent.Name
		services[name] = mcp.New(name, a.MCP(func() (model.AgentRun, error) { return agentSvc.Run(name) }), changed)
	}
	return services
}

// newSkills is the Skills view's service: each agent's reader, in the
// order the agents are listed.
func newSkills(known []knownagents.Agent) *skills.Service {
	var order []string
	readers := map[string]skills.Reader{}
	for _, a := range known {
		order = append(order, a.Agent.Name)
		readers[a.Agent.Name] = a.Skills
	}
	return skills.New(order, readers, skillfile.CanTrash, skillfile.Trash)
}

// newTrust is the trust card's service: what a folder brings each agent.
func newTrust(known []knownagents.Agent, st trust.Store) *trust.Service {
	byName := map[string]trust.Agent{}
	for _, a := range known {
		byName[a.Agent.Name] = a.Trust
	}
	return trust.New(byName, st)
}

// openUsage keeps usage in the database at path (ADR 0136), and returns
// what closes them both, usage first. A database that won't open is
// logged and the daemon goes on without usage: chats never depend on it.
func openUsage(path string, st *store.Store) (*usage.Service, func()) {
	db, err := database.Open(path)
	if err != nil {
		slog.Error("usage isn't kept: opening the database", "err", err)
		u := usage.New(nil, st)
		return u, u.Close
	}
	u := usage.New(db, st)
	return u, func() {
		u.Close()
		if err := db.Close(); err != nil {
			slog.Warn("closing the database", "err", err)
		}
	}
}

// newServers is the dev servers feature (ADR 0098): each server on a
// terminal of the daemon's, with the login shell's environment (env, the
// agents'), its processes in record.
func newServers(record servers.Record, chats servers.Chats, env servers.Env, procs servers.Procs, publish func(model.Event)) *servers.Service {
	return servers.New(servers.Options{Chats: chats, Procs: procs, Env: env, Publish: publish,
		Record: record, Spawn: startServer})
}

// startServer starts a dev server's program on a terminal, whose
// foreground nothing follows.
func startServer(argv []string, dir string, env []string) (servers.Process, error) {
	return terminal.Start(argv, dir, env, 120, 40, nil)
}

// usePush gives remote access Web Push (ADR 0054): the daemon's VAPID key,
// made once and kept in vapid.json (0600), and the chats' agents' names;
// a push goes through transport (the system's proxy, as the relay link
// goes, on a company network).
func usePush(st *store.Store, r *remote.Service, chatSvc *chats.Service, kinds []chats.Kind, transport http.RoundTripper) error {
	k, ok, err := st.VAPIDKey()
	if err != nil {
		return err
	}
	fresh := !ok || len(k.Private) != 32 || len(k.Public) != 65
	if fresh {
		keys, err := webpush.NewKeys()
		if err != nil {
			return err
		}
		k = model.VAPIDKey{Private: keys.Private, Public: keys.Public}
		if err := st.SaveVAPIDKey(k); err != nil {
			return err
		}
	}
	keys := webpush.Keys{Private: k.Private, Public: k.Public}
	titles := map[string]string{}
	for _, kind := range kinds {
		info := kind.Info()
		titles[info.Name] = info.Title
	}
	r.UsePush(remote.Push{
		Key: keys.PublicKey(),
		Send: func(ctx context.Context, subject string, s webpush.Subscription, m webpush.Message) error {
			return (&webpush.Sender{Keys: keys, Subject: subject, Transport: transport}).Send(ctx, s, m)
		},
		Agent: func(chatID string) (string, bool) {
			sess, err := chatSvc.Session(chatID)
			if err != nil {
				return "", false
			}
			return titles[sess.Agent], titles[sess.Agent] != ""
		},
	}, fresh)
	return nil
}

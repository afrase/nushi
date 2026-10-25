package chats

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// opened is an agent with a session open.
type opened struct {
	agent  Agent
	sid    string
	config []model.ConfigOption
	images bool                                  // the agent takes images in prompts
	load   bool                                  // and reopens sessions
	forkAt func(messageID string) map[string]any // and forks sessions at a message
}

// openSession launches an agent and opens a session in folder: a new one,
// or, given its id, an existing one, replayed through session/load, or with
// fork a new one that starts with a copy of it (session/fork). The agent
// stops if that fails.
func (c *chat) openSession(ctx context.Context, sid, folder string, fork bool) (opened, error) {
	// The agent's lines name the sessions it opens (see internal/agentproc).
	agent, init, err := initialize(ctx, c.kind.launch, c, c.dialect.InitMeta, c.logger("", folder))
	if err != nil {
		return opened{}, c.kind.explain(err)
	}
	o := opened{agent: agent, sid: sid}
	if c.dialect.ForkAt != nil && agent.CanFork() {
		o.forkAt = c.dialect.ForkAt(init)
	}
	if caps := init.AgentCapabilities; caps != nil {
		o.load = caps.LoadSession
		o.images = caps.PromptCapabilities != nil && caps.PromptCapabilities.Image
	}
	switch {
	case sid == "":
		o.sid, o.config, err = c.newSession(ctx, agent, folder)
	case fork && !agent.CanFork():
		err = errors.New("the agent can't fork sessions")
	case fork:
		o.sid, o.config, err = c.forkSession(ctx, agent, sid, folder, nil)
	case init.AgentCapabilities == nil || !init.AgentCapabilities.LoadSession:
		err = errors.New("the agent can't reopen sessions")
	default:
		var resp *acp.LoadSessionResponse
		if resp, err = agent.LoadSession(ctx, &acp.LoadSessionRequest{SessionID: acp.SessionID(sid), Cwd: folder, MCPServers: c.mcpServers()}); err == nil {
			o.config = c.configFrom(resp.ConfigOptions, resp.Modes)
		}
	}
	if err != nil {
		_ = agent.Close() // its start failed; that error is the one to return
		return opened{}, c.kind.explain(err)
	}
	return o, nil
}

// newSession has agent start a session in folder.
func (c *chat) newSession(ctx context.Context, agent Agent, folder string) (string, []model.ConfigOption, error) {
	resp, err := agent.NewSession(ctx, &acp.NewSessionRequest{Cwd: folder, MCPServers: c.mcpServers()})
	if err != nil {
		return "", nil, err
	}
	return string(resp.SessionID), c.configFrom(resp.ConfigOptions, resp.Modes), nil
}

// forkSession has agent fork session sid with folder as the fork's cwd:
// a copy of the whole conversation, or as meta asks (see Dialect.ForkAt).
// It goes on when ctx ends (the app went): a fork the agent made would be
// a copy of the conversation nobody knows of.
func (c *chat) forkSession(ctx context.Context, agent Agent, sid, folder string, meta map[string]any) (string, []model.ConfigOption, error) {
	ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), time.Minute)
	defer cancel()
	resp, err := agent.ForkSession(ctx, &acp.ForkSessionRequest{SessionID: acp.SessionID(sid), Cwd: folder, Meta: meta, MCPServers: c.mcpServers()})
	if err != nil {
		return "", nil, err
	}
	return string(resp.SessionID), c.configFrom(resp.ConfigOptions, resp.Modes), nil
}

// Tools are the MCP servers of Nushi's own tools a chat's sessions get
// (internal/features/tools): its id, its agent, its issue.
type Tools func(chat, agent string, issue *model.ChatIssue) []acp.MCPServer

// UseTools gives chats' sessions Nushi's tools, set once at startup.
func (s *Service) UseTools(t Tools) {
	for _, k := range s.kinds {
		k.tools = t
	}
}

// mcpServers are the MCP servers of Nushi's own tools for the chat, if
// any; the agent's own come from its config.
func (c *chat) mcpServers() []acp.MCPServer {
	if c.kind.tools == nil {
		return nil
	}
	return c.kind.tools(c.id, c.kind.Name, c.issue)
}

// initialize launches an agent and initializes the connection, with meta
// as the client's _meta; the agent stops if that fails.
func initialize(ctx context.Context, launch Launch, h acp.Client, meta map[string]any, log *slog.Logger) (Agent, *acp.InitializeResponse, error) {
	agent, err := launch(h, log)
	if err != nil {
		log.Warn("agent not started", "err", err)
		return nil, nil, fmt.Errorf("start agent: %w", err)
	}
	init, err := agent.Initialize(ctx, &acp.InitializeRequest{
		ProtocolVersion: acp.LatestProtocolVersion,
		ClientCapabilities: &acp.ClientCapabilities{
			Elicitation: &acp.ElicitationCapabilities{Form: &acp.ElicitationFormCapabilities{}},
			Meta:        meta,
		},
		ClientInfo: &acp.Implementation{Name: "nushi", Title: "Nushi"},
	})
	if err != nil {
		_ = agent.Close() // as above
		return nil, nil, err
	}
	return agent, init, nil
}

// useLocked makes an opened session the chat's, on a new agent.
// What the agent sends from then on is live, not a replay (kept).
func (s *Service) useLocked(c *chat, o opened) {
	c.agent, c.canFork, c.steer, c.canImage, c.sid, c.config = o.agent, o.agent.CanFork(), o.agent.CanSteer(), o.images, o.sid, o.config
	c.forkAt, c.held, c.kept, c.ownTurn, c.reopenFailed = o.forkAt, false, false, false, false
	c.canLoad, c.asleep = o.load, false
	c.mcpChanged = false // the new agent has the MCP servers as they are now
	c.emitLocked(model.Event{ChatID: c.id, Config: slices.Clone(c.config)})
	go s.watch(c, o.agent)
}

// watch notices the agent's process ending on its own: the chat lets go of
// it and says so, its side chats end, and the next message (or opening the
// chat) reopens the session through session/load. An agent Nushi stopped or
// replaced is no longer the chat's by then.
func (s *Service) watch(c *chat, agent Agent) {
	<-agent.Done()
	c.mu.Lock()
	if c.agent != agent {
		c.mu.Unlock()
		return
	}
	c.agent, c.kept = nil, true
	c.logLocked().Error("the chat's agent quit unexpectedly", "pid", agent.Pid())
	c.orphanLocked()
	c.noticeLocked("error", "The agent quit unexpectedly. Your next message reopens the chat.")
	c.statusChangedLocked()
	c.mu.Unlock()
	s.discard(c, s.dropSides(c))
}

// orphanLocked fails what can't finish once the agent that ran it is gone:
// tool calls still pending or running (also as a replay brings them back,
// when the agent died before their results), and subagents running in the
// background.
func (c *chat) orphanLocked() {
	c.ownTurn = false
	for i, it := range c.items {
		running := it.Status == "pending" || it.Status == "in_progress" || it.Subagent != nil && it.Subagent.State == "running"
		if it.Kind == model.ToolCall && running {
			c.items[i].Status = "failed"
			c.subagentLocked(&c.items[i])
			c.publishLocked(c.items[i])
		}
	}
}

// disconnect stops the chat's agent, gently (Agent.Stop), and not under
// the lock: its last updates need it. The transcript stays as it is: a
// reopen doesn't replay into it (kept).
func (c *chat) disconnect() {
	c.mu.Lock()
	agent := c.agent
	c.agent, c.kept = nil, len(c.items) > 0
	c.orphanLocked()
	c.mu.Unlock()
	if agent != nil {
		_ = agent.Stop(stopGrace) // its process is gone either way
	}
}

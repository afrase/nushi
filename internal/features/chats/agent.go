package chats

import (
	"context"
	"errors"
	"fmt"
	"slices"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// opened is an agent with a session open.
type opened struct {
	agent  Agent
	sid    string
	config []model.ConfigOption
	images bool // the agent takes images in prompts
	rewind bool // and forks sessions at a message
}

// openSession launches an agent and opens a session in folder: a new one,
// or, given its id, an existing one, replayed through session/load, or with
// fork a new one that starts with a copy of it (session/fork). The agent
// stops if that fails.
func (c *chat) openSession(ctx context.Context, launch Launch, sid, folder string, fork bool) (opened, error) {
	agent, init, err := initialize(ctx, launch, c)
	if err != nil {
		return opened{}, err
	}
	o := opened{agent: agent, sid: sid, rewind: agent.CanFork() && forksAtMessage(init)}
	if init.AgentCapabilities != nil && init.AgentCapabilities.PromptCapabilities != nil {
		o.images = init.AgentCapabilities.PromptCapabilities.Image
	}
	switch {
	case sid == "":
		var resp *acp.NewSessionResponse
		if resp, err = agent.NewSession(ctx, acp.NewSessionRequest{Cwd: folder, MCPServers: []acp.MCPServer{}}); err == nil {
			o.sid, o.config = string(resp.SessionID), configFrom(resp.ConfigOptions, resp.Modes)
		}
	case fork && !agent.CanFork():
		err = errors.New("the agent can't fork sessions")
	case fork:
		var resp *acp.ForkSessionResponse
		if resp, err = agent.ForkSession(ctx, acp.ForkSessionRequest{SessionID: acp.SessionID(sid), Cwd: folder, MCPServers: []acp.MCPServer{}}); err == nil {
			o.sid, o.config = string(resp.SessionID), configFrom(resp.ConfigOptions, resp.Modes)
		}
	case init.AgentCapabilities == nil || !init.AgentCapabilities.LoadSession:
		err = errors.New("the agent can't reopen sessions")
	default:
		var resp *acp.LoadSessionResponse
		if resp, err = agent.LoadSession(ctx, acp.LoadSessionRequest{SessionID: acp.SessionID(sid), Cwd: folder, MCPServers: []acp.MCPServer{}}); err == nil {
			o.config = configFrom(resp.ConfigOptions, resp.Modes)
		}
	}
	if err != nil {
		agent.Close()
		return opened{}, err
	}
	return o, nil
}

// initialize launches an agent and initializes the connection; the agent
// stops if that fails.
func initialize(ctx context.Context, launch Launch, h acp.Handler) (Agent, *acp.InitializeResponse, error) {
	agent, err := launch(h)
	if err != nil {
		return nil, nil, fmt.Errorf("start agent: %w", err)
	}
	init, err := agent.Initialize(ctx, acp.InitializeRequest{
		ProtocolVersion: acp.Version,
		ClientCapabilities: &acp.ClientCapabilities{
			Elicitation: &acp.ElicitationCapabilities{Form: &acp.ElicitationFormCapabilities{}},
			// claude-agent-acp then sends a subagent's text and thinking too.
			Meta: map[string]any{"subagent-transcript": true},
		},
		ClientInfo: &acp.Implementation{Name: "nushi", Title: "Nushi"},
	})
	if err != nil {
		agent.Close()
		return nil, nil, err
	}
	return agent, init, nil
}

// useLocked makes an opened session the chat's, on a new agent.
func (s *Service) useLocked(c *chat, o opened) {
	c.agent, c.canFork, c.steer, c.canImage, c.sid, c.config = o.agent, o.agent.CanFork(), o.agent.CanSteer(), o.images, o.sid, o.config
	c.canRewind, c.held = o.rewind, false
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
	for i, it := range c.items { // they won't finish now
		if it.Kind == model.ToolCall && (it.Status == "pending" || it.Status == "in_progress") {
			c.items[i].Status = "failed"
			c.publishLocked(c.items[i])
		}
	}
	c.noticeLocked("error", "The agent quit unexpectedly. Your next message reopens the chat.")
	c.statusChangedLocked()
	c.mu.Unlock()
	s.dropSides(c)
}

// disconnect stops the chat's agent.
func (c *chat) disconnect() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.agent != nil {
		c.agent.Close()
		c.agent = nil
	}
}

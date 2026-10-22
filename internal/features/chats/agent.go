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
}

// openSession launches an agent and opens a session in folder: a new one,
// or, given its id, an existing one, replayed through session/load, or with
// fork a new one that starts with a copy of it (session/fork). The agent
// stops if that fails.
func (c *chat) openSession(ctx context.Context, launch Launch, sid, folder string, fork bool) (opened, error) {
	agent, err := launch(c)
	if err != nil {
		return opened{}, fmt.Errorf("start agent: %w", err)
	}
	o := opened{agent: agent, sid: sid}
	init, err := agent.Initialize(ctx, acp.InitializeRequest{
		ProtocolVersion:    acp.Version,
		ClientCapabilities: &acp.ClientCapabilities{Elicitation: &acp.ElicitationCapabilities{Form: &acp.ElicitationFormCapabilities{}}},
		ClientInfo:         &acp.Implementation{Name: "nushi", Title: "Nushi"},
	})
	if err == nil && init.AgentCapabilities != nil && init.AgentCapabilities.PromptCapabilities != nil {
		o.images = init.AgentCapabilities.PromptCapabilities.Image
	}
	switch {
	case err != nil:
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

// useLocked makes an opened session the chat's.
func (c *chat) useLocked(o opened) {
	c.agent, c.canFork, c.canImage, c.sid, c.config = o.agent, o.agent.CanFork(), o.images, o.sid, o.config
	c.emitLocked(model.Event{ChatID: c.id, Config: slices.Clone(c.config)})
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

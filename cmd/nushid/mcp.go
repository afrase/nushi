package main

import (
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/mcp"
	"github.com/afrase/nushi/internal/knownagents"
)

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
		services[name] = mcp.New(name, a.MCP(func() (agents.Run, error) { return agentSvc.Run(name) }), changed)
	}
	return services
}

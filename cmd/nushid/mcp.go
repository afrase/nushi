package main

import (
	"github.com/afrase/nushi/internal/ante"
	"github.com/afrase/nushi/internal/antemcp"
	"github.com/afrase/nushi/internal/claudemcp"
	"github.com/afrase/nushi/internal/features/agents"
	"github.com/afrase/nushi/internal/features/mcp"
)

// newMCP is the MCP servers of each agent whose config Nushi knows: Claude's
// through `claude mcp`, Ante's in its settings (checked by a throwaway
// `ante serve`, run as a chat's would be).
func newMCP(agentSvc *agents.Service, changed mcp.Changed) map[string]*mcp.Service {
	spawn := func() (ante.Spawn, error) {
		r, err := agentSvc.Run("ante")
		if err != nil {
			return nil, err
		}
		return ante.Server(r.CLI, r.Env, nil), nil
	}
	return map[string]*mcp.Service{
		"claude": mcp.New("claude", claudemcp.Claude{}, changed),
		"ante":   mcp.New("ante", antemcp.Ante{Spawn: spawn}, changed),
	}
}

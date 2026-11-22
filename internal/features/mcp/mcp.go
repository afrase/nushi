// Package mcp shows and changes the MCP servers an agent uses in a
// folder, one Service per agent whose config Nushi knows (Claude's,
// Ante's). The agent's own config is the source of truth: Nushi keeps no
// copy of it (ADR 0021). The scopes (user, project, local, plugin,
// claudeai) and project approvals are Claude Code's model; which server
// of a name wins is the agent's Config's to say, and an agent with less
// (Ante: user scope only) refuses the rest in its Config.
package mcp

import (
	"context"

	"github.com/afrase/nushi/internal/model"
)

// Config is the agent's MCP config (internal/claudemcp, internal/antemcp).
type Config interface {
	// Servers returns the servers the agent's config files give folder,
	// with their config as stored (secrets in clear), each that another
	// of its name wins over marked Shadowed by the agent's own rule.
	Servers(folder string) ([]model.MCPServer, error)
	// Check has the agent connect to every server it would use in folder
	// and returns how each went, by name; one only the agent knows comes
	// with its scope and config.
	Check(ctx context.Context, folder string) ([]model.MCPServer, error)
	// Add and Remove change a scope's servers, run in folder.
	Add(ctx context.Context, folder, scope, name, config string) error
	Remove(ctx context.Context, folder, scope, name string) error
	// Project is the folder the agent files folder's local servers under.
	Project(folder string) string
	// SetOn turns a server on or off for folder's project: a project
	// server is approved (on) or rejected; a user or local one is turned
	// off there as the agent's own /mcp does.
	SetOn(ctx context.Context, folder, scope, name string, on bool) error
	// Login signs in to a server through the browser, waiting until that
	// is done; Logout forgets the sign-in.
	Login(ctx context.Context, folder, name string) error
	Logout(ctx context.Context, folder, name string) error
	// UserOnly says the agent has less than Claude's model: only the
	// user's servers, with no off switch or legacy SSE. The rest is
	// refused here; this is what tells the app not to offer it. A sign-in
	// isn't part of it: a server in state needs_auth has one to offer.
	UserOnly() bool
}

// Changed tells the chats that agent's servers changed for its chats in
// the folders affected says yes to.
type Changed func(agent string, affected func(folder string) bool)

type Service struct {
	agent   string
	config  Config
	changed Changed
}

// New is the MCP servers of agent (as chats name it, "claude").
func New(agent string, config Config, changed Changed) *Service {
	return &Service{agent: agent, config: config, changed: changed}
}

// UserOnly says the agent's servers are only the user's (Config.UserOnly).
func (s *Service) UserOnly() bool { return s.config.UserOnly() }

// List returns folder's servers. With check, each gets its state, and a
// server only the agent knows is added; when checking fails, the servers
// come back unchecked with checkErr saying why.
func (s *Service) List(ctx context.Context, folder string, check bool) (servers []model.MCPServer, checkErr, err error) {
	servers, err = s.config.Servers(folder)
	if err != nil {
		return nil, nil, err
	}
	for i := range servers {
		servers[i].Config = masked(servers[i].Config)
	}
	used := map[string]int{} // the server the agent uses, by name
	for i, sv := range servers {
		if _, ok := used[sv.Name]; !ok && !sv.Shadowed {
			used[sv.Name] = i
		}
	}
	if !check {
		return servers, nil, nil
	}
	checked, checkErr := s.config.Check(ctx, folder)
	if checkErr != nil {
		return servers, checkErr, nil
	}
	for i := range servers {
		if !servers[i].Shadowed {
			servers[i].State, servers[i].Detail = "disabled", "Not in use here"
		}
	}
	for _, c := range checked {
		if i, ok := used[c.Name]; ok {
			servers[i].State, servers[i].Detail = c.State, c.Detail
			continue
		}
		if c.Scope == "" {
			c.Scope = "other"
		}
		c.Config = masked(c.Config)
		servers = append(servers, c)
	}
	return servers, nil, nil
}

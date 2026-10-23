// Package mcp shows the MCP servers the agent uses in a folder. The
// agent's own config is the source of truth: Nushi keeps no copy of it
// (ADR 0021).
package mcp

import (
	"context"

	"github.com/afrase/nushi/internal/model"
)

// Config is the agent's MCP config (Claude's: internal/claudemcp).
type Config interface {
	// Servers returns the servers the agent's config files give folder,
	// with their config as stored (secrets in clear).
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
	// SetOn approves (on) or rejects a project server for folder's
	// project.
	SetOn(ctx context.Context, folder, name string, on bool) error
	// Login signs in to a server through the browser, waiting until that
	// is done; Logout forgets the sign-in.
	Login(ctx context.Context, folder, name string) error
	Logout(ctx context.Context, folder, name string) error
}

// Changed tells the chats that the servers changed for chats in the
// folders affected says yes to.
type Changed func(affected func(folder string) bool)

type Service struct {
	config  Config
	changed Changed
}

func New(config Config, changed Changed) *Service { return &Service{config: config, changed: changed} }

// rank orders scopes as the agent picks between servers of the same name:
// local wins, then project, user, plugins and claude.ai.
var rank = map[string]int{"local": 0, "project": 1, "user": 2, "plugin": 3, "claudeai": 4, "other": 5}

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
		if j, ok := used[sv.Name]; !ok || rank[sv.Scope] < rank[servers[j].Scope] {
			used[sv.Name] = i
		}
	}
	for i := range servers {
		servers[i].Shadowed = used[servers[i].Name] != i
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
		servers = append(servers, c)
	}
	return servers, nil, nil
}

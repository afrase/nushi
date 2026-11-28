// Package mcp shows and changes the MCP servers an agent uses in a
// folder, one Service per agent whose config Nushi knows (Claude's,
// Ante's, PiG's). The agent's own config is the source of truth: Nushi
// keeps no copy of it (ADR 0021). The scopes (user, project, local,
// plugin, claudeai) and project approvals are Claude Code's model; which
// server of a name wins is the agent's Config's to say, and an agent with
// less (Ante: user scope only; PiG: user and project, a project's loaded
// with the folder's trust) says so in its Shape and refuses the rest in
// its Config.
package mcp

import (
	"context"
	"errors"

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
	// SetOn turns a server on or off: a project server for folder's
	// project, approved (on) or rejected; a user or local one as the
	// agent's own switch does (Claude's /mcp, for the project; PiG's
	// "enabled" in your file, everywhere: Shape's UserSwitch). One whose
	// switch can't act (Held) is refused with why.
	SetOn(ctx context.Context, folder, scope, name string, on bool) error
	// Login signs in to a server through the browser, waiting until that
	// is done; Logout forgets the sign-in.
	Login(ctx context.Context, folder, name string) error
	Logout(ctx context.Context, folder, name string) error
	// Shape is what the agent's config has of Claude's model, which tells
	// the app what to offer; what it hasn't, its Config refuses. A sign-in
	// isn't part of it: a server in state needs_auth has one to offer.
	Shape() model.MCPShape
	// ChecksInFolder says Check runs the agent in folder, where it reads
	// what the folder brings (Claude's `claude mcp list`), so the API
	// checks only a folder nothing untrusted runs in. Ante's runs in an
	// empty folder of its own and needs no such gate.
	ChecksInFolder() bool
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

// Shape is what the agent's config has (Config.Shape).
func (s *Service) Shape() model.MCPShape { return s.config.Shape() }

// UserOnly says the agent's servers are only the user's, with nothing
// else of Claude's model: what the app went by before Shape.
func (s *Service) UserOnly() bool {
	sh := s.config.Shape()
	return len(sh.Scopes) == 1 && sh.Scopes[0] == "user" && !sh.Switch && !sh.SSE
}

// ChecksInFolder says a check runs the agent in the folder
// (Config.ChecksInFolder).
func (s *Service) ChecksInFolder() bool { return s.config.ChecksInFolder() }

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
		if _, ok := used[sv.Name]; !ok && !sv.Shadowed && !sv.Untrusted {
			used[sv.Name] = i
		}
	}
	if !check {
		return servers, nil, nil
	}
	checked, checkErr := s.config.Check(ctx, folder)
	if checkErr != nil {
		return servers, errors.New(maskText(checkErr.Error())), nil
	}
	for i := range checked { // a failed server's words are its own output (PiG's: its stderr)
		checked[i].Detail = maskText(checked[i].Detail)
	}
	if b, ok := s.config.(byScope); ok && b.ChecksByScope() {
		return byScopeAndName(servers, checked), nil, nil
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

// folderTrust is a Config whose agent loads a folder's project servers
// only when it trusts the folder (PiG's trust.json, pi.Flavor.Trusts).
type folderTrust interface{ TrustsFolder(folder string) bool }

// TrustsFolder says whether the agent trusts folder, so loads its
// project servers; ok is false for an agent with no folder trust of its
// own (Claude's approvals, Ante's user servers).
func (s *Service) TrustsFolder(folder string) (trusted, ok bool) {
	if f, isTrust := s.config.(folderTrust); isTrust {
		return f.TrustsFolder(folder), true
	}
	return false, false
}

// byScope is a Config whose check says the scope of each server it
// reports (PiG's list: "global" or "project"), so its results are matched
// by scope and name, not by name alone.
type byScope interface{ ChecksByScope() bool }

// byScopeAndName gives servers the check's results by scope and name.
// A server the check didn't report stays unchecked: the check may not
// see all a session does (PiG's list ignores a project trusted only by
// defaultProjectTrust "always"). A result for a server another of its
// name hides counts only when that other one got a result too (the agent
// refused it, and used the hidden one instead): then it is no longer
// hidden. A result for no server listed is added, as a server only the
// agent knows.
func byScopeAndName(servers, checked []model.MCPServer) []model.MCPServer {
	at := map[[2]string]int{}
	for i, sv := range servers {
		if !sv.Untrusted {
			at[[2]string{sv.Scope, sv.Name}] = i
		}
	}
	got := map[int]bool{}
	var pending []model.MCPServer // results for hidden servers
	for _, c := range checked {
		i, ok := at[[2]string{c.Scope, c.Name}]
		switch {
		case !ok:
			if c.Scope == "" {
				c.Scope = "other"
			}
			c.Config = masked(c.Config)
			servers = append(servers, c)
		case servers[i].Shadowed:
			pending = append(pending, c)
		default:
			servers[i].State, servers[i].Detail = c.State, c.Detail
			got[i] = true
		}
	}
	for _, c := range pending {
		for j, w := range servers {
			if w.Name == c.Name && !w.Shadowed && !w.Untrusted && got[j] {
				i := at[[2]string{c.Scope, c.Name}]
				servers[i].State, servers[i].Detail, servers[i].Shadowed = c.State, c.Detail, false
				break
			}
		}
	}
	return servers
}

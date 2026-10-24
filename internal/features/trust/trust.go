// Package trust warns before a chat starts in a folder that brings its own
// code for the agent to run (MCP servers, hooks, helper commands), unless
// the agent was told to trust the folder, or the user told Nushi to start
// there anyway. It warns; it never refuses (ADR 0023).
package trust

import (
	"fmt"
	"path/filepath"

	"github.com/afrase/nushi/internal/model"
)

// Agent knows an agent's own trust record and what a folder has it run.
type Agent interface {
	Key(folder string) string // what trust is kept under (its repository's folder)
	Trusted(folder string, also []string) (bool, error)
	Runs(folder string) ([]model.FolderRun, error)
}

// Store keeps the folders the user started chats in anyway, by key.
type Store interface {
	TrustedFolders() ([]string, error)
	TrustFolder(key string) error
}

type Service struct {
	agents map[string]Agent
	store  Store
}

// New makes the service for the agents, by name.
func New(agents map[string]Agent, store Store) *Service {
	return &Service{agents: agents, store: store}
}

// Check returns what folder would have agent run when nobody trusted it,
// or nothing.
func (s *Service) Check(agent, folder string) ([]model.FolderRun, error) {
	a, err := s.agent(agent, folder)
	if err != nil {
		return nil, err
	}
	runs, err := a.Runs(folder)
	if err != nil { // can't tell what it runs: say why, and let the user decide
		runs = []model.FolderRun{{What: "Settings Nushi couldn't read", Command: err.Error()}}
	}
	if len(runs) == 0 {
		return nil, nil
	}
	also, err := s.store.TrustedFolders()
	if err != nil {
		return nil, err
	}
	if ok, err := a.Trusted(folder, also); ok || err != nil {
		return nil, err
	}
	return runs, nil
}

// Trust remembers that the user starts chats with agent in folder anyway.
func (s *Service) Trust(agent, folder string) error {
	a, err := s.agent(agent, folder)
	if err != nil {
		return err
	}
	return s.store.TrustFolder(a.Key(folder))
}

func (s *Service) agent(name, folder string) (Agent, error) {
	switch a := s.agents[name]; {
	case !filepath.IsAbs(folder):
		return nil, fmt.Errorf("%q is not an absolute path", folder)
	case a == nil:
		return nil, fmt.Errorf("Nushi doesn't know the agent %q", name)
	default:
		return a, nil
	}
}

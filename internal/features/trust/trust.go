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

// Agent knows the agent's own trust record and what a folder has it run.
type Agent interface {
	Key(folder string) string // the folder trust is kept under (its repository's)
	Trusted(folder string, also []string) (bool, error)
	Runs(folder string) ([]model.FolderRun, error)
}

// Store keeps the folders the user started chats in anyway, by key.
type Store interface {
	TrustedFolders() ([]string, error)
	TrustFolder(key string) error
}

type Service struct {
	agent Agent
	store Store
}

func New(agent Agent, store Store) *Service { return &Service{agent: agent, store: store} }

// Check returns what folder would have the agent run when nobody trusted
// it, or nothing.
func (s *Service) Check(folder string) ([]model.FolderRun, error) {
	if !filepath.IsAbs(folder) {
		return nil, fmt.Errorf("%q is not an absolute path", folder)
	}
	runs, err := s.agent.Runs(folder)
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
	if ok, err := s.agent.Trusted(folder, also); ok || err != nil {
		return nil, err
	}
	return runs, nil
}

// Trust remembers that the user starts chats in folder anyway.
func (s *Service) Trust(folder string) error {
	if !filepath.IsAbs(folder) {
		return fmt.Errorf("%q is not an absolute path", folder)
	}
	return s.store.TrustFolder(s.agent.Key(folder))
}

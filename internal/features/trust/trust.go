// Package trust warns before a chat starts in a folder that brings its own
// code for the agent to run (MCP servers, hooks, helper commands), unless
// the agent was told to trust the folder, or the user told Nushi to start
// there anyway. It warns; it never refuses (ADR 0023).
package trust

import (
	"errors"
	"fmt"
	"path/filepath"

	"github.com/afrase/nushi/internal/model"
)

// Agent knows an agent's own trust record and what a folder has it run.
type Agent interface {
	// Runs returns what folder has the agent run, and the key "Start
	// anyway" keeps that under ("" when it can't be kept): both from one
	// look at the folder.
	Runs(folder string) (runs []model.FolderRun, key string, err error)
	// Key is the key for folder as it is now.
	Key(folder string) string
	Trusted(folder string, also []string) (bool, error)
}

// ErrChanged says the folder isn't as its card showed it.
var ErrChanged = errors.New("the folder changed since you looked at it; look again")

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
// or nothing, and the key that remembers what it shows ("" when it can't
// be remembered: Start anyway is then for one start).
func (s *Service) Check(agent, folder string) ([]model.FolderRun, string, error) {
	a, err := s.agent(agent, folder)
	if err != nil {
		return nil, "", err
	}
	runs, key, err := a.Runs(folder)
	if err != nil { // can't tell what it runs: say why, and let the user decide
		runs, key = []model.FolderRun{{What: "Settings Nushi couldn't read", Command: err.Error()}}, ""
	}
	if len(runs) == 0 {
		return nil, "", nil
	}
	also, err := s.store.TrustedFolders()
	if err != nil {
		return nil, "", err
	}
	if ok, err := a.Trusted(folder, also); ok || err != nil {
		return nil, "", err
	}
	return runs, key, nil
}

// Trust remembers that the user starts chats with agent in folder anyway,
// given the key its card came with; ErrChanged when the folder is no
// longer what the card showed.
func (s *Service) Trust(agent, folder, key string) error {
	a, err := s.agent(agent, folder)
	if err != nil {
		return err
	}
	if key == "" || key != a.Key(folder) {
		return ErrChanged
	}
	return s.store.TrustFolder(key)
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

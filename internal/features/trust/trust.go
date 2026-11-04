// Package trust warns before a chat starts in a folder that brings its own
// code for the agent to run (MCP servers, hooks, helper commands), unless
// the agent was told to trust the folder, or the user told Nushi to start
// there anyway. It warns; it never refuses (ADR 0023).
package trust

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"strings"

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
	runs, key := runsOf(a, folder)
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

// runsOf is what folder has a run, and its key; when it can't tell, why,
// with no key, so the user decides for this start.
func runsOf(a Agent, folder string) ([]model.FolderRun, string) {
	runs, key, err := a.Runs(folder)
	if err != nil {
		return []model.FolderRun{{What: "Settings Nushi couldn't read", Command: err.Error()}}, ""
	}
	return runs, key
}

// UntrustedHeadError is a pull request's head that brings code for the agent
// to run that nobody trusted: what it runs, in the worktree at Folder
// (gone by the time the user looks), and Shown, the key of what it runs,
// which a start the user said "Start anyway" to gives back.
type UntrustedHeadError struct {
	Folder string
	Runs   []model.FolderRun
	Shown  string
}

func (e *UntrustedHeadError) Error() string {
	return "the pull request's head brings its own code to run"
}

// Head checks a pull request's head, checked out at folder, before the
// agent starts there (ADR 0023: the folder asked about is the one that
// starts). It is nil when the head brings nothing nobody trusted, or
// when shown is the Shown of an *UntrustedHeadError the user said "Start
// anyway" to and the head is still the commit the card was made from
// (commit, its id), running exactly that: a fork pushed again between the
// card and the start, changing what a listed hook runs and nothing listed,
// is asked about again. *UntrustedHeadError otherwise. A fork's head is an outsider's: no earlier trust counts
// (Claude's is the repository's, which any head would ride on) and Start
// anyway is for this start only. A head of the repository's own is
// remembered as a folder's card is.
func (s *Service) Head(agent, folder, commit string, fork bool, shown string) error {
	if commit == "" {
		return fmt.Errorf("the pull request's head in %s has no commit to check", folder)
	}
	var runs []model.FolderRun
	var key string
	if fork {
		a, err := s.agent(agent, folder)
		if err != nil {
			return err
		}
		runs, _ = runsOf(a, folder)
	} else {
		var err error
		if runs, key, err = s.Check(agent, folder); err != nil {
			return err
		}
	}
	if len(runs) == 0 {
		return nil
	}
	if seen := shownKey(folder, commit, runs); seen != shown {
		return &UntrustedHeadError{Folder: folder, Runs: runs, Shown: seen}
	}
	if key == "" {
		return nil
	}
	return s.store.TrustFolder(key)
}

// shownKey names what runs shows at commit, folder's path taken out of
// it: a start again checks out the same head in another worktree.
func shownKey(folder, commit string, runs []model.FolderRun) string {
	rel := make([]model.FolderRun, len(runs))
	for i, r := range runs {
		in := func(s string) string { return strings.ReplaceAll(s, folder, ".") }
		rel[i] = model.FolderRun{File: in(r.File), What: in(r.What), Command: in(r.Command)}
	}
	b, _ := json.Marshal(struct {
		Commit string
		Runs   []model.FolderRun
	}{commit, rel})
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
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

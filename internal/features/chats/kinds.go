package chats

import (
	"fmt"

	"github.com/afrase/nushi/internal/model"
)

// Kind is an agent Nushi can run: how to start it, and what it does beyond
// ACP.
type Kind struct {
	Name    string // as chats keep it, such as "claude"
	Title   string // as people read it, such as "Claude"
	Launch  Launch
	Dialect Dialect
	// History copies a session to another folder's history for a move; nil
	// when the agent's sessions can't move.
	History CopyHistory
	// Resume is the terminal command that opens one of its sessions, given
	// the session id.
	Resume string
	// MCP says its MCP servers are the ones the mcp feature shows and
	// changes.
	MCP bool
	// DeleteArchives says its session/delete archives a session rather
	// than deleting it.
	DeleteArchives bool
	// OpenElsewhere returns its sessions that a process of its own holds
	// open now, one Nushi didn't start (a terminal's): by session id, where
	// ("a terminal"). nil when that can't be told.
	OpenElsewhere func() map[string]string
}

// kind is a Kind the service runs.
type kind struct {
	Kind
	launch  Launch // Launch, refused once the service closes
	deletes *bool  // whether the agent deletes sessions, once known (under Service.mu)
}

// New makes the service for agents, the first of them the default.
func New(agents []Kind, modes Modes, sessions Sessions, worktrees Worktrees, scratch string, publish func(model.Event)) *Service {
	s := &Service{modes: modes, sessions: sessions, worktrees: worktrees,
		scratch: scratch, publish: publish, chats: map[string]*chat{}, live: map[Agent]bool{}}
	for _, k := range agents {
		s.kinds = append(s.kinds, &kind{Kind: k, launch: s.started(k.Launch)})
	}
	return s
}

// Agents returns the agents chats can run, the default first.
func (s *Service) Agents() []Kind {
	var out []Kind
	for _, k := range s.kinds {
		out = append(out, k.Kind)
	}
	return out
}

// kindOf returns the agent named name; "" is the default.
func (s *Service) kindOf(name string) (*kind, error) {
	for _, k := range s.kinds {
		if k.Name == name || name == "" {
			return k, nil
		}
	}
	return nil, fmt.Errorf("Nushi doesn't know the agent %q", name)
}

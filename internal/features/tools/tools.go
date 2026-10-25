// Package tools is the tools Nushi gives a chat's agent through an MCP
// server of its own (ADR 0043): `nushid tools-mcp`, which the agent starts
// over stdio and which asks the daemon, over its socket, for the tools
// and their results. The server holds a key the daemon made for the chat;
// the key grants only that chat's tool sets, each scoped to the chat (the
// Jira set to its issue), and never carries a credential of the user's.
package tools

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"sync"

	"github.com/afrase/nushi/internal/model"
)

// Grant is what a key lets its holder use: one chat's tools.
type Grant struct {
	Chat  string           // Nushi's id for the chat
	Agent string           // the chat's agent, such as "claude"
	Issue *model.ChatIssue // the Jira issue the chat is on, if it is
}

// Tool is a tool as MCP lists it.
type Tool struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	InputSchema json.RawMessage `json:"inputSchema"`
}

// Set is a group of tools (Jira's; review comments' later), which decides
// what a grant gets of it.
type Set interface {
	Tools(Grant) []Tool
	// Call runs one of its tools for a grant, with the arguments the agent
	// sent; the text is the agent's answer. An error is the tool failing,
	// which the agent sees as such.
	Call(ctx context.Context, g Grant, tool string, args json.RawMessage) (string, error)
}

// Service holds the keys given out while the daemon runs.
type Service struct {
	sets []Set

	mu     sync.Mutex
	grants map[string]Grant // by key
}

// New makes the service for sets.
func New(sets ...Set) *Service {
	return &Service{sets: sets, grants: map[string]Grant{}}
}

// Key is the key for a chat's tools: the one it has, or a new one. It
// lives as long as the daemon runs.
func (s *Service) Key(g Grant) string {
	s.mu.Lock()
	defer s.mu.Unlock()
	for k, have := range s.grants {
		if have.Chat == g.Chat {
			s.grants[k] = g // its issue, kept current
			return k
		}
	}
	k := rand.Text()
	s.grants[k] = g
	return k
}

// HasTools says whether a chat would get any tool.
func (s *Service) HasTools(g Grant) bool {
	for _, set := range s.sets {
		if len(set.Tools(g)) > 0 {
			return true
		}
	}
	return false
}

// ErrKey is a key the daemon didn't give out (or gave out before it
// restarted).
var ErrKey = errors.New("not a key for Nushi's tools")

func (s *Service) grant(key string) (Grant, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for k, g := range s.grants {
		if subtle.ConstantTimeCompare([]byte(k), []byte(key)) == 1 {
			return g, nil
		}
	}
	return Grant{}, ErrKey
}

// List is the tools a key grants.
func (s *Service) List(key string) ([]Tool, error) {
	g, err := s.grant(key)
	if err != nil {
		return nil, err
	}
	var out []Tool
	for _, set := range s.sets {
		out = append(out, set.Tools(g)...)
	}
	return out, nil
}

// Call runs a tool the key grants. The log says which tool, for which
// chat, and whether it worked; never the arguments or the result.
func (s *Service) Call(ctx context.Context, key, tool string, args json.RawMessage) (string, error) {
	g, err := s.grant(key)
	if err != nil {
		return "", err
	}
	for _, set := range s.sets {
		for _, t := range set.Tools(g) {
			if t.Name != tool {
				continue
			}
			text, err := set.Call(ctx, g, tool, args)
			log := slog.With("chat", g.Chat, "agent", g.Agent, "tool", tool)
			if err != nil {
				log.Info("agent's tool failed", "err", err)
			} else {
				log.Info("agent's tool ran")
			}
			return text, err
		}
	}
	return "", fmt.Errorf("no tool %q for this chat", tool)
}

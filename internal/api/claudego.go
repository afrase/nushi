package api

import (
	"log/slog"

	nushiv1 "github.com/afrase/nushi/internal/gen/nushi/v1"
)

// ClaudeGoPref keeps whether Claude's chats run through Nushi's Go agent
// rather than the adapter (internal/store; ADR 0066). The agents feature
// reads it each time a Claude chat's agent starts, so a change needs no
// restart.
type ClaudeGoPref interface {
	ClaudeGoAgent() bool
	SetClaudeGoAgent(on bool) error
}

// setClaudeGo sets what SetSettings gives of it, when given and changed.
func (s *server) setClaudeGo(set *nushiv1.Settings) error {
	if s.claudeGo == nil || set.ClaudeGoAgent == nil || *set.ClaudeGoAgent == s.claudeGo.ClaudeGoAgent() {
		return nil
	}
	if err := s.claudeGo.SetClaudeGoAgent(*set.ClaudeGoAgent); err != nil {
		return err
	}
	slog.Info("claude's agent", "go", *set.ClaudeGoAgent)
	return nil
}

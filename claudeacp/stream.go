package claudeacp

import (
	"github.com/afrase/nushi/claudeagent"
)

// stream is what the reader keeps of claude's stream: the session's
// context use.
type stream struct {
	model     string // the model of the last top-level message
	errorKind string // the API error the last top-level message named
	used      int    // tokens in the context window
	window    int    // its size, once a result has said
}

// handle maps one of claude's messages: to updates, and to turns'
// starts and ends.
func (s *session) handle(m claudeagent.Message) {
	switch m := m.(type) {
	case *claudeagent.User:
		if m.UUID != "" {
			s.echo(m.UUID)
		}
	case *claudeagent.Result:
		s.result(m)
	case *claudeagent.SessionState:
		s.mu.Lock()
		s.stateLocked(m.State)
		s.mu.Unlock()
	case *claudeagent.CompactBoundary:
		if post := m.CompactMetadata.PostTokens; post > 0 {
			s.st.used = post
			s.usage(nil, nil)
		}
	case *claudeagent.RateLimit:
		s.usage(nil, map[string]any{"_claude/rateLimit": m.Info})
	}
}

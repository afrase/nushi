package claudeacp

import (
	"regexp"
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// contextUsed sends the context's use when the last top-level message's
// counts change it.
func (s *session) contextUsed() {
	u := s.st.usage
	if used := u.InputTokens + u.OutputTokens + u.CacheReadInputTokens + u.CacheCreationInputTokens; used != s.st.used {
		s.st.used = used
		s.usage(nil, nil)
	}
}

// usage sends a usage_update: the context's use and size, cost when
// given, and meta, with the model under _claude/model.
func (s *session) usage(cost *acp.Cost, meta map[string]any) {
	if meta == nil {
		meta = map[string]any{}
	}
	if s.st.model != "" {
		meta["_claude/model"] = s.st.model
	}
	s.a.update(s.id, acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{
		Used: uint64(max(s.st.used, 0)), Size: uint64(s.size()), Cost: cost, Meta: meta, //nolint:gosec // token counts
	}})
}

// oneM is a model id or name that says it has a million-token context.
var oneM = regexp.MustCompile(`(?i)\b1m\b`)

// size is the context window's: what the last result said, else a
// million for a model whose id says 1m, else 200k.
func (s *session) size() int {
	switch {
	case s.st.window > 0:
		return s.st.window
	case oneM.MatchString(s.st.model):
		return 1_000_000
	}
	return 200_000
}

// result is the end of one of claude's turns. Every result sends the
// session's cost, with the turn's origin under _claude/origin (a
// prompt's turn says "human" when claude didn't say), which clients read
// as the end of the user's turn. A prompt's turn that showed no text
// shows the result's. Then the turn engine ends the turn.
func (s *session) result(r *claudeagent.Result) {
	if mu, ok := r.ModelUsage[s.st.model]; ok && mu.ContextWindow > 0 {
		s.st.window = mu.ContextWindow
	} else {
		for _, mu := range r.ModelUsage {
			s.st.window = max(s.st.window, mu.ContextWindow)
		}
	}
	s.mu.Lock()
	user := s.userLaneLocked(r)
	t := s.targetLocked(s.namedLocked(resultIDs(r)))
	fallback := user && t != nil && (!t.textSent || s.st.local) && !s.dropTop && r.Subtype == "success" && !r.IsError && r.Result != ""
	why := endedTurn
	if s.dropTop || t != nil && t.cancelled {
		why = endedCancel
	}
	s.mu.Unlock()
	// claude's turn is over: what it left open won't end now.
	incomplete := s.endTools(why)
	meta := map[string]any{}
	switch {
	case r.Origin != nil:
		meta["_claude/origin"] = r.Origin // as claude wrote it
	case user:
		meta["_claude/origin"] = claudeagent.Origin{Kind: "human"}
	}
	s.usage(&acp.Cost{Amount: r.TotalCostUSD, Currency: "USD"}, meta)
	if fallback {
		s.chunk("agent_message_chunk", "", r.UUID, acp.ContentBlock{Text: &acp.TextContent{Text: r.Result}})
	}
	if r.StopReason == "refusal" && s.st.refused != "" {
		s.chunk("agent_message_chunk", "", r.UUID, acp.ContentBlock{Text: &acp.TextContent{Text: s.st.refused}})
	}
	end := ending{errorKind: s.st.errorKind, incomplete: incomplete,
		login: s.st.login || r.IsError && strings.Contains(r.Result, "Please run /login")}
	s.st.local, s.st.refused, s.st.login = false, "", false
	if s.fastState(r.FastModeState, r.FastModeDisabledReason) {
		s.sendOptions()
	}
	s.mu.Lock()
	s.resultLocked(r, end)
	s.mu.Unlock()
	if user {
		s.retitle()
	}
}

package claudeacp

import (
	"strings"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// contextUsed sends the context's use when the last top-level message's
// counts change it.
func (s *session) contextUsed() {
	s.st.counted = true
	u := s.st.usage
	if used := u.InputTokens + u.OutputTokens + u.CacheReadInputTokens + u.CacheCreationInputTokens; used != s.st.used {
		s.st.used = used
		s.usage(nil, nil)
	}
}

// usage sends a usage_update (window.report) of the stream's counts.
func (s *session) usage(cost *acp.Cost, meta map[string]any) {
	s.win.report(s.st.used, s.st.model, cost, meta)
}

// report sends a usage_update: the context's use (used) and size, cost
// when given, and meta, with the model under _claude/model. It is sent
// under the window's lock, so claude's answer about the window comes
// before or after it, never in between.
func (w *window) report(used int, model string, cost *acp.Cost, meta map[string]any) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.shown = shownUsage{used: used, model: model, size: w.sizeLocked(model), ok: true}
	w.sendLocked(w.shown, cost, meta)
}

// sendLocked sends u as a usage_update.
func (w *window) sendLocked(u shownUsage, cost *acp.Cost, meta map[string]any) {
	if meta == nil {
		meta = map[string]any{}
	}
	if u.model != "" {
		meta["_claude/model"] = u.model
	}
	w.send(acp.SessionUpdate{SessionUpdate: "usage_update", UsageUpdate: &acp.UsageUpdate{
		Used: uint64(max(u.used, 0)), Size: uint64(u.size), Cost: cost, Meta: meta, //nolint:gosec // token counts
	}})
}

// result is the end of one of claude's turns. A result after a model
// call sends the session's cost, with the turn's origin under
// _claude/origin (a prompt's turn says "human" when claude didn't say),
// which clients read as the end of the user's turn. One with none (no
// top-level message's counts and no tokens: a slash command claude
// answered itself, /context, /compact) sends no usage, as
// claude-agent-acp sends none, so a session not yet counted isn't shown
// at zero. A prompt's turn that showed no text shows the result's. Then
// the turn engine ends the turn.
func (s *session) result(r *claudeagent.Result) {
	s.resultWindow(r, s.st.model)
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
	incomplete := s.tools.end(why)
	meta := map[string]any{}
	switch {
	case r.Origin != nil:
		meta["_claude/origin"] = r.Origin // as claude wrote it
	case user:
		meta["_claude/origin"] = claudeagent.Origin{Kind: "human"}
	}
	if u := r.Usage; s.st.counted || u.InputTokens+u.OutputTokens+u.CacheReadInputTokens+u.CacheCreationInputTokens > 0 {
		s.usage(&acp.Cost{Amount: r.TotalCostUSD, Currency: "USD"}, meta)
	}
	if fallback {
		s.chunk("agent_message_chunk", "", r.UUID, acp.ContentBlock{Text: &acp.TextContent{Text: r.Result}})
	}
	if r.StopReason == "refusal" && s.st.refused != "" {
		s.chunk("agent_message_chunk", "", r.UUID, acp.ContentBlock{Text: &acp.TextContent{Text: s.st.refused}})
	}
	end := ending{errorKind: s.st.errorKind, incomplete: incomplete,
		login: s.st.login || r.IsError && strings.Contains(r.Result, "Please run /login")}
	s.st.local, s.st.refused, s.st.login, s.st.counted = false, "", false, false
	if s.fastState(r.FastModeState, r.FastModeDisabledReason) {
		s.cfg.sendOptions()
	}
	s.mu.Lock()
	s.resultLocked(r, end)
	s.mu.Unlock()
	if user {
		s.retitle()
	}
}

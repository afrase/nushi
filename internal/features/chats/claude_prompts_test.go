package chats

import "testing"

// answeredAtResult checks the Go agent answers each prompt right at its
// turn's result: the usage update with the cost from a cycle the user
// started (`_claude/origin.kind` "human") is the last thing it sends on
// the prompt's session before the answer, whatever still runs in the
// background (subagent-nested, subagent-stop-taskstop: a subagent the
// turn started runs on past it). claude-agent-acp held the prompt until
// such subagents ended (docs/facts/claude.md); the Go agent doesn't, so
// a Claude turn's end for the chats is the prompt's answer. A
// prompt with no such result (a command claude answers itself, a cancel
// before any model call) is let be.
func answeredAtResult(t *testing.T, events []event) {
	t.Helper()
	resulted := map[string]bool{} // whether the session's running prompt has had its result
	last := map[string]bool{}     // whether the session's last update was its turn's result
	for _, e := range events {
		switch {
		case e.note != nil:
			s := string(e.note.SessionID)
			last[s] = humanResult(e)
			resulted[s] = resulted[s] || last[s]
		case e.method == "session/prompt" && !e.done:
			resulted[e.session], last[e.session] = false, false
		case e.method == "session/prompt":
			if resulted[e.session] && !last[e.session] {
				t.Errorf("session %s: a prompt (%q) answered past its turn's result", e.session, e.text)
			}
		}
	}
}

// humanResult says an event is a turn's result: a usage update with a
// cost, from a cycle the user started.
func humanResult(e event) bool {
	u := e.note.Update.UsageUpdate
	if u == nil || u.Cost == nil {
		return false
	}
	origin, _ := u.Meta["_claude/origin"].(map[string]any)
	return origin["kind"] == "human"
}

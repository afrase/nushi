package claudeacp

import (
	"encoding/json"
	"maps"
	"slices"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// A subagent's state, as claude's task events tell it.

// taskUpdated is a change to a task: a subagent backgrounded, or ended.
func (s *session) taskUpdated(m *claudeagent.TaskUpdated) {
	k := &s.kids
	k.mu.Lock()
	sa := k.byID[m.TaskID]
	if sa == nil || late(sa, m.RunID) {
		k.mu.Unlock()
		return
	}
	if b := m.Patch.IsBackgrounded; b != nil {
		sa.background = *b
	}
	k.mu.Unlock()
	s.taskEnded(m.TaskID, m.RunID, "", m.Patch.Status, m.Patch.Error)
}

// taskNotification is a task's end.
func (s *session) taskNotification(m *claudeagent.TaskNotification) {
	s.taskEnded(m.TaskID, m.RunID, m.ToolUseID, m.Status, m.Summary)
}

// late says a task frame of run is of a run of sa before the one claude
// runs now.
func late(sa *subagent, run string) bool { return run != "" && sa.run != "" && run != sa.run }

// taskEnded is the subagent id ending with claude's status for it ("" or
// a status that isn't an end changes nothing), once a run: it goes idle,
// saying why, and its calls still open end, as nothing will end them now.
// call is the call whose run ended, when claude says: the end of a call
// that ran it before isn't the end of this one.
func (s *session) taskEnded(id, run, call, status, text string) {
	k := &s.kids
	k.mu.Lock()
	sa := k.byID[id]
	end, ok := endState(status, text)
	stale := sa != nil && call != "" && call != sa.call && k.byCall[call] == sa
	if sa == nil || !ok || sa.ended || stale || late(sa, run) {
		k.mu.Unlock()
		return
	}
	sa.ended = true
	if sa.shown {
		s.childStateLocked(sa, end)
	}
	calls := map[string]bool{}
	for c, x := range k.byCall {
		if x == sa {
			calls[c] = true
		}
	}
	k.mu.Unlock()
	s.endSubagentTools(id, calls)
}

// endState is the state a subagent ends in for claude's status: done,
// cancelled (stopped or killed), or failed with text as its error.
func endState(status, text string) (acp.StateUpdate, bool) {
	idle := &acp.IdleStateUpdate{}
	switch status {
	case "completed":
		idle.EndTurn = true
	case "stopped", "killed", "cancelled":
		idle.Cancelled = true
	case "failed":
		idle.Error = &acp.ErrorStopReason{}
		if text != "" {
			idle.Error.Error = &acp.Error{Code: acp.ErrorCodeInternalError, Message: text}
		}
	case "disconnected": // claude can't see it anymore
		return acp.StateUpdate{Unknown: &acp.UnknownStateUpdate{}}, true
	default:
		return acp.StateUpdate{}, false
	}
	return acp.StateUpdate{Idle: idle}, true
}

// stoppedText is what a call of a subagent that ended says when it had
// no result.
const stoppedText = "The subagent stopped before this call had a result."

// endSubagentTools ends the open calls of the subagent agent, whose
// stream is one of calls.
func (s *session) endSubagentTools(agent string, calls map[string]bool) {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	for _, id := range slices.Sorted(maps.Keys(ts.byID)) {
		if t := ts.byID[id]; !t.ended && (calls[t.parent] || t.parent == "" && t.agent == agent) {
			t.ended = true
			s.sendLocked(t, report{status: acp.ToolCallStatusFailed, content: texts(stoppedText)})
		}
	}
}

// subagentsGone is claude's output ending: a subagent still running ends
// with no reason given, as none is known, and work still held goes on
// the session.
func (s *session) subagentsGone() {
	k := &s.kids
	k.mu.Lock()
	defer k.mu.Unlock()
	for _, id := range slices.Sorted(maps.Keys(k.byID)) {
		if sa := k.byID[id]; sa.shown && !sa.ended {
			sa.ended = true
			s.childStateLocked(sa, acp.StateUpdate{Other: json.RawMessage(`{"state":"idle"}`)})
		}
	}
	for len(k.order) > 0 {
		s.flushLocked(k.order[0], s.id)
	}
}

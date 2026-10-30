package claudeacp

import (
	"encoding/json"
	"maps"
	"slices"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// A subagent's state, as claude's task events and the agent's own
// requests tell it, and its stop.

// taskStarted is claude starting a task: a subagent's is announced, or
// runs again (subagents.started).
func (s *session) taskStarted(m *claudeagent.TaskStarted) {
	if m.SubagentType == "" && m.TaskType != "local_agent" {
		return // a background command's
	}
	in, stream := s.callInput(m.ToolUseID)
	s.kids.started(m, in, stream)
}

// taskUpdated is a change to a task: a subagent backgrounded, running
// again, or ended.
func (s *session) taskUpdated(m *claudeagent.TaskUpdated) {
	if s.kids.updated(m) {
		s.taskEnded(m.TaskID, m.RunID, "", m.Patch.Status, m.Patch.Error)
	}
}

// taskNotification is a task's end.
func (s *session) taskNotification(m *claudeagent.TaskNotification) {
	s.taskEnded(m.TaskID, m.RunID, m.ToolUseID, m.Status, m.Summary)
}

// taskEnded is the subagent id ending (subagents.ended), and its calls
// still open with it, as nothing will end them now.
func (s *session) taskEnded(id, run, call, status, text string) {
	if calls, ok := s.kids.ended(id, run, call, status, text); ok {
		s.endSubagentTools(id, calls)
	}
}

// resumed is a SendMessage's result: when it ran a subagent that had
// ended again, the call delegated to it.
func (s *session) resumed(call string, structured json.RawMessage) {
	var r struct {
		Success        bool   `json:"success"`
		ResumedAgentID string `json:"resumedAgentId"`
	}
	if json.Unmarshal(structured, &r) != nil || !r.Success || r.ResumedAgentID == "" {
		return
	}
	in, _ := s.callInput(call)
	s.kids.resumed(r.ResumedAgentID, call, in.Message)
}

// stopSubagent stops the subagent id alone, as a cancel of its child
// session asks: what it asks the user is withdrawn, and claude stops its
// task. Its end comes as claude reports it.
func (s *session) stopSubagent(id string) {
	s.withdraw(func(a *ask) bool { return a.agent == id })
	s.bg.Go(func() {
		if err := s.cs.StopTask(s.a.ctx, id); err != nil {
			s.log.Info("stopping a subagent", "err", err)
		}
	})
}

// child is the session one of whose subagents is the child session id.
func (a *agent) child(id string) *session {
	a.mu.Lock()
	open := slices.Collect(maps.Values(a.sessions))
	a.mu.Unlock()
	for _, s := range open {
		if s.kids.shownChild(id) {
			return s
		}
	}
	return nil
}

// updated follows a change to task m.TaskID, if it is a subagent's:
// backgrounded, or run again with no new start. It says whether the
// change is of the subagent's run now, and so may end it.
func (k *subagents) updated(m *claudeagent.TaskUpdated) bool {
	k.mu.Lock()
	defer k.mu.Unlock()
	sa := k.byID[m.TaskID]
	if sa == nil || late(sa, m.RunID) {
		return false
	}
	if b := m.Patch.IsBackgrounded; b != nil {
		sa.background = *b
	}
	if m.Patch.Status == "running" && sa.ended { // claude ran it again, with no new start
		k.againLocked(sa, "", "")
	}
	return true
}

// late says a task frame of run is of a run of sa before the one claude
// runs now.
func late(sa *subagent, run string) bool { return run != "" && sa.run != "" && run != sa.run }

// ended is the subagent id ending with claude's status for it ("" or a
// status that isn't an end changes nothing), once a run: it goes idle,
// saying why. call is the call whose run ended, when claude says: the end
// of a call that ran it before isn't the end of this one. It returns the
// calls whose streams are the subagent's, and false when nothing ended.
func (k *subagents) ended(id, run, call, status, text string) (calls map[string]bool, ok bool) {
	k.mu.Lock()
	defer k.mu.Unlock()
	sa := k.byID[id]
	end, isEnd := endState(status, text)
	stale := sa != nil && call != "" && call != sa.call && k.byCall[call] == sa
	if sa == nil || !isEnd || sa.ended || stale || late(sa, run) {
		return nil, false
	}
	sa.ended = true
	if sa.call != "" {
		if sa.endedRuns == nil {
			sa.endedRuns = map[string]bool{}
		}
		sa.endedRuns[sa.call] = true
	}
	if sa.shown {
		k.childStateLocked(sa, end)
	}
	calls = map[string]bool{}
	for c, x := range k.byCall {
		if x == sa {
			calls[c] = true
		}
	}
	return calls, true
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

// gone is claude's output ending: a subagent still running ends with no
// reason given, as none is known, and work still held goes on the
// session.
func (k *subagents) gone() {
	k.mu.Lock()
	defer k.mu.Unlock()
	for _, id := range slices.Sorted(maps.Keys(k.byID)) {
		if sa := k.byID[id]; sa.shown && !sa.ended {
			sa.ended = true
			k.childStateLocked(sa, acp.StateUpdate{Other: json.RawMessage(`{"state":"idle"}`)})
		}
	}
	for len(k.order) > 0 {
		k.flushLocked(k.order[0], k.sid)
	}
}

// resumed is the subagent agent run again by the SendMessage call with
// message.
func (k *subagents) resumed(agent, call, message string) {
	k.mu.Lock()
	defer k.mu.Unlock()
	if sa := k.byID[agent]; sa != nil {
		k.againLocked(sa, call, message)
	}
}

// asking counts a request of the subagent agent opening (+1) or closing
// (-1): it requires action while one is open, and runs again once none
// is, unless a cancel withdrew it.
func (k *subagents) asking(agent string, d int, withdrawn bool) {
	k.mu.Lock()
	defer k.mu.Unlock()
	sa := k.byID[agent]
	if sa == nil {
		return
	}
	sa.asks += d
	switch {
	case !sa.shown || sa.ended:
	case d > 0 && sa.asks == 1:
		k.childStateLocked(sa, acp.StateUpdate{RequiresAction: &acp.RequiresActionStateUpdate{}})
	case d < 0 && sa.asks == 0 && !withdrawn:
		k.childStateLocked(sa, acp.StateUpdate{Running: &acp.RunningStateUpdate{}})
	}
}

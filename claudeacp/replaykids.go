package claudeacp

import (
	"encoding/json"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
	"github.com/afrase/nushi/claudeagent/sessions"
)

// Subagents in a replay. Each is announced on the session of the stream
// that started it, as live, its first message names that call, and its
// transcript replays on its session; the subagent is kept as the
// session's, so a SendMessage after the load runs it again on the same
// session. Its end goes once the whole history is out: what the last
// task notification about it said (a user message, or a prompt claude
// queued, in whichever transcript started it: findQueued); else stopped,
// when the main agent
// stopped it; else, for one in the foreground, how its call ended; else
// idle with no reason, as nothing says (a background subagent that was
// running when claude last exited).

// replayedKid is a subagent the replay announced, and what the history
// says of its end.
type replayedKid struct {
	sa         *subagent
	background bool   // started in the background: its call's result says nothing of its end
	launched   string // its first call's result: "ok", "failed", or "" with none
	failure    string // that result's text, when it failed
	ended      string // the status of the last task notification about it
	summary    string
	stopped    bool // the main agent stopped it (TaskStop)
}

// findAgents finds the subagents' transcripts and the calls that started
// them: each one's sidecar names its call; else the call's result names
// the subagent (linkResults).
func (r *replayer) findAgents(ms []sessions.Message) {
	list, err := sessions.Store{ConfigDir: r.s.a.cfg.ConfigDir}.Subagents(r.s.id, r.cwd)
	if err != nil {
		return
	}
	for _, a := range list {
		r.byAgent[a.ID] = a
		if a.ParentToolUseID != "" {
			r.agents[a.ParentToolUseID] = a
		}
	}
	r.linkResults(ms)
}

// linkResults finds the calls in ms, the main agent's or a subagent's
// messages, whose result names a subagent with no sidecar to name its
// call (an Agent call's toolUseResult.agentId).
func (r *replayer) linkResults(ms []sessions.Message) {
	for _, m := range ms {
		var rec struct {
			Message struct {
				Content claudeagent.Blocks `json:"content"`
			} `json:"message"`
			Result struct {
				AgentID string `json:"agentId"`
			} `json:"toolUseResult"`
		}
		if m.Type != "user" || json.Unmarshal(m.Raw, &rec) != nil || len(rec.Message.Content) != 1 {
			continue
		}
		call := rec.Message.Content[0].ToolUseID
		if a, ok := r.byAgent[rec.Result.AgentID]; ok && call != "" && a.ParentToolUseID == "" {
			r.agents[call] = a
		}
	}
}

// subagent announces the subagent a, started by call (with input in) in
// the stream of stream, then replays its transcript.
func (r *replayer) subagent(stream, call string, a sessions.Subagent, in launch) {
	if r.byID[a.ID] != nil {
		return // another call ran it again: the first one showed it
	}
	sa := r.s.kids.replayed(a.ID, call, stream, in)
	if sa == nil { // the session is live and has it already
		return
	}
	kid := &replayedKid{sa: sa, background: in.Background}
	r.kids = append(r.kids, kid)
	r.byID[sa.id] = kid
	store := sessions.Store{ConfigDir: r.s.a.cfg.ConfigDir}
	ms, err := store.SubagentMessages(r.s.id, r.cwd, a.ID)
	if err != nil {
		r.s.log.Info("replaying a subagent", "agent", a.ID, "err", err)
		return
	}
	r.linkResults(ms)
	if qs, err := store.SubagentQueuedPrompts(r.s.id, r.cwd, a.ID); err == nil {
		r.place(qs, ms)
	}
	r.messages(ms, call)
}

// called is a call's result, for what it says of a subagent: the end of
// the call that started one, a SendMessage that ran one again, or a
// TaskStop of one.
func (r *replayer) called(t *tool, b claudeagent.Block, structured json.RawMessage) {
	in := r.inputs[t.id]
	if kid := r.launchOf(t.id); kid != nil && kid.launched == "" {
		kid.launched = "ok"
		if b.IsError {
			kid.launched = "failed"
			kid.failure, _ = resultParts(b.Content)
		}
		return
	}
	switch t.name {
	case "TaskStop":
		if kid := r.byID[in.TaskID]; kid != nil && !b.IsError {
			kid.stopped = true
		}
	case "SendMessage":
		var res struct {
			Success        bool   `json:"success"`
			ResumedAgentID string `json:"resumedAgentId"`
		}
		if json.Unmarshal(structured, &res) != nil || !res.Success {
			return
		}
		if kid := r.byID[res.ResumedAgentID]; kid != nil {
			r.s.kids.rerun(kid.sa, t.id, in.Message)
		}
	}
}

// launchOf is the subagent call started, if the replay announced it.
func (r *replayer) launchOf(call string) *replayedKid {
	if a, ok := r.agents[call]; ok {
		if kid := r.byID[a.ID]; kid != nil && kid.sa.call == call {
			return kid
		}
	}
	return nil
}

// findQueued reads the prompts claude kept other than as user messages
// (sessions.Store.QueuedPrompts): a task notification delivered into a
// running turn is only an attachment, and one still queued when claude
// closed only a queue-operation (docs/facts/claude.md). The end of a
// subagent started by a subagent goes to the one that started it, in that
// one's transcript (subagent). claude-agent-acp reads neither, so its
// replay leaves such a subagent idle with no reason.
func (r *replayer) findQueued(ms []sessions.Message) {
	qs, err := sessions.Store{ConfigDir: r.s.a.cfg.ConfigDir}.QueuedPrompts(r.s.id, r.cwd)
	if err != nil {
		return
	}
	r.place(qs, ms)
}

// place sets the prompts qs of a transcript whose messages are ms to be
// read after the message before each, or first when that message isn't
// replayed; one still queued comes after them all.
func (r *replayer) place(qs []sessions.Queued, ms []sessions.Message) {
	known := map[string]bool{}
	for _, m := range ms {
		known[m.UUID] = true
	}
	for _, q := range qs {
		after := q.After
		if !known[after] {
			after = ""
		}
		r.queued[after] = append(r.queued[after], q.Prompt)
	}
}

// notifiedAfter keeps what the prompts queued after the message uuid
// ("" for those first) say of subagents' ends.
func (r *replayer) notifiedAfter(uuid string) {
	for _, p := range r.queued[uuid] {
		r.notified(p)
	}
	delete(r.queued, uuid)
}

// notified keeps what the task notifications in a user message's text
// say of subagents' ends.
func (r *replayer) notified(text string) {
	for _, e := range taskEnds(text) {
		if kid := r.byID[e.id]; kid != nil {
			if _, ok := endState(e.status, ""); ok {
				kid.ended, kid.summary = e.status, e.summary
			}
		}
	}
}

// ends tells the client how each subagent announced ended.
func (r *replayer) ends() {
	ends := make([]replayEnd, 0, len(r.kids))
	for _, kid := range r.kids {
		st, ok := endState(kid.ended, kid.summary)
		switch {
		case ok:
		case kid.stopped:
			st, _ = endState("stopped", "")
		case !kid.background && kid.launched == "ok":
			st, _ = endState("completed", "")
		case !kid.background && kid.launched == "failed":
			st, _ = endState("failed", kid.failure)
		default:
			st = acp.StateUpdate{Other: json.RawMessage(`{"state":"idle"}`)}
		}
		ends = append(ends, replayEnd{kid.sa, st})
	}
	r.s.kids.replayEnded(ends)
}

// replayed is the subagent id, started by call (of the stream named
// stream) with input in, as a replay announces it, with its first
// message; nil when the session is live and has it already.
func (k *subagents) replayed(id, call, stream string, in launch) *subagent {
	k.mu.Lock()
	defer k.mu.Unlock()
	if k.byID[id] != nil {
		return nil
	}
	sa := &subagent{id: id, call: call, on: k.sid, background: in.Background}
	if p := k.byCall[stream]; p != nil && p.shown {
		sa.on = p.id
	}
	k.byID[sa.id], k.byCall[call] = sa, sa
	k.announceLocked(sa, in, "", "")
	k.delegatedLocked(sa, call, in.Prompt)
	return sa
}

// rerun is the subagent sa run again by the SendMessage call with
// message, in a replay.
func (k *subagents) rerun(sa *subagent, call, message string) {
	k.mu.Lock()
	defer k.mu.Unlock()
	sa.call, k.byCall[call] = call, sa
	k.delegatedLocked(sa, call, message)
}

// replayEnd is how a subagent a replay announced ended.
type replayEnd struct {
	sa *subagent
	st acp.StateUpdate
}

// replayEnded tells the client how each subagent a replay announced
// ended, in order.
func (k *subagents) replayEnded(ends []replayEnd) {
	k.mu.Lock()
	defer k.mu.Unlock()
	for _, e := range ends {
		e.sa.ended = true
		e.sa.endedRuns = map[string]bool{e.sa.call: true}
		k.childStateLocked(e.sa, e.st)
	}
}

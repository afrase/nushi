package claudeacp

import (
	"encoding/json"
	"slices"
	"strings"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// The turn engine: which claude messages start and end a prompt's turn.
// A prompt's user message joins claude's queue; its turn starts at
// claude's echo of it and ends at the first result after that, in the
// user's lane. Each rule below names what claude does that it follows.

// turn is a prompt from the time its user message is written until it is
// answered.
type turn struct {
	id     string          // its user message's uuid
	ids    map[string]bool // id and the steers that joined it
	steers map[string]bool // steers no result has named yet

	active    bool // claude has taken it (its echo came)
	sawResult bool // a result came since it became active
	cancelled bool // the client cancelled it while active
	held      *outcome
	textSent  bool // text reached the client during it
	usage     claudeagent.Usage

	done    chan outcome // its answer, once
	ended   chan struct{}
	settled bool
}

// outcome is a prompt's answer.
type outcome struct {
	resp *acp.PromptResponse
	err  error
}

func newTurn(id string) *turn {
	return &turn{id: id, ids: map[string]bool{id: true}, steers: map[string]bool{}, done: make(chan outcome, 1), ended: make(chan struct{})}
}

func (t *turn) ownsAny(ids []string) bool {
	return slices.ContainsFunc(ids, func(id string) bool { return t.ids[id] })
}

func (t *turn) answer(r acp.StopReason) outcome {
	u := t.usage
	read, write := uint64(u.CacheReadInputTokens), uint64(u.CacheCreationInputTokens) //nolint:gosec // token counts
	return outcome{resp: &acp.PromptResponse{StopReason: r, Usage: &acp.Usage{
		InputTokens: uint64(u.InputTokens), OutputTokens: uint64(u.OutputTokens), //nolint:gosec // token counts
		CachedReadTokens: &read, CachedWriteTokens: &write,
		TotalTokens: uint64(u.InputTokens+u.OutputTokens) + read + write, //nolint:gosec // token counts
	}}}
}

func cancelled(t *turn) outcome { return t.answer(acp.StopReasonCancelled) }

// settleLocked answers t, once, and takes it out of the queue.
func (s *session) settleLocked(t *turn, o outcome) {
	if t.settled {
		return
	}
	t.settled = true
	t.done <- o
	close(t.ended)
	s.turns = slices.DeleteFunc(s.turns, func(x *turn) bool { return x == t })
	if s.active == t {
		s.active = nil
	}
}

// ownerLocked is the queued turn a user message's uuid belongs to.
func (s *session) ownerLocked(id string) *turn {
	for _, t := range s.turns {
		if t.ids[id] {
			return t
		}
	}
	return nil
}

// activateLocked makes t the running turn. The turns queued before it
// end: claude has moved past them (folded them into the last turn, or
// ran them with no result of their own).
func (s *session) activateLocked(t *turn) {
	for len(s.turns) > 0 && s.turns[0] != t {
		before := s.turns[0]
		if before.cancelled {
			s.settleLocked(before, cancelled(before))
		} else {
			s.settleLocked(before, before.answer(acp.StopReasonEndTurn))
		}
	}
	t.active, t.sawResult = true, false
	s.active = t
	s.dropTop = false
}

// echo is claude taking a user message: the turn it belongs to starts.
// One of a prompt already answered (cancelled) starts nothing.
func (s *session) echo(id string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if t := s.ownerLocked(id); t != nil && !t.active {
		s.activateLocked(t)
	}
}

// autonomous are the origins of turns claude runs on its own (a
// background task's end, another agent's message): no prompt's.
var autonomous = map[string]bool{"task-notification": true, "peer": true, "coordinator": true, "observer": true, "observer-activity": true}

func resultIDs(r *claudeagent.Result) []string {
	ids := slices.Clone(r.UserMessageUUIDs)
	if r.UserMessageUUID != "" {
		ids = append(ids, r.UserMessageUUID)
	}
	return ids
}

// namedLocked are the queued turns that own a uuid of ids, in order;
// orphan is a result that names only prompts no longer queued (the
// stopped work of a cancelled one).
func (s *session) namedLocked(ids []string) (named []*turn, orphan bool) {
	for _, t := range s.turns {
		if t.ownsAny(ids) {
			named = append(named, t)
		}
	}
	return named, len(ids) > 0 && len(named) == 0
}

// userLaneLocked says whether r ends a prompt's turn rather than one
// claude ran on its own; a result naming a queued prompt is that
// prompt's whatever its origin.
func (s *session) userLaneLocked(r *claudeagent.Result) bool {
	named, _ := s.namedLocked(resultIDs(r))
	return len(named) > 0 || r.Origin == nil || !autonomous[r.Origin.Kind]
}

// targetLocked is the turn a user-lane result ends: the running one, or
// one it names; failing both, the queue's head, for a result with no
// echo before it (a slash command claude ran itself, a compaction).
func (s *session) targetLocked(named []*turn, orphan bool) *turn {
	switch {
	case orphan:
		return nil
	case s.active != nil:
		return s.active
	case len(named) > 0:
		return named[0]
	case len(s.turns) > 0:
		return s.turns[0]
	}
	return nil
}

// resultLocked ends the turn r ends, with r's stop reason; the prompts
// r names that claude folded into it end with it. While a steer that
// joined the turn is unnamed, the turn waits for a result that names it,
// or the idle after this one.
func (s *session) resultLocked(r *claudeagent.Result, errorKind string) {
	ids := resultIDs(r)
	named, orphan := s.namedLocked(ids)
	t := s.targetLocked(named, orphan)
	if !s.userLaneLocked(r) || t == nil {
		s.owedIdle++
		return
	}
	if !t.active {
		s.activateLocked(t)
	}
	t.usage = addUsage(t.usage, r.Usage)
	t.sawResult = true
	for _, id := range ids {
		delete(t.steers, id)
	}
	o := stop(r, t, errorKind)
	if len(t.steers) > 0 && !t.cancelled {
		t.held = &o
		return
	}
	for _, n := range named {
		if n != t {
			s.settleLocked(n, n.answer(acp.StopReasonEndTurn))
		}
	}
	s.settleLocked(t, o)
	s.owedIdle++
}

// stateLocked follows claude's session state. Running clears the idles
// owed to earlier results; an idle not owed to one ends the running turn:
// with the result it held for a steer, as cancelled, or, when no result
// came at all, as failed.
func (s *session) stateLocked(state string) {
	switch state {
	case "running":
		s.owedIdle = 0
	case "idle":
		if s.owedIdle > 0 {
			s.owedIdle--
			return
		}
		t := s.active
		switch {
		case t == nil:
		case t.held != nil:
			s.settleLocked(t, *t.held)
		case t.cancelled:
			s.settleLocked(t, cancelled(t))
		case !t.sawResult:
			s.settleLocked(t, outcome{err: &acp.Error{Code: acp.ErrorCodeInternalError,
				Message: "Claude stopped without finishing the turn.", Data: []byte(`{"errorKind":"no_result"}`)}})
		}
	}
}

// stop is the outcome r gives t: a stop reason, or for a failed turn
// claude's error. errorKind is the API error the turn's last message
// named, if any.
func stop(r *claudeagent.Result, t *turn, errorKind string) outcome {
	if t.cancelled {
		return cancelled(t)
	}
	switch {
	case r.StopReason == "refusal":
		return t.answer(acp.StopReasonRefusal)
	case r.StopReason == "max_tokens" && (r.Subtype == "success" || r.Subtype == "error_during_execution"):
		return t.answer(acp.StopReasonMaxTokens)
	case r.IsError:
		msg := r.Result
		if msg == "" {
			msg = strings.Join(r.Errors, ", ")
		}
		if msg == "" {
			msg = "Claude's turn failed (" + r.Subtype + ")."
		}
		e := &acp.Error{Code: acp.ErrorCodeInternalError, Message: msg}
		if errorKind != "" {
			e.Data, _ = json.Marshal(map[string]string{"errorKind": errorKind})
		}
		return outcome{err: e}
	case r.Subtype == "error_max_turns", r.Subtype == "error_max_budget_usd", r.Subtype == "error_max_structured_output_retries":
		return t.answer(acp.StopReasonMaxTurnRequests)
	}
	return t.answer(acp.StopReasonEndTurn)
}

func addUsage(a, b claudeagent.Usage) claudeagent.Usage {
	a.InputTokens += b.InputTokens
	a.OutputTokens += b.OutputTokens
	a.CacheReadInputTokens += b.CacheReadInputTokens
	a.CacheCreationInputTokens += b.CacheCreationInputTokens
	return a
}

// backstop is how long a cancelled turn waits for claude's result or
// idle before it is answered anyway.
const backstop = 30 * time.Second

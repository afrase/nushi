package claudeacp

import (
	"cmp"
	"encoding/json"
	"slices"
	"sync"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/claudeagent"
)

// Subagents as sessions of their own (ACP's subagents RFD), for a client
// that takes them: each subagent claude runs is a child session whose id
// is claude's task id for it, as claude-agent-acp has it. The child is
// announced on the session that started it (subagent_update), with the
// Agent call's role and description; its first message (session_message)
// names that call and carries its prompt; its work goes on the child,
// each update still naming the call in _meta.claudeCode.parentToolUseId;
// and its state follows claude's task events: running, requires_action
// while it asks the user, idle with why once it ends. The Agent call
// itself stays where it was made. Cancelling the child stops that
// subagent alone (stop_task). A client without subagents gets all of it
// on the session, as before; a background command is a task too, but its
// call says all there is of it (toolResponse.backgroundTaskId).

// subagent is one of claude's subagents.
type subagent struct {
	id         string // claude's task id for it, and the child session's
	call       string // the call that started it, or ran it again last
	run        string // claude's run of it now: a frame of an earlier one is late
	on         string // the session it was announced on
	background bool   // a parent's cancel spares it
	shown      bool   // announced to the client
	asks       int    // its permission and question requests open
	ended      bool
	endedRuns  map[string]bool // the calls whose run of it has ended
}

// subagents are a session's subagents. What goes to their children goes
// out under mu, so a child's announcement comes before its work.
type subagents struct {
	mu     sync.Mutex
	byID   map[string]*subagent           // by task id
	byCall map[string]*subagent           // by each call that started or ran one
	held   map[string][]acp.SessionUpdate // a call's work, until claude says whose it is
	order  []string                       // held's calls, oldest first
	nheld  int
}

// The bounds of held, as claude-agent-acp's: calls, updates in all, and
// updates of one call.
const (
	maxHeldCalls   = 64
	maxHeld        = 256
	maxHeldPerCall = 32
)

func (k *subagents) init() {
	k.byID, k.byCall, k.held = map[string]*subagent{}, map[string]*subagent{}, map[string][]acp.SessionUpdate{}
}

// emit sends an update of the stream of call parent ("" at the top): a
// subagent's goes to its child, and waits while claude hasn't said which
// subagent the call started.
func (s *session) emit(parent string, u acp.SessionUpdate) {
	if parent == "" || !s.children {
		s.a.update(s.id, u)
		return
	}
	k := &s.kids
	k.mu.Lock()
	defer k.mu.Unlock()
	if sa := k.byCall[parent]; sa != nil && sa.shown {
		s.a.update(sa.id, u)
		return
	}
	if _, ok := k.held[parent]; !ok {
		k.order = append(k.order, parent)
	}
	k.held[parent] = append(k.held[parent], u)
	k.nheld++
	// Past the bounds the oldest work goes on the session, as a client
	// without subagents has it: it still names its call.
	for len(k.order) > maxHeldCalls || k.nheld > maxHeld {
		s.flushLocked(k.order[0], s.id)
	}
	if len(k.held[parent]) > maxHeldPerCall {
		s.flushLocked(parent, s.id)
	}
}

// flushLocked sends the work held for call to session to.
func (s *session) flushLocked(call, to string) {
	k := &s.kids
	for _, u := range k.held[call] {
		s.a.update(to, u)
	}
	k.nheld -= len(k.held[call])
	delete(k.held, call)
	k.order = slices.DeleteFunc(k.order, func(c string) bool { return c == call })
}

// release sends what is held for call on the session: the call has ended
// and claude never said it started a subagent.
func (s *session) release(call string) {
	k := &s.kids
	k.mu.Lock()
	defer k.mu.Unlock()
	if k.byCall[call] == nil {
		s.flushLocked(call, s.id)
	}
}

// callOf is the call the subagent agent works for, "" when it isn't
// known: what its requests name as their parent.
func (s *session) callOf(agent string) string {
	k := &s.kids
	k.mu.Lock()
	defer k.mu.Unlock()
	if sa := k.byID[agent]; sa != nil {
		return sa.call
	}
	return ""
}

// sessionOf is the session a request of the subagent agent goes to: its
// child once announced, else this one.
func (s *session) sessionOf(agent string) string {
	k := &s.kids
	k.mu.Lock()
	defer k.mu.Unlock()
	if sa := k.byID[agent]; sa != nil && sa.shown {
		return sa.id
	}
	return s.id
}

// inBackground says the subagent agent runs in the background, where a
// cancel of the session's turn doesn't reach.
func (s *session) inBackground(agent string) bool {
	k := &s.kids
	k.mu.Lock()
	defer k.mu.Unlock()
	sa := k.byID[agent]
	return sa != nil && sa.background && !sa.ended
}

// launch is what the call that starts a subagent says of it.
type launch struct {
	Name         string `json:"name"`
	Description  string `json:"description"`
	SubagentType string `json:"subagent_type"`
	Prompt       string `json:"prompt"`
	Message      string `json:"message"` // a SendMessage's
	Background   bool   `json:"run_in_background"`
	TaskID       string `json:"task_id"` // a TaskStop's
}

// callInput is the input of the call id as the client was last shown it,
// and the stream it is of.
func (s *session) callInput(id string) (in launch, stream string) {
	ts := &s.tools
	ts.mu.Lock()
	defer ts.mu.Unlock()
	if t := ts.byID[id]; t != nil {
		_ = json.Unmarshal([]byte(t.sent["rawInput"]), &in)
		return in, t.parent
	}
	return in, ""
}

// taskStarted is claude starting a task. A subagent's is announced, or,
// when it ran before, runs again for the call that started it now.
func (s *session) taskStarted(m *claudeagent.TaskStarted) {
	if m.SubagentType == "" && m.TaskType != "local_agent" {
		return // a background command's
	}
	in, stream := s.callInput(m.ToolUseID)
	k := &s.kids
	k.mu.Lock()
	defer k.mu.Unlock()
	if sa := k.byID[m.TaskID]; sa != nil {
		sa.run, sa.background = m.RunID, m.IsBackgrounded
		s.againLocked(sa, m.ToolUseID, cmp.Or(m.Prompt, in.Message, in.Prompt))
		return
	}
	sa := &subagent{id: m.TaskID, call: m.ToolUseID, run: m.RunID, background: m.IsBackgrounded}
	k.byID[sa.id] = sa
	if sa.call != "" {
		k.byCall[sa.call] = sa
	}
	if !s.children {
		return
	}
	// A subagent's subagent is announced on its parent's child.
	sa.on = s.id
	if p := cmp.Or(k.byID[m.ParentTaskID], k.byCall[stream]); p != nil && p.shown {
		sa.on = p.id
	}
	s.announceLocked(sa, in, m.SubagentType, m.Description)
	s.delegatedLocked(sa, sa.call, cmp.Or(in.Prompt, m.Prompt))
}

// announceLocked tells the client of the subagent sa, on the session
// sa.on: its role and description from in, the input of the call that
// started it, else role and description.
func (s *session) announceLocked(sa *subagent, in launch, role, description string) {
	role = cmp.Or(in.SubagentType, role)
	title := role
	if in.Name != "" && role != "" {
		title = in.Name + " (" + role + ")"
	} else if in.Name != "" {
		title = in.Name
	}
	su := &acp.SubagentUpdate{SessionID: acp.SessionID(sa.id),
		Capabilities: acp.Nullable[acp.SubagentSessionCapabilities]{Value: &acp.SubagentSessionCapabilities{Cancel: &acp.SessionCancelCapabilities{}}, Present: true},
		State:        stateOf(acp.StateUpdate{Running: &acp.RunningStateUpdate{}})}
	if title != "" {
		su.Title = acp.Nullable[string]{Value: &title, Present: true}
	}
	if d := cmp.Or(in.Description, description); d != "" {
		su.Description = acp.Nullable[string]{Value: &d, Present: true}
	}
	s.a.update(sa.on, acp.SessionUpdate{SessionUpdate: "subagent_update", SubagentUpdate: su})
	sa.shown = true
}

// againLocked is the subagent sa running again for call (a SendMessage's,
// or a new start of it) with prompt: it runs, and call delegated to it,
// unless it had already (claude may say so twice: the SendMessage's
// result, then the task's start). The result can come after the run it
// started has ended, and then runs nothing.
func (s *session) againLocked(sa *subagent, call, prompt string) {
	k := &s.kids
	fresh := call != "" && k.byCall[call] != sa
	if call != "" && !fresh && sa.endedRuns[call] {
		return
	}
	if fresh {
		sa.call = call
		k.byCall[call] = sa
	}
	if !sa.shown {
		return
	}
	if sa.ended {
		sa.ended = false
		s.childStateLocked(sa, acp.StateUpdate{Running: &acp.RunningStateUpdate{}})
	}
	if fresh {
		s.delegatedLocked(sa, call, prompt)
	}
}

// delegatedLocked sends the child sa its message from call, which names
// the call (clients find the Agent call by it), then the call's work held
// so far.
func (s *session) delegatedLocked(sa *subagent, call, prompt string) {
	if call == "" {
		return
	}
	m := &acp.SessionMessage{MessageID: acp.MessageID(call), RecipientSessionID: acp.SessionID(sa.id)}
	if prompt != "" {
		c := []acp.ContentBlock{{Text: &acp.TextContent{Text: prompt}}}
		m.Content = acp.Nullable[[]acp.ContentBlock]{Value: &c, Present: true}
	}
	s.a.update(sa.id, acp.SessionUpdate{SessionUpdate: "session_message", SessionMessage: m})
	s.flushLocked(call, sa.id)
}

// childStateLocked tells the client the subagent sa's state.
func (s *session) childStateLocked(sa *subagent, st acp.StateUpdate) {
	s.a.update(sa.on, acp.SessionUpdate{SessionUpdate: "subagent_update", SubagentUpdate: &acp.SubagentUpdate{
		SessionID: acp.SessionID(sa.id), State: stateOf(st)}})
}

func stateOf(st acp.StateUpdate) acp.Nullable[acp.StateUpdate] {
	return acp.Nullable[acp.StateUpdate]{Value: &st, Present: true}
}

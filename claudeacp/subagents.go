package claudeacp

import (
	"cmp"
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

// subagents are a session's subagents, and the way every update of a
// stream goes to the client: a subagent's work to its child. What goes to
// their children goes out under mu, so a child's announcement comes
// before its work.
type subagents struct {
	sid      string                                // the session's id
	children bool                                  // the client takes subagents as sessions of their own
	send     func(sid string, u acp.SessionUpdate) // to the client

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

func (k *subagents) init(sid string, children bool, send func(string, acp.SessionUpdate)) {
	k.sid, k.children, k.send = sid, children, send
	k.byID, k.byCall, k.held = map[string]*subagent{}, map[string]*subagent{}, map[string][]acp.SessionUpdate{}
}

// emit sends an update of the stream of call parent ("" at the top): a
// subagent's goes to its child, and waits while claude hasn't said which
// subagent the call started.
func (k *subagents) emit(parent string, u acp.SessionUpdate) {
	if parent == "" || !k.children {
		k.send(k.sid, u)
		return
	}
	k.mu.Lock()
	defer k.mu.Unlock()
	if sa := k.byCall[parent]; sa != nil && sa.shown {
		k.send(sa.id, u)
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
		k.flushLocked(k.order[0], k.sid)
	}
	if len(k.held[parent]) > maxHeldPerCall {
		k.flushLocked(parent, k.sid)
	}
}

// flushLocked sends the work held for call to session to.
func (k *subagents) flushLocked(call, to string) {
	for _, u := range k.held[call] {
		k.send(to, u)
	}
	k.nheld -= len(k.held[call])
	delete(k.held, call)
	k.order = slices.DeleteFunc(k.order, func(c string) bool { return c == call })
}

// release sends what is held for call on the session: the call has ended
// and claude never said it started a subagent.
func (k *subagents) release(call string) {
	k.mu.Lock()
	defer k.mu.Unlock()
	if k.byCall[call] == nil {
		k.flushLocked(call, k.sid)
	}
}

// callOf is the call the subagent agent works for, "" when it isn't
// known: what its requests name as their parent.
func (k *subagents) callOf(agent string) string {
	k.mu.Lock()
	defer k.mu.Unlock()
	if sa := k.byID[agent]; sa != nil {
		return sa.call
	}
	return ""
}

// sessionOf is the session a request of the subagent agent goes to: its
// child once announced, else the session.
func (k *subagents) sessionOf(agent string) string {
	k.mu.Lock()
	defer k.mu.Unlock()
	if sa := k.byID[agent]; sa != nil && sa.shown {
		return sa.id
	}
	return k.sid
}

// inBackground says the subagent agent runs in the background, where a
// cancel of the session's turn doesn't reach.
func (k *subagents) inBackground(agent string) bool {
	k.mu.Lock()
	defer k.mu.Unlock()
	sa := k.byID[agent]
	return sa != nil && sa.background && !sa.ended
}

// shownChild says the child session id is one of these subagents'.
func (k *subagents) shownChild(id string) bool {
	k.mu.Lock()
	defer k.mu.Unlock()
	sa := k.byID[id]
	return sa != nil && sa.shown
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

// started is claude starting a subagent's task, for the call whose input
// is in, of the stream stream. A new one is announced; one that ran
// before runs again for the call that started it now.
func (k *subagents) started(m *claudeagent.TaskStarted, in launch, stream string) {
	k.mu.Lock()
	defer k.mu.Unlock()
	if sa := k.byID[m.TaskID]; sa != nil {
		sa.run, sa.background = m.RunID, m.IsBackgrounded
		k.againLocked(sa, m.ToolUseID, cmp.Or(m.Prompt, in.Message, in.Prompt))
		return
	}
	sa := &subagent{id: m.TaskID, call: m.ToolUseID, run: m.RunID, background: m.IsBackgrounded}
	k.byID[sa.id] = sa
	if sa.call != "" {
		k.byCall[sa.call] = sa
	}
	if !k.children {
		return
	}
	// A subagent's subagent is announced on its parent's child.
	sa.on = k.sid
	if p := cmp.Or(k.byID[m.ParentTaskID], k.byCall[stream]); p != nil && p.shown {
		sa.on = p.id
	}
	k.announceLocked(sa, in, m.SubagentType, m.Description)
	k.delegatedLocked(sa, sa.call, cmp.Or(in.Prompt, m.Prompt))
}

// announceLocked tells the client of the subagent sa, on the session
// sa.on: its role and description from in, the input of the call that
// started it, else role and description.
func (k *subagents) announceLocked(sa *subagent, in launch, role, description string) {
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
	k.send(sa.on, acp.SessionUpdate{SessionUpdate: "subagent_update", SubagentUpdate: su})
	sa.shown = true
}

// againLocked is the subagent sa running again for call (a SendMessage's,
// or a new start of it) with prompt: it runs, and call delegated to it,
// unless it had already (claude may say so twice: the SendMessage's
// result, then the task's start). The result can come after the run it
// started has ended, and then runs nothing.
func (k *subagents) againLocked(sa *subagent, call, prompt string) {
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
		k.childStateLocked(sa, acp.StateUpdate{Running: &acp.RunningStateUpdate{}})
	}
	if fresh {
		k.delegatedLocked(sa, call, prompt)
	}
}

// delegatedLocked sends the child sa its message from call, which names
// the call (clients find the Agent call by it), then the call's work held
// so far.
func (k *subagents) delegatedLocked(sa *subagent, call, prompt string) {
	if call == "" {
		return
	}
	m := &acp.SessionMessage{MessageID: acp.MessageID(call), RecipientSessionID: acp.SessionID(sa.id)}
	if prompt != "" {
		c := []acp.ContentBlock{{Text: &acp.TextContent{Text: prompt}}}
		m.Content = acp.Nullable[[]acp.ContentBlock]{Value: &c, Present: true}
	}
	k.send(sa.id, acp.SessionUpdate{SessionUpdate: "session_message", SessionMessage: m})
	k.flushLocked(call, sa.id)
}

// childStateLocked tells the client the subagent sa's state.
func (k *subagents) childStateLocked(sa *subagent, st acp.StateUpdate) {
	k.send(sa.on, acp.SessionUpdate{SessionUpdate: "subagent_update", SubagentUpdate: &acp.SubagentUpdate{
		SessionID: acp.SessionID(sa.id), State: stateOf(st)}})
}

func stateOf(st acp.StateUpdate) acp.Nullable[acp.StateUpdate] {
	return acp.Nullable[acp.StateUpdate]{Value: &st, Present: true}
}

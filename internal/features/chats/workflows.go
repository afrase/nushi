package chats

import (
	"cmp"
	"errors"
	"fmt"
	"io/fs"
	"reflect"
	"slices"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// A workflow (ADR 0127) is a run a tool call launched, which goes on past
// the call, its agents writing only to the agent's own files: Claude's
// Workflow. The call answers at once and the turn ends, so the chat
// follows the run from those files (WorkflowReader) and counts it as
// working while it runs. Nothing in what the agent sends says reliably that
// a run ended: Claude's snapshot of it does, and when that never comes,
// the agent's going does.

// follow is a workflow being followed: the agent that ran it (nil when
// the chat reopened since: no agent of this daemon's runs it), and a poke
// that has it read at once.
type follow struct {
	owner   Agent
	poke    chan struct{}
	found   bool      // its files were read once
	since   time.Time // when following began
	gone    time.Time // when its owner was first seen gone
	missing time.Time // when its files, found before, were first not there
}

// workflowLocked notices a call that launched a workflow and follows it,
// once the call completed: its run (model.Workflow) as the harness read
// it from the call, or now from the whole call (a replay has no more),
// which the harness says is a launch or not.
func (c *chat) workflowLocked(it *model.Item) {
	r := c.kind.workflows
	if r == nil || it.Kind != model.ToolCall || it.Status != "completed" || it.Parent != "" || c.muted {
		return
	}
	if it.Workflow == nil {
		if it.Workflow = r.LaunchedWorkflow(*it); it.Workflow == nil {
			return
		}
		it.TaskID = it.Workflow.TaskID
	}
	if it.Workflow.State.Ended() || c.following[it.ID] != nil {
		return
	}
	if it.Workflow.Session == "" { // where its files are, from now on
		w := *it.Workflow
		w.Session, w.Folder = c.sid, c.record.Folder
		it.Workflow = &w
	}
	f := &follow{poke: make(chan struct{}, 1), since: time.Now()}
	// The agent running now ran it, unless the chat is reopening: a run
	// followed again after its items were let go is still its agent's.
	if !c.reopeningLocked() && c.agent != nil {
		f.owner = c.agent
		if it.Workflow.State == "" {
			w := *it.Workflow
			w.Started = time.Now()
			it.Workflow = &w
		}
	}
	if c.following == nil {
		c.following = map[string]*follow{}
	}
	c.following[it.ID] = f
	go c.followWorkflow(it.ID, f)
}

// followWorkflowsLocked follows the workflows of the chat's items that
// may still run: after a reopen or a copy read back, none is followed.
func (c *chat) followWorkflowsLocked() {
	for i := range c.items {
		if it := &c.items[i]; it.Kind == model.ToolCall && (it.Workflow == nil || !it.Workflow.State.Ended()) {
			c.workflowLocked(it)
		}
	}
}

// workflowLiveLocked says a workflow of the chat's hasn't ended: running,
// or stalled (nothing says it ended). A Move or a rewind would stop the
// claude that runs it (another session), so neither starts while one is.
func (c *chat) workflowLiveLocked() bool {
	return slices.ContainsFunc(c.items, func(it model.Item) bool { return it.Workflow != nil && it.Workflow.State == model.RunRunning })
}

// pokeWorkflowsLocked has each workflow followed read its files now:
// something happened that may be its end (an own turn starting, as its
// notification does; the agent going; a task stopped).
func (c *chat) pokeWorkflowsLocked() {
	for _, f := range c.following {
		select {
		case f.poke <- struct{}{}:
		default:
		}
	}
}

// followWorkflow reads the run of call callID until it ended, the call is
// gone (a rewind) or the service closes.
func (c *chat) followWorkflow(callID string, f *follow) {
	defer func() {
		c.mu.Lock()
		if c.following[callID] == f {
			delete(c.following, callID)
		}
		c.mu.Unlock()
	}()
	for {
		c.mu.Lock()
		it := c.itemLocked(callID)
		if it == nil || it.Workflow == nil || c.svc.ctx.Err() != nil {
			c.mu.Unlock()
			return
		}
		sid, folder, w := c.sidFolderLocked(*it)
		// The run lives in the claude of the session that launched it: that
		// agent gone, or the chat on another session (it stops that claude),
		// the run went with it.
		gone := f.owner != nil && (c.agent != f.owner || c.sid != sid)
		c.mu.Unlock()
		got, err := c.kind.workflows.ReadWorkflow(sid, folder, w)
		c.mu.Lock()
		it = c.itemLocked(callID)
		if it == nil || it.Workflow == nil {
			c.mu.Unlock()
			return
		}
		next, wait := c.judgeWorkflow(*it.Workflow, got, err, f, gone, time.Now())
		// Its end, seen now, of a run this daemon's agent ran: said once
		// (ADR 0141). A run found ended on a reopen or a replay isn't one.
		ended := f.owner != nil && next != nil && next.State.Ended() && !it.Workflow.State.Ended()
		c.setWorkflowLocked(it, next, ended)
		final := next == nil || next.State.Ended()
		c.mu.Unlock()
		if final {
			return
		}
		select {
		case <-time.After(wait):
		case <-f.poke:
		case <-c.svc.ctx.Done():
			return
		}
	}
}

// workflowStall is how long a run's files stay still, its agent alive,
// before it shows as stalled (ADR 0127).
const workflowStall = time.Hour

// judgeWorkflow is what a read of a run (got, err) makes of it (cur), and
// how long to wait for the next read; nil when it is no workflow to show
// after all (its files never came: the call shows as a plain one). Once
// its files were found, a read that fails is judged on the run as last
// read: its agent gone, its files still too long or gone for good end it
// all the same, so no run reads "running" for good.
func (c *chat) judgeWorkflow(cur, got model.Workflow, err error, f *follow, gone bool, now time.Time) (*model.Workflow, time.Duration) {
	poll := c.svc.timing.workflowPoll()
	switch {
	case err != nil && !f.found && now.Sub(f.since) >= c.svc.timing.workflowFind():
		return nil, 0
	case err != nil && !f.found && !errors.Is(err, fs.ErrNotExist) && f.owner == nil:
		return nil, 0 // a past run whose files can't be read
	case err != nil && !f.found: // not there yet, or a read that failed: the next one may not
		return &cur, poll
	case err != nil:
		got = cur
		if !errors.Is(err, fs.ErrNotExist) {
			f.missing = time.Time{}
		} else if f.missing.IsZero() {
			f.missing = now
		}
	default:
		f.found, f.missing = true, time.Time{}
		if got.State.Ended() {
			return &got, 0
		}
	}
	got.Stalled = false
	switch {
	case f.owner != nil && gone && f.gone.IsZero():
		f.gone = now // a last read after a grace, for the snapshot it may have left
		return &got, c.svc.timing.workflowGrace()
	case f.owner != nil && gone:
		return quit(got, now, c.kind.Title), 0
	case !f.missing.IsZero() && now.Sub(f.missing) >= c.svc.timing.workflowFind():
		got.State, got.End, got.Ended, got.Running, got.RunningCount = model.RunUnknown, "its files are gone", now, nil, 0
		return &got, 0 // Claude's files of the run went (a Move, the session deleted)
	case f.owner == nil && now.Sub(got.Active) >= c.svc.timing.workflowQuiet():
		return quit(got, now, c.kind.Title), 0 // no agent of this daemon's runs it, and its files are still
	case f.owner != nil && now.Sub(got.Active) >= workflowStall:
		got.Stalled = true
		return &got, c.svc.timing.workflowStalledPoll()
	}
	return &got, poll
}

// quit is w ended with the agent that ran it, title as people read the
// agent's name: a run lives in the agent's process, and Claude itself
// calls a run it left so stopped.
func quit(w model.Workflow, now time.Time, title string) *model.Workflow {
	w.State, w.End, w.Ended, w.Running, w.RunningCount = model.RunStopped, title+" quit while it ran", now, nil, 0
	return &w
}

// setWorkflowLocked sets the call's run and publishes it when it changed
// (its files' time aside, which changes with every write). A run once set
// is never changed in place: copies of the item handed out (GetWorkflow's,
// a published event's) share it and read it without the chat's lock.
// ended marks its event as the run's end, seen as it came
// (model.Event.WorkflowEnded).
func (c *chat) setWorkflowLocked(it *model.Item, w *model.Workflow, ended bool) {
	if w != nil && it.Workflow != nil {
		was, now := *it.Workflow, *w
		was.Active, now.Active = time.Time{}, time.Time{}
		if reflect.DeepEqual(was, now) {
			kept := *it.Workflow
			kept.Active = w.Active
			it.Workflow = &kept
			return
		}
	}
	it.Workflow = w
	if w == nil {
		it.TaskID = ""
	}
	published := *it
	c.emitLocked(model.Event{ChatID: c.id, Item: &published, WorkflowEnded: ended})
	if w == nil && !c.muted { // the item no longer says it was a workflow's: count again
		c.recountLocked()
	}
	if w == nil || w.State.Ended() {
		c.copyLocked(false)
	}
}

// stopWorkflow is the message that asks the agent to stop the
// workflow call started, by its task's id.
func stopWorkflow(call model.Item) *model.ToSubagent {
	if call.Workflow == nil || call.TaskID == "" {
		return nil
	}
	return &model.ToSubagent{Agent: cmp.Or(call.Workflow.Name, "workflow"), AgentID: call.TaskID, Stop: true}
}

// ErrNoWorkflow says the chat has no such workflow, or the workflow no
// such agent, or the agent's files no longer have it.
var ErrNoWorkflow = errors.New("no such workflow or agent in this chat")

// maxWorkflowAgents is the most of a workflow's agents GetWorkflow lists.
const maxWorkflowAgents = 500

// Workflow returns the run tool call callID of chat chatID launched, and
// its agents (maxWorkflowAgents at most; more says there are others), as
// the agent's files say now. A run that hasn't ended may have no files
// yet: no agents; one that ended whose files are gone is ErrNoWorkflow.
func (s *Service) Workflow(chatID, callID string) (w model.Workflow, agents []model.WorkflowAgent, more bool, err error) {
	c, call, err := s.workflowCall(chatID, callID)
	if err != nil {
		return model.Workflow{}, nil, false, err
	}
	agents, err = c.kind.workflows.WorkflowAgents(c.sidFolder(call))
	switch {
	case errors.Is(err, fs.ErrNotExist) && call.Workflow.State.Ended():
		return model.Workflow{}, nil, false, fmt.Errorf("the run's files: %w", ErrNoWorkflow)
	case err != nil && !errors.Is(err, fs.ErrNotExist):
		return model.Workflow{}, nil, false, err
	}
	if len(agents) > maxWorkflowAgents {
		agents, more = agents[:maxWorkflowAgents], true
	}
	return *call.Workflow, agents, more, nil
}

// WorkflowAgent returns the steps of agent agentID of the run call callID
// launched, the last limit of them, how many came before, and the agent.
func (s *Service) WorkflowAgent(chatID, callID, agentID string, limit int) ([]model.Item, int, model.WorkflowAgent, error) {
	c, call, err := s.workflowCall(chatID, callID)
	if err != nil {
		return nil, 0, model.WorkflowAgent{}, err
	}
	sid, folder, w := c.sidFolder(call)
	agents, err := c.kind.workflows.WorkflowAgents(sid, folder, w)
	if err != nil && !errors.Is(err, fs.ErrNotExist) { // a read that failed isn't an agent gone
		return nil, 0, model.WorkflowAgent{}, err
	}
	var agent model.WorkflowAgent
	for _, a := range agents {
		if a.ID == agentID {
			agent = a
		}
	}
	if agent.ID == "" {
		return nil, 0, agent, fmt.Errorf("agent %q of that workflow: %w", agentID, ErrNoWorkflow)
	}
	items, earlier, err := c.kind.workflows.WorkflowAgentItems(sid, folder, w, agentID, limit)
	if errors.Is(err, fs.ErrNotExist) {
		err = fmt.Errorf("the agent's transcript: %w", ErrNoWorkflow)
	}
	return items, earlier, agent, err
}

// workflowCall is chat chatID's call callID that launched a workflow, as
// it stands.
func (s *Service) workflowCall(chatID, callID string) (*chat, model.Item, error) {
	c, err := s.find(chatID)
	if err != nil {
		return nil, model.Item{}, fmt.Errorf("%w: %w", ErrNoWorkflow, err)
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.itemsBackLocked()
	it := c.itemLocked(callID)
	if it == nil || it.Workflow == nil || c.kind.workflows == nil {
		return nil, model.Item{}, fmt.Errorf("workflow %q: %w", callID, ErrNoWorkflow)
	}
	return c, *it, nil
}

// sidFolder is what the reader needs of the chat for call's run: the
// session and folder its files are in.
func (c *chat) sidFolder(call model.Item) (sid, folder string, w model.Workflow) {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.sidFolderLocked(call)
}

func (c *chat) sidFolderLocked(call model.Item) (sid, folder string, w model.Workflow) {
	w = *call.Workflow
	return cmp.Or(w.Session, c.sid), cmp.Or(w.Folder, c.record.Folder), w
}

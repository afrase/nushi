package chats

import (
	"cmp"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// A background command's end is the agent's to say, where it says
// (ADR 0130): Claude, through claude-acp-go v0.5.0 on, sends its task's
// status as updates of the call that started it (BackgroundTasks'
// Task). Its output file and the command's shell are the fallback,
// used only for a command whose task the agent hasn't told of: an agent
// that doesn't, a claude that went mid-command, a reopened chat whose
// history had no end.

// taskWord is what the agent last said of a task of its: its state, how
// it ended and a failed workflow's summary, as Task reads them, and the
// agent that said "running", which counts only while that agent runs.
type taskWord struct {
	state   model.RunState
	end     string
	summary string
	agent   Agent
}

// taskLocked takes an update that is the agent's word on one of its
// tasks: a background command's ends its row (commandTaskLocked), a
// workflow's ends its run (workflowTaskLocked). It says whether the
// update said nothing else, so it is no step of the agent's work (no
// turn of its own, no change to the call): that goes for the agent's word
// on any task, a word Nushi doesn't read too. Claude's workflow's, taken
// for a step, started a turn of the agent's own when it came with the
// chat idle, and kept it when no turn followed.
func (c *chat) taskLocked(u acp.SessionUpdate) (only bool) {
	t := u.ToolCallUpdate
	if c.kind.background == nil || u.SessionUpdate != "tool_call_update" || t == nil {
		return false
	}
	task, ok := c.kind.background.Task(t.Meta)
	if !ok {
		return false
	}
	switch {
	case task.State == "":
	case task.Of == model.TaskCommand:
		c.commandTaskLocked(task, string(t.ToolCallID))
	case task.Of == model.TaskWorkflow:
		c.workflowTaskLocked(task, string(t.ToolCallID))
	}
	return t.Status == "" && t.Title == "" && t.Kind == "" && t.Content == nil && t.Locations == nil && t.RawInput == nil && t.RawOutput == nil
}

// heardTaskLocked keeps the agent's word on a task and returns it as kept:
// the first end it said is the end, a later one (the second of an end's
// two updates, a stop's "stopped" after "killed") only adds how it ended,
// and a "running" after an end (late, or replayed after it) is passed
// over.
func (c *chat) heardTaskLocked(task model.TaskUpdate) taskWord {
	was := c.tasks[task.ID]
	switch {
	case was.state.Ended() && task.State == model.RunRunning:
	case was.state.Ended():
		was.end, was.summary = cmp.Or(was.end, task.End), cmp.Or(was.summary, task.Summary)
	case task.State == model.RunRunning:
		was = taskWord{state: task.State, agent: c.agent}
	default:
		was = taskWord{state: task.State, end: task.End, summary: task.Summary}
	}
	if c.tasks == nil {
		c.tasks = map[string]taskWord{}
	}
	c.tasks[task.ID] = was
	return was
}

// commandTaskLocked ends the row of the background command call started
// when the agent's word on its task is an end: the first of an end's two
// updates ends it, the second only adds how, so the row changes once and
// its detail at most once more.
func (c *chat) commandTaskLocked(task model.TaskUpdate, call string) {
	c.heardTaskLocked(task)
	if it := c.itemLocked(call); it != nil && it.BackgroundCommand != nil && it.BackgroundCommand.ID == task.ID {
		if sh := c.heardLocked(*it.BackgroundCommand); sh != *it.BackgroundCommand {
			it.BackgroundCommand = &sh
			c.publishLocked(*it)
		}
	}
}

// heardLocked is sh as the agent's word on its task has it: ended, if
// the agent said so, whatever the file or a TaskStop made of it before;
// a command Nushi stopped itself reads "stopped" though Claude says it
// failed (model.BackgroundCommand's Killed). How it ended keeps the words
// it has (the file's end line), else takes the agent's.
func (c *chat) heardLocked(sh model.BackgroundCommand) model.BackgroundCommand {
	t := c.tasks[sh.ID]
	if !t.state.Ended() {
		return sh
	}
	state := t.state
	if state == model.RunFailed && sh.Killed {
		state = model.RunStopped
	}
	if sh.State != state {
		if sh.State != model.RunRunning && sh.State != model.RunStarted {
			sh.End = "" // the fallback's guess, overruled
		}
		sh.State = state
		if !sh.Started.IsZero() && sh.Ended.IsZero() {
			sh.Ended = time.Now()
		}
	}
	sh.End = cmp.Or(sh.End, t.end)
	return sh
}

// backgroundCommandLocked notices a tool call that left its command running in the
// background (see model.BackgroundCommand) and follows it: through its output file
// while the agent that runs it lives, else once, for how it ended.
func (c *chat) backgroundCommandLocked(it *model.Item) {
	if it.BackgroundCommand != nil || it.Status != "completed" || c.kind.background == nil {
		return
	}
	id, file, ok := c.kind.background.BackgroundCommand(*it)
	if !ok {
		return
	}
	sh := model.BackgroundCommand{ID: id, State: model.RunStarted}
	var agent Agent // none: the end is read once
	if !c.sessionOpLocked() {
		sh.State, sh.Started, agent = model.RunRunning, time.Now(), c.agent
	}
	sh = c.heardLocked(sh) // its end can come first
	it.BackgroundCommand = &sh
	go c.followCommand(it.ID, id, file, agent, commandPoll)
}

// followCommand reads the command's output file for its output until it
// ends. While the agent that runs it lives and has said its task runs,
// that word stands, whatever the file says; its end comes as an update
// (commandTaskLocked), after which the file is read once more, for the
// output and its end line's words. Else, the fallback: an end Claude's file
// gives (its line can be followed by what the command left dying, and the
// command can print such a line itself: docs/facts/claude.md) is taken
// only once the file has stopped growing after it and the command's shell
// no longer runs, where Nushi can look (commandShellRuns); the file gives
// how it ended. With its agent gone there's nothing more to wait for: the
// file's end, else "started" (its end unknown). Claude's TaskStop of the
// task ends it too (stoppedLocked). The file is looked at every poll
// (commandPoll; a test's own), and read again only once its size or time
// changed: what its last read gave stands meanwhile, and each step judges
// it again, as the end's rules need a step to see the same output twice.
func (c *chat) followCommand(callID, id, file string, agent Agent, poll time.Duration) {
	f := commandFollower{c: c, callID: callID, id: id, file: file, agent: agent}
	for f.step() {
		select {
		case <-time.After(poll):
		case <-c.svc.ctx.Done():
			return // the service closed: its agents end, and nobody is left to tell
		}
	}
}

// commandPoll is how often a running background command's output file is
// looked at; commandTail is how often at most a change to its output alone
// is sent, the row's other changes (its state, its end) going at once.
// A second is as often as the file is looked at; two seconds is a tail a
// person watching it still reads as live, at half the events of a command
// that writes all the time (a dev server's log).
const (
	commandPoll = time.Second
	commandTail = 2 * time.Second
)

// commandFollower follows one background command (followCommand): its
// call, its task's id and output file, and the agent that runs it (nil:
// the end is read once).
type commandFollower struct {
	c                *chat
	callID, id, file string
	agent            Agent
	endAt            *string   // the output an end was first seen after
	last             *fileRead // what the file gave when last read, nil to read it
	sentAt           time.Time // when the row was last sent
}

// fileRead is what a read of a command's output file gave, and the file's
// size and time just before it.
type fileRead struct {
	size            int64
	modified        time.Time
	out, end, state string
}

// read reads the command's output file, unless its size and time
// are as at the last read, which then stands.
func (f *commandFollower) read() (out, end, state string, err error) {
	tasks := f.c.kind.background
	size, modified, serr := tasks.StatBackgroundCommand(f.id, f.file)
	if l := f.last; serr == nil && l != nil && l.size == size && l.modified.Equal(modified) {
		return l.out, l.end, l.state, nil
	}
	f.last = nil
	out, end, state, err = tasks.ReadBackgroundCommand(f.id, f.file)
	if err == nil && serr == nil { // a change after the stat is seen at the next step
		f.last = &fileRead{size: size, modified: modified, out: out, end: end, state: state}
	}
	return out, end, state, err
}

// step reads the file once, if it changed, and updates the row; false
// once there's no more to follow. A change to a running command's output
// alone is sent at most every commandTail and isn't for the copy; its end
// is sent, and written to the copy, at once.
func (f *commandFollower) step() bool {
	c := f.c
	out, end, state, err := f.read()
	if end != "" && f.agent != nil && f.endAt != nil && *f.endAt == out && !c.toldRunning(f.id, f.agent) && c.commandShellRuns(f.callID, f.agent) {
		f.endAt = nil // the shell runs: the line was the command's own
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	it := c.itemLocked(f.callID)
	if it == nil || it.BackgroundCommand == nil {
		return false // the chat went, or was rewound past the call
	}
	sh := *it.BackgroundCommand
	if err == nil {
		sh.Output = out
	}
	sh, over := f.nextLocked(sh, out, end, state, err == nil)
	if was := *it.BackgroundCommand; sh != was && (over || !f.holdsTail(was, sh)) {
		it.BackgroundCommand = &sh
		saved := !c.unsaved[it.ID]
		c.publishLocked(*it)
		f.sentAt = time.Now()
		if saved && !over && sh.State == model.RunRunning && withOutput(was, sh.Output) == sh {
			// The tail alone waits for a turn's or the agent's end
			// (copyLocked(true)), not each model call (ADR 0130's
			// amendment).
			delete(c.unsaved, it.ID)
			if c.tails == nil {
				c.tails = map[string]bool{}
			}
			c.tails[it.ID] = true
		}
	}
	following := !over && sh.State == model.RunRunning
	if !following && c.unsaved[it.ID] {
		c.copyLocked(false) // the copy has the command's end, with its last output
	}
	return following
}

// withOutput is sh with out for its output.
func withOutput(sh model.BackgroundCommand, out string) model.BackgroundCommand {
	sh.Output = out
	return sh
}

// holdsTail says the row went from was to sh by a change to a running
// command's output alone, sent less than commandTail ago: it waits, the
// file holding it, for a step commandTail after (ADR 0130's amendment).
func (f *commandFollower) holdsTail(was, sh model.BackgroundCommand) bool {
	return withOutput(was, sh.Output) == sh && sh.State == model.RunRunning && time.Since(f.sentAt) < commandTail
}

// nextLocked is the row sh after a read of the file (read: it was read,
// as out, end and state), and whether following it is over.
func (f *commandFollower) nextLocked(sh model.BackgroundCommand, out, end, state string, read bool) (model.BackgroundCommand, bool) {
	c := f.c
	task := c.tasks[f.id]
	live := f.agent != nil && c.agent == f.agent
	gone := !live || !read
	switch {
	case task.state.Ended(): // the agent's word: the file adds its end line's words
		sh = c.heardLocked(sh)
		if end != "" && read {
			sh.End = end
		}
		return sh, true
	case sh.State != model.RunRunning && sh.State != model.RunStarted: // its TaskStop ended it
		return sh, true
	case task.state == model.RunRunning && task.agent == f.agent && live: // it runs, whatever the file says
	case end != "" && (gone || f.endAt != nil && *f.endAt == out):
		sh.State, sh.End = cmp.Or(model.RunState(state), model.RunFailed), end
		if sh.Killed && sh.State == model.RunFailed { // Nushi stopped it, though the agent saw an exit code (Claude: 144 for SIGTERM)
			sh.State = model.RunStopped
		}
		if !sh.Started.IsZero() && sh.Ended.IsZero() {
			sh.Ended = time.Now()
		}
	case end != "":
		f.endAt = &out
	case gone:
		sh.State = model.RunStarted // no word of its end, and nothing says it still runs
	}
	return sh, false
}

// toldRunning says the agent, still running, has said task id runs: its
// shell needn't be looked for.
func (c *chat) toldRunning(id string, agent Agent) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	t := c.tasks[id]
	return t.state == model.RunRunning && t.agent == agent && c.agent == agent
}

// commandStoppedLocked ends the background command of task id, if the chat
// shows it running or its end unknown: the agent's TaskStop stopped it
// (Claude writes "[killed]" then), or found it no longer running, how it
// ended unsaid (docs/facts/claude.md). Its follower then only reads its
// output once more. One step, under the lock: the row is never seen with
// one of its state and end changed and not the other.
func (c *chat) commandStoppedLocked(id string, stopped bool) {
	for i := range c.items {
		it := &c.items[i]
		if it.BackgroundCommand == nil || it.BackgroundCommand.ID != id || it.BackgroundCommand.State != model.RunRunning && it.BackgroundCommand.State != model.RunStarted {
			continue
		}
		sh := *it.BackgroundCommand
		sh.State = model.RunStopped
		if !sh.Started.IsZero() {
			sh.Ended = time.Now()
		}
		if stopped {
			sh.End = "killed"
		}
		it.BackgroundCommand = &sh
		c.publishLocked(*it)
	}
}

// commandShellRuns says whether the shell running the command callID left
// in the background is still among agent's processes (a group's leader:
// BackgroundTasks.RunsBackgroundCommand). False when Nushi can't look (no
// process tree, the agent's pid unknown, the tree unreadable): the file
// alone then says.
func (c *chat) commandShellRuns(callID string, agent Agent) bool {
	c.mu.Lock()
	call := c.itemLocked(callID)
	if c.svc.procs == nil || c.kind.background == nil || call == nil || agent.Pid() <= 0 {
		c.mu.Unlock()
		return false
	}
	cp, tasks := *call, c.kind.background
	c.mu.Unlock()
	found, err := commandShells(c.svc.procs, agent.Pid(), tasks, cp)
	return err == nil && len(found) > 0
}

// commandShells are the processes below root that lead a process group
// and run call's command left in the background
// (BackgroundTasks.RunsBackgroundCommand), and Under's error.
func commandShells(procs Processes, root int, tasks BackgroundTasks, call model.Item) ([]model.Process, error) {
	all, err := procs.Under(root)
	var found []model.Process
	for _, p := range all {
		if p.Pid == p.Pgid && tasks.RunsBackgroundCommand(call, p.Args) {
			found = append(found, p)
		}
	}
	return found, err
}

// Processes are the processes agents run (internal/proctree).
type Processes interface {
	// Get is process pid as it is now, without its command line.
	Get(pid int) (model.Process, error)
	// Under lists the processes below root, root not included, with their
	// command lines.
	Under(root int) ([]model.Process, error)
	// StopGroup ends the process group p leads, if p is still that process
	// below root: SIGTERM, then SIGKILL to what is left after a grace.
	StopGroup(root int, p model.Process) error
}

// stopCommand stops a command the agent left running in the background
// itself, without a turn or a word to the agent: the one process below the
// agent's that leads a process group and is the shell running the call's
// command (BackgroundTasks.RunsBackgroundCommand), by its group. Its row ends "stopped" once
// the agent's own record says it ended (followCommand); the agent hears it
// failed, and the next prompt tells it why (stopNote). False when that one
// process can't be told (none, two alike, a command line Nushi can't read
// whole): the agent is asked instead.
func (s *Service) stopCommand(c *chat, callID string) bool {
	c.mu.Lock()
	agent, tasks, log := c.agent, c.kind.background, c.logLocked()
	call := c.itemLocked(callID)
	if s.procs == nil || tasks == nil || agent == nil || agent.Pid() <= 0 || call == nil || call.BackgroundCommand == nil {
		c.mu.Unlock()
		return false
	}
	cp := *call
	c.mu.Unlock()
	root := agent.Pid()
	found, err := commandShells(s.procs, root, tasks, cp)
	if err != nil || len(found) != 1 {
		log.Info("background command left to the agent to stop", "call", callID, "found", len(found), "err", err)
		return false
	}
	if !c.markKilled(callID, agent, true) {
		return false
	}
	if err := s.procs.StopGroup(root, found[0]); err != nil {
		c.markKilled(callID, agent, false)
		log.Warn("background command not stopped", "call", callID, "err", err)
		return false
	}
	log.Info("background command stopped", "call", callID, "pid", found[0].Pid)
	if noteID.MatchString(cp.BackgroundCommand.ID) {
		c.mu.Lock()
		c.killed = append(c.killed, cp.BackgroundCommand.ID)
		c.mu.Unlock()
	}
	return true
}

// markKilled marks the background command callID started as stopped by
// Nushi (model.BackgroundCommand's Killed), or not, while it still runs under agent.
func (c *chat) markKilled(callID string, agent Agent, killed bool) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	it := c.itemLocked(callID)
	if it == nil || it.BackgroundCommand == nil || it.BackgroundCommand.State != model.RunRunning || c.agent != agent {
		return false
	}
	sh := *it.BackgroundCommand
	sh.Killed = killed
	it.BackgroundCommand = &sh
	return true
}

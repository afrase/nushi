package chats

import (
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// backgroundCommandLocked notices a tool call that left its command running in the
// background (see model.BackgroundCommand) and follows it: through its output file
// while the agent that runs it lives, else once, for how it ended.
func (c *chat) backgroundCommandLocked(it *model.Item) {
	if it.BackgroundCommand != nil || it.Status != "completed" || c.dialect.BackgroundCommand == nil {
		return
	}
	id, file, ok := c.dialect.BackgroundCommand(*it)
	if !ok {
		return
	}
	it.BackgroundCommand = &model.BackgroundCommand{ID: id, State: "started"}
	var agent Agent // none: the end is read once
	if !c.reopeningLocked() {
		it.BackgroundCommand.State, it.BackgroundCommand.Started, agent = "running", time.Now(), c.agent
	}
	go c.followCommand(it.ID, id, file, agent)
}

// commandPoll is how often a running background command's output is read.
var commandPoll = time.Second

// A command can print a line that reads as Claude's end line, so an end is
// taken only once the file stops growing after it (while the command's
// agent runs: else there's nothing more to wait for).
func (c *chat) followCommand(callID, id, file string, agent Agent) {
	var endAt *string // the output an end was first seen after
	for {
		out, end, err := c.dialect.ReadBackgroundCommand(id, file)
		c.mu.Lock()
		it := c.itemLocked(callID)
		if it == nil || it.BackgroundCommand == nil {
			c.mu.Unlock()
			return // the chat went, or was rewound past the call
		}
		sh := *it.BackgroundCommand
		if err == nil {
			sh.Output = out
		}
		gone := agent == nil || c.agent != agent || err != nil
		switch {
		case end != "" && (gone || endAt != nil && *endAt == out):
			sh.State, sh.End = commandState(end, sh.Killed), end
			if !sh.Started.IsZero() && sh.Ended.IsZero() {
				sh.Ended = time.Now()
			}
		case end != "":
			endAt = &out
		case gone:
			sh.State = "started" // no word of its end, and nothing says it still runs
		}
		if sh != *it.BackgroundCommand {
			it.BackgroundCommand = &sh
			c.publishLocked(*it)
		}
		c.mu.Unlock()
		if sh.State != "running" {
			return
		}
		select {
		case <-time.After(commandPoll):
		case <-c.ctx.Done():
			return // the service closed: its agents end, and nobody is left to tell
		}
	}
}

// commandState is a background command's state from how the agent says it
// ended; one Nushi killed (model.BackgroundCommand's Killed) reads "stopped" though
// Claude Code gives it an exit code (144 for SIGTERM).
func commandState(end string, killed bool) string {
	switch {
	case strings.HasSuffix(end, " 0"):
		return "done"
	case end == "killed", killed:
		return "stopped"
	}
	return "failed"
}

// Processes are the processes agents run (internal/proctree).
type Processes interface {
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
// command (Dialect.RunsBackgroundCommand), by its group. Its row ends "stopped" once
// the agent's own record says it ended (followCommand); the agent hears it
// failed, and the next prompt tells it why (stopNote). False when that one
// process can't be told (none, two alike, a command line Nushi can't read
// whole): the agent is asked instead.
func (s *Service) stopCommand(c *chat, callID string) bool {
	c.mu.Lock()
	agent, runs, log := c.agent, c.dialect.RunsBackgroundCommand, c.logLocked()
	call := c.itemLocked(callID)
	if s.procs == nil || runs == nil || agent == nil || agent.Pid() <= 0 || call == nil || call.BackgroundCommand == nil {
		c.mu.Unlock()
		return false
	}
	cp := *call
	c.mu.Unlock()
	root := agent.Pid()
	procs, err := s.procs.Under(root)
	var found []model.Process
	for _, p := range procs {
		if p.Pid == p.Pgid && runs(cp, p.Args) {
			found = append(found, p)
		}
	}
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
	if it == nil || it.BackgroundCommand == nil || it.BackgroundCommand.State != "running" || c.agent != agent {
		return false
	}
	sh := *it.BackgroundCommand
	sh.Killed = killed
	it.BackgroundCommand = &sh
	return true
}

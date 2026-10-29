package chats

import (
	"strings"
	"time"

	"github.com/afrase/nushi/internal/model"
)

// shellLocked notices a tool call that left its command running in the
// background (see model.Shell) and follows it: through its output file
// while the agent that runs it lives, else once, for how it ended.
func (c *chat) shellLocked(it *model.Item) {
	if it.Shell != nil || it.Status != "completed" || c.dialect.Shell == nil {
		return
	}
	id, file, ok := c.dialect.Shell(*it)
	if !ok {
		return
	}
	it.Shell = &model.Shell{ID: id, State: "started"}
	var agent Agent // none: the end is read once
	if !c.reopeningLocked() {
		it.Shell.State, it.Shell.Started, agent = "running", time.Now(), c.agent
	}
	go c.followShell(it.ID, id, file, agent)
}

// shellPoll is how often a running background command's output is read.
var shellPoll = time.Second

// A command can print a line that reads as Claude's end line, so an end is
// taken only once the file stops growing after it (while the command's
// agent runs: else there's nothing more to wait for).
func (c *chat) followShell(callID, id, file string, agent Agent) {
	var endAt *string // the output an end was first seen after
	for {
		out, end, err := c.dialect.ReadShell(id, file)
		c.mu.Lock()
		it := c.itemLocked(callID)
		if it == nil || it.Shell == nil {
			c.mu.Unlock()
			return // the chat went, or was rewound past the call
		}
		sh := *it.Shell
		if err == nil {
			sh.Output = out
		}
		gone := agent == nil || c.agent != agent || err != nil
		switch {
		case end != "" && (gone || endAt != nil && *endAt == out):
			sh.State, sh.End = shellState(end), end
			if !sh.Started.IsZero() && sh.Ended.IsZero() {
				sh.Ended = time.Now()
			}
		case end != "":
			endAt = &out
		case gone:
			sh.State = "started" // no word of its end, and nothing says it still runs
		}
		if sh != *it.Shell {
			it.Shell = &sh
			c.publishLocked(*it)
		}
		c.mu.Unlock()
		if sh.State != "running" {
			return
		}
		select {
		case <-time.After(shellPoll):
		case <-c.ctx.Done():
			return // the service closed: its agents end, and nobody is left to tell
		}
	}
}

func shellState(end string) string {
	switch {
	case end == "killed":
		return "stopped"
	case strings.HasSuffix(end, " 0"):
		return "done"
	}
	return "failed"
}

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
	id, file, ok := c.dialect.Shell(it.Text)
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

func (c *chat) followShell(callID, id, file string, agent Agent) {
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
		switch {
		case end != "":
			sh.State, sh.End = shellState(end), end
			if !sh.Started.IsZero() && sh.Ended.IsZero() {
				sh.Ended = time.Now()
			}
		case agent == nil || c.agent != agent || err != nil:
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
		time.Sleep(shellPoll)
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

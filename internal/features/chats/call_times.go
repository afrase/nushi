// This file holds the times the daemon stamps on tool calls (model.Item's
// Started and Ended) and the time a subagent worked (model.Subagent's
// Worked and Working): what a row's time and a subagent's are made of.

package chats

import (
	"time"

	"github.com/afrase/nushi/internal/model"
)

// callEnded says a tool call's status is an end.
func callEnded(status string) bool { return status == "completed" || status == "failed" }

// callRunning says a tool call's status says it runs.
func callRunning(status string) bool { return status == "pending" || status == "in_progress" }

// timeCallLocked stamps a tool call as an update comes (was is its status
// before it, "" for a new call): its start when the daemon first sees it,
// live, unless a permission prompt for it is pending (askedLocked), and
// its end when its status first becomes one. A replayed call gets no
// times: when it ran isn't known.
func (c *chat) timeCallLocked(it *model.Item, was string) {
	if c.muted || c.sessionOpLocked() {
		return
	}
	now := time.Now()
	if it.Started.IsZero() && was == "" && c.asking[it.ID] == 0 {
		it.Started = now
	}
	if !it.Started.IsZero() && callEnded(it.Status) && !callEnded(was) {
		it.Ended = now // also past the end its turn gave it
	}
}

// askedLocked says a permission prompt for tool call callID is pending:
// the call doesn't count as running until it's allowed (permittedLocked),
// so the wait for the user isn't in its time. Agents order the two either
// way (docs/facts: Claude and OpenCode send the call first, Codex the
// prompt), so a call already stamped loses its start.
func (c *chat) askedLocked(callID string) {
	if c.asking == nil {
		c.asking = map[string]int{}
	}
	c.asking[callID]++
	if it := c.itemLocked(callID); it != nil && it.Kind == model.ToolCall && !it.Started.IsZero() {
		it.Started, it.Ended = time.Time{}, time.Time{}
		c.publishLocked(*it)
	}
}

// permittedLocked says the prompt for tool call callID was answered:
// allowed, the call starts to run now; denied or cancelled, it has no time.
func (c *chat) permittedLocked(callID string, allowed bool) {
	if c.asking[callID]--; c.asking[callID] <= 0 {
		delete(c.asking, callID)
	}
	it := c.itemLocked(callID)
	if !allowed || it == nil || it.Kind != model.ToolCall || callEnded(it.Status) {
		return
	}
	it.Started, it.Ended = time.Now(), time.Time{}
	c.publishLocked(*it)
}

// endCallsLocked ends the times of the tool calls still running as a turn
// ends (cancelled, or the agent left them so): their status stays the
// agent's, but they no longer count as running; an end of their own
// later replaces this one. It says whether it ended any.
func (c *chat) endCallsLocked() bool {
	now := time.Now()
	ended := false
	for i := range c.items {
		if it := &c.items[i]; it.Kind == model.ToolCall && callRunning(it.Status) && !it.Started.IsZero() && it.Ended.IsZero() {
			it.Ended, ended = now, true
			c.publishLocked(*it)
		}
	}
	return ended
}

// untimed drops the times of what an item had running that a daemon
// coming back can't know the end of: a tool call's, and the time a
// subagent worked (it shows none rather than one that counts the time the
// daemon was gone).
func untimed(it *model.Item) {
	if it.Kind == model.ToolCall && it.Ended.IsZero() {
		it.Started = time.Time{}
	}
	if sa := it.Subagent; sa != nil && !sa.Working.IsZero() {
		cp := *sa
		cp.Worked, cp.Working = 0, time.Time{}
		it.Subagent = &cp
	}
}

// work keeps the time a subagent worked as its state changes (old
// to sa's), now: it counts from when it begins to work, and stops while
// it waits. The agent's own totals, once it reports them as the subagent
// ends (its first run's), stand for what the daemon counted to then; a
// later run counts on from them, without their tokens, which no longer
// cover all it did.
func work(sa *model.Subagent, old model.Subagent, totals *model.Totals, now time.Time) {
	running := sa.State == model.RunRunning
	switch {
	case running && sa.Working.IsZero() && !sa.Started.IsZero():
		if old.State != model.RunRunning && sa.Reported {
			sa.Tokens = 0 // a run its totals don't cover
		}
		sa.Working = now
	case !running && !sa.Working.IsZero():
		sa.Worked += now.Sub(sa.Working)
		sa.Working = time.Time{}
	}
	if !running && totals != nil && !sa.Reported {
		sa.Worked, sa.Tokens, sa.Reported = totals.Duration, totals.Tokens, true
	}
}

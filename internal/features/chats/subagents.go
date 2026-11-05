// This file holds a subagent's state (model.Subagent, ADR 0044): what its
// tool call, and the steps under it, bring it up to date with.

package chats

import (
	"time"

	"github.com/afrase/nushi/internal/model"
)

// subagentLocked brings the subagent that call (a tool call) starts, if
// it starts one, up to date (see model.Subagent), and says whether it
// changed. A subagent in the background runs on past its call until its
// report, if the daemon saw it start: a replayed one without a report has
// ended.
func (c *chat) subagentLocked(call *model.Item) bool { //nolint:gocyclo // one test per field the subagent's state takes from the call
	if call.Agent == "" {
		return false
	}
	var sa model.Subagent
	if call.Subagent != nil {
		sa = *call.Subagent
	}
	old := sa
	var background, elsewhere bool
	if sub := c.kind.subagents; sub != nil {
		if call.AgentID == "" {
			call.AgentID = sub.SubagentID(call.Text)
		}
		background, elsewhere = sub.Background(call.Text), sub.ReportElsewhere(call.Text)
	}
	r, last, said := -1, -1, -1 // its last report, its last item, and its last message
	for i := range c.items {
		if it := &c.items[i]; it.Parent == call.ID {
			last = i
			if it.Report {
				r = i
			}
			if it.Kind == model.AgentMessage {
				said = i
			}
		}
	}
	switch {
	case sa.Said != "": // the agent said, of its session (children.go)
		sa.State = sa.Said
	case call.Status == "pending" || call.Status == "in_progress":
		sa.State = "running"
	case call.Status == "failed":
		sa.State = "failed"
	case background && r < 0 && !sa.Started.IsZero():
		sa.State = "running"
	// Steps after its last report (never replayed, so seen live): a
	// message ran it again. A call that reports apart from its output
	// may not have its report any more (replayed).
	case last > r && (r >= 0 || background || elsewhere):
		sa.State = "running"
	default:
		sa.State = "done"
	}
	switch {
	case sa.State == "running" && sa.Started.IsZero() && !c.reopeningLocked():
		sa.Started = time.Now()
	case sa.State != "running" && !sa.Started.IsZero() && sa.Ended.IsZero():
		sa.Ended = time.Now()
	case sa.State == "running":
		sa.Ended = time.Time{}
	}
	switch {
	case sa.State == "running":
		sa.Result = ""
	case r >= 0:
		sa.Result = c.items[r].Text
	case said >= 0 && sa.Said != "": // it ended without a report: its last words
		sa.Result = c.items[said].Text
	case sa.Said == "stopped": // its call says only that it was
		sa.Result = ""
	case !background && !elsewhere:
		sa.Result = call.Text
	}
	call.Subagent = &sa
	if old.State == "running" && sa.State != "running" { // its own moment: the turn may be long over (ADR 0044)
		c.lookRelatedLocked()
	}
	return sa != old
}

// reportedLocked updates the subagent a tool call comes from, if one does:
// a report ends it, and a step after its report means it runs again.
func (c *chat) reportedLocked(it model.Item) {
	if call := c.itemLocked(it.Parent); call != nil && c.subagentLocked(call) {
		c.publishLocked(*call)
	}
}

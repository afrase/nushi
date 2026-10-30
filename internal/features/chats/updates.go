package chats

import (
	"encoding/base64"
	"encoding/json"
	"path/filepath"
	"slices"
	"strings"
	"time"

	acp "github.com/afrase/acp-go/unstable"

	"github.com/afrase/nushi/internal/model"
)

// update turns the agent's updates into transcript items. from is the
// subagent's session they came on, if they did (children.go): only its
// steps are taken, as the steps of the subagent call it works for.
func (c *chat) update(n *acp.SessionNotification, from *child) { //nolint:gocognit,gocyclo,maintidx // one case per ACP update kind
	c.mu.Lock()
	defer c.mu.Unlock()
	replayed := slices.Contains(replayKinds, n.Update.SessionUpdate)
	if c.kept && replayed {
		return // session/load's replay of a transcript the chat still has
	}
	parent, ok := c.stepOfLocked(n, from)
	if !ok {
		return
	}
	if c.replaying && replayed { // it goes aside, to be merged with the copy
		c.items, c.replay, c.quiet = c.replay, c.items, true
		defer func() { c.items, c.replay, c.quiet = c.replay, c.items, false }()
	}
	if !c.busy && c.started.IsZero() && slices.Contains([]string{"agent_message_chunk", "agent_thought_chunk", "tool_call", "tool_call_update"}, n.Update.SessionUpdate) &&
		parent == "" && c.parentLocked(n.Update) == "" { // a subagent's steps aren't the agent's own work
		// Its work after a turn of the user's starts a chapter of its own in
		// the transcript; an update to a call it made before (a late
		// result) doesn't.
		if !c.ownNoted && n.Update.SessionUpdate != "tool_call_update" &&
			slices.ContainsFunc(c.items, func(it model.Item) bool { return it.Kind == model.UserMessage }) {
			c.ownNoted = true
			c.noticeLocked("own_turn", "On its own, after a background task")
		}
		c.ownTurn = true // until its usage_update, which ends a turn
	}
	switch u := n.Update; u.SessionUpdate {
	case "user_message_chunk": // replayed by session/load
		c.chunkLocked(model.UserMessage, u.UserMessageChunk, "")
	case "agent_message_chunk":
		c.chunkLocked(model.AgentMessage, u.AgentMessageChunk, parent)
	case "agent_thought_chunk":
		c.chunkLocked(model.Thought, u.AgentThoughtChunk, parent)
	case "plan":
		c.planLocked(u.Plan.Entries)
	case "tool_call":
		t := u.ToolCall
		item := model.Item{ID: string(t.ToolCallID), Kind: model.ToolCall, Title: t.Title,
			ToolKind: string(t.Kind), Status: string(t.Status), Paths: c.paths(t.Locations), Parent: parent}
		c.setOutput(&item, t.Content)
		c.toolCallLocked(&item, t.Meta, t.RawInput)
		keepRaw(&item, t.RawInput, t.RawOutput)
		if it := c.itemLocked(item.ID); it != nil { // a repeated tool_call replaces the call
			item.Subagent, item.BackgroundCommand = it.Subagent, it.BackgroundCommand
			*it = item
			c.subagentLocked(it)
			c.backgroundCommandLocked(it)
			c.publishLocked(*it)
		} else {
			c.subagentLocked(&item)
			c.backgroundCommandLocked(&item)
			c.addLocked(item)
		}
		c.reportedLocked(item)
		c.passedOnLocked(item)
	case "available_commands_update":
		c.commands = []model.Command{}
		for _, a := range u.AvailableCommandsUpdate.AvailableCommands {
			cmd := model.Command{Name: a.Name, Description: a.Description}
			if a.Input != nil && a.Input.Unstructured != nil {
				cmd.Hint = a.Input.Unstructured.Hint
			}
			c.commands = append(c.commands, cmd)
		}
		c.emitLocked(model.Event{ChatID: c.id, Commands: slices.Clone(c.commands)})
		c.statusChangedLocked() // CanAskContext
	case "config_option_update":
		c.replaceConfigLocked(u.ConfigOptionUpdate.ConfigOptions)
		c.configChangedLocked()
	case "current_mode_update":
		if i := modeIndex(c.config); i >= 0 {
			c.config[i].Current = string(u.CurrentModeUpdate.CurrentModeID)
			c.configChangedLocked()
		}
	case "usage_update":
		c.ownTurn, c.ownNoted = false, false
		u := u.UsageUpdate
		if c.dialect.TurnDone != nil && !c.started.IsZero() && !c.stopped && c.dialect.TurnDone(u) {
			switch {
			case c.steered > 0: // the result of the work a steered message cut short: the turn goes on
				c.steered = 0
			case c.backgroundLocked(c.turnFrom): // the agent holds a turn for the subagents it started
				c.releaseLocked()
			}
		}
		// The end of the agent's own turn: its items have settled. During one of
		// Nushi's, which ends with the prompt's answer, a model call's.
		c.copyLocked(c.started.IsZero())
		c.usage.Used, c.usage.Size = int64(u.Used), int64(u.Size) //nolint:gosec // token counts, far below the limits
		if u.Cost != nil {                                        // else the cost reported last still stands
			c.usage.Cost, c.usage.Currency = u.Cost.Amount, u.Cost.Currency
		}
		c.usageChangedLocked()
	case "session_info_update":
		var t string // a title cleared (null) is left as it was
		if v := u.SessionInfoUpdate.Title.Value; v != nil {
			t = *v
		}
		forkTitle := c.dialect.ForkTitle != nil && c.dialect.ForkTitle(t, c.record.Title)
		if t != "" && !forkTitle {
			c.saveLocked(func(s *model.ChatRecord) { s.Title = t })
			c.titled = true
			c.nameBranchLocked() // when it came between turns; else at the turn's end
		}
	case "tool_call_update":
		t := u.ToolCallUpdate
		it := c.itemLocked(string(t.ToolCallID))
		if it == nil {
			return
		}
		if t.Title != "" {
			it.Title = t.Title
		}
		if t.Kind != "" {
			it.ToolKind = string(t.Kind)
		}
		if t.Status != "" {
			it.Status = string(t.Status)
		}
		if t.Locations != nil {
			it.Paths = c.paths(t.Locations)
		}
		if own := c.toolCallLocked(it, t.Meta, t.RawInput); !own && t.Content != nil {
			c.setOutput(it, t.Content)
		}
		keepRaw(it, t.RawInput, t.RawOutput)
		c.subagentLocked(it)
		c.backgroundCommandLocked(it)
		c.publishLocked(*it)
		c.reportedLocked(*it)
		c.passedOnLocked(*it)
		if t.Status == "completed" || t.Status == "failed" {
			c.stoppedLocked(*it)
			c.copyLocked(false)
		}
		if (t.Status == "completed" || t.Status == "failed") && it.Parent == "" && !c.started.IsZero() {
			c.deliverLocked() // between tool calls: the agent's chance to take queued messages
		}
	}
}

// stepOfLocked says whether to take an update, and which subagent call it
// is a step of when it came on a subagent's session (from): only its steps
// are taken, and not as replayed (the copy has them, as for an agent
// without such sessions).
func (c *chat) stepOfLocked(n *acp.SessionNotification, from *child) (parent string, ok bool) {
	if from == nil {
		return "", true
	}
	if !slices.Contains(stepKinds, n.Update.SessionUpdate) || c.replaying {
		return "", false
	}
	return c.childOfLocked(from, string(n.SessionID)), true
}

// parentLocked is the subagent tool call an update comes from, if one
// does (see Dialect.Parent).
func (c *chat) parentLocked(u acp.SessionUpdate) string {
	if c.dialect.Parent == nil {
		return ""
	}
	switch {
	case u.AgentMessageChunk != nil:
		return c.dialect.Parent(u.AgentMessageChunk.Meta)
	case u.AgentThoughtChunk != nil:
		return c.dialect.Parent(u.AgentThoughtChunk.Meta)
	case u.ToolCall != nil:
		return c.dialect.Parent(u.ToolCall.Meta)
	case u.ToolCallUpdate != nil:
		if it := c.itemLocked(string(u.ToolCallUpdate.ToolCallID)); it != nil {
			return it.Parent
		}
		return c.dialect.Parent(u.ToolCallUpdate.Meta)
	}
	return ""
}

// chunkLocked adds a chunk of a message (text or an image): to the message
// with its id, or, when it has none, to the last item if that is a message
// of the same kind. parent is the subagent call it is a step of, when its
// session says (else its _meta may).
func (c *chat) chunkLocked(kind model.ItemKind, m *acp.ContentChunk, parent string) {
	var text string
	var images []model.Image
	switch {
	case m.Content.Text != nil:
		text = m.Content.Text.Text
	case m.Content.Image != nil:
		img, ok := image(m.Content.Image)
		if !ok {
			return
		}
		images = []model.Image{img}
	default:
		return
	}
	if kind == model.UserMessage && c.dialect.Interrupted != nil && c.dialect.Interrupted(text) {
		return
	}
	id := string(m.MessageID)
	if kind == model.Thought && id != "" {
		id = "thought-" + id // a thought may share its message's id
	}
	if c.dialect.Parent != nil && parent == "" {
		parent = c.dialect.Parent(m.Meta)
	}
	if kind == model.AgentMessage && parent == "" && text != "" && c.dialect.Notice != nil {
		if n, ok := c.dialect.Notice(m.Meta, text); ok {
			c.agentNoticeLocked(n)
			return
		}
	}
	it := c.itemLocked(id)
	if m.MessageID == "" && len(c.items) > 0 {
		it = &c.items[len(c.items)-1]
	}
	if it != nil && it.Parent != parent {
		it = nil // another agent's message
	}
	if it != nil && it.Kind == kind && images != nil {
		it.Images = append(it.Images, images...)
		c.publishLocked(*it)
		return
	}
	if it != nil && it.Kind == kind {
		it.Text += text
		if noted := c.unnotedLocked(it); c.readToSubagentLocked(it) || noted { // whole now
			c.publishLocked(*it)
			return
		}
		c.emitLocked(model.Event{ChatID: c.id, Item: &model.Item{ID: it.ID, Kind: kind, Text: text}, Append: true})
		return
	}
	item := model.Item{ID: id, Kind: kind, Text: text, Images: images, Parent: parent}
	c.unnotedLocked(&item)
	c.readToSubagentLocked(&item)
	c.addLocked(item)
}

// agentNoticeLocked adds a notice of the agent's own (Dialect.Notice). One
// that says the model's safeguards stopped the response before it marks
// what streamed of that response, the message just before, if any.
func (c *chat) agentNoticeLocked(n model.AgentNotice) {
	if last := len(c.items) - 1; n.Stopped && last >= 0 {
		if it := &c.items[last]; it.Kind == model.AgentMessage && it.Parent == "" {
			it.Status = model.StoppedBySafeguards
			c.publishLocked(*it)
		}
	}
	c.noticeLocked(map[bool]string{false: "agent_notice", true: "agent_warning"}[n.Warning], n.Text)
}

// toolCallLocked adds what the agent tells of a tool call beyond ACP (see
// Dialect.ToolCall).
func (c *chat) toolCallLocked(it *model.Item, meta map[string]any, input json.RawMessage) (ownText bool) {
	return c.dialect.ToolCall != nil && c.dialect.ToolCall(it, meta, input)
}

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
	if call.AgentID == "" && c.dialect.SubagentID != nil {
		call.AgentID = c.dialect.SubagentID(call.Text)
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
	background := c.dialect.Background != nil && c.dialect.Background(call.Text)
	elsewhere := c.dialect.ReportElsewhere != nil && c.dialect.ReportElsewhere(call.Text)
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
	return sa != old
}

// reportedLocked updates the subagent a tool call comes from, if one does:
// a report ends it, and a step after its report means it runs again.
func (c *chat) reportedLocked(it model.Item) {
	if call := c.itemLocked(it.Parent); call != nil && c.subagentLocked(call) {
		c.publishLocked(*call)
	}
}

// planLocked shows the agent's plan: it replaces the plan of the current
// turn (since the last user message), or starts one.
func (c *chat) planLocked(entries []acp.PlanEntry) {
	plan := make([]model.PlanEntry, 0, len(entries))
	for _, e := range entries {
		plan = append(plan, model.PlanEntry{Content: e.Content, Status: string(e.Status)})
	}
	for i := len(c.items) - 1; i >= 0 && c.items[i].Kind != model.UserMessage; i-- {
		if c.items[i].Kind == model.Plan {
			c.items[i].Plan = plan
			c.publishLocked(c.items[i])
			return
		}
	}
	c.addLocked(model.Item{Kind: model.Plan, Plan: plan})
}

func (c *chat) publishLocked(it model.Item) {
	c.emitLocked(model.Event{ChatID: c.id, Item: &it})
}

// setOutput sets a tool call's output from its content: the text as
// markdown, its diffs and images apart. A terminal shows nothing: Nushi
// offers agents none, so a command's output comes in the agent's _meta
// (Dialect.ToolCall).
func (c *chat) setOutput(it *model.Item, content []acp.ToolCallContent) {
	var parts []string
	var diffs []model.FileChange
	var images []model.Image
	for _, tc := range content {
		switch {
		case tc.Content != nil && tc.Content.Content.Text != nil:
			parts = append(parts, tc.Content.Content.Text.Text)
		case tc.Content != nil && tc.Content.Content.Image != nil:
			if img, ok := image(tc.Content.Content.Image); ok {
				images = append(images, img)
			}
		case tc.Diff != nil:
			d := tc.Diff
			status := "modified"
			if d.OldText == "" {
				status = "added"
			}
			diffs = append(diffs, model.FileChange{Path: c.rel(d.Path), Status: status, Old: d.OldText, New: d.NewText})
		}
	}
	it.Text, it.Diffs, it.Images = strings.Join(parts, "\n\n"), diffs, images
}

// image decodes an image the agent sent; one given only by URI is left out.
func image(i *acp.ImageContent) (model.Image, bool) {
	data, err := base64.StdEncoding.DecodeString(i.Data)
	return model.Image{MimeType: i.MimeType, Data: data}, err == nil && len(data) > 0
}

func (c *chat) paths(locs []acp.ToolCallLocation) []string {
	var out []string
	for _, l := range locs {
		out = append(out, c.rel(l.Path))
	}
	return out
}

// rel makes path relative to the chat's folder when it is inside it.
func (c *chat) rel(path string) string {
	if r, err := filepath.Rel(c.record.Folder, path); err == nil && filepath.IsLocal(r) {
		return r
	}
	return path
}

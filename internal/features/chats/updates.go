package chats

import (
	"cmp"
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
func (c *chat) update(n *acp.SessionNotification, from *child) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.updateLocked(n, from)
}

func (c *chat) updateLocked(n *acp.SessionNotification, from *child) { //nolint:gocognit,gocyclo,maintidx // one case per ACP update kind
	replayed := slices.Contains(replayKinds, n.Update.SessionUpdate)
	if c.outlived && replayed {
		return // session/load's replay of a transcript the chat still has
	}
	parent, ok := c.stepOfLocked(n, from)
	if !ok {
		return
	}
	if c.replaying && replayed { // it goes aside, to be merged with the copy
		c.items, c.replay, c.muted = c.replay, c.items, true
		defer func() { c.items, c.replay, c.muted = c.replay, c.items, false }()
	}
	if c.commandTaskLocked(n.Update) {
		return // a background command's task, told on its call: no step of the agent's work
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
		if !c.ownTurn {
			c.ownTurn = true // until the usage_update that ends the turn
			c.statusChangedLocked()
			c.pokeWorkflowsLocked() // a workflow's end starts one (Claude's task-notification)
		}
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
			item.Started, item.Ended, item.Totals = it.Started, it.Ended, cmp.Or(item.Totals, it.Totals)
			c.timeCallLocked(&item, cmp.Or(it.Status, "pending"))
			if it.Workflow != nil {
				item.Workflow, item.TaskID = it.Workflow, it.TaskID
			}
			*it = item
			c.subagentLocked(it)
			c.backgroundCommandLocked(it)
			c.workflowLocked(it)
			c.publishLocked(*it)
		} else {
			c.timeCallLocked(&item, "")
			c.subagentLocked(&item)
			c.backgroundCommandLocked(&item)
			c.workflowLocked(&item)
			c.addLocked(item)
		}
		c.reportedLocked(item)
		c.passedOnLocked(item)
	case "available_commands_update":
		listed := []model.Command{}
		for _, a := range u.AvailableCommandsUpdate.AvailableCommands {
			cmd := model.Command{Name: a.Name, Description: a.Description}
			if a.Input != nil && a.Input.Unstructured != nil {
				cmd.Hint = a.Input.Unstructured.Hint
			}
			listed = append(listed, cmd)
		}
		listed = c.kind.offered(listed) // one it can't run here is neither shown nor remembered
		c.commands = c.kind.withTerminalCommands(listed)
		c.emitLocked(model.Event{ChatID: c.id, Commands: slices.Clone(c.commands)})
		c.statusChangedLocked() // CanAskContext
		if len(listed) > 0 && !slices.Equal(listed, c.svc.remembered.Commands(c.kind.Name)) {
			if err := c.svc.remembered.SetCommands(c.kind.Name, listed); err != nil {
				c.logLocked().Warn("commands not remembered", "err", err)
			}
		}
	case "config_option_update":
		c.replaceConfigLocked(u.ConfigOptionUpdate.ConfigOptions)
		c.configChangedLocked()
	case "current_mode_update":
		if i := modeIndex(c.config); i >= 0 {
			c.config[i].Current = string(u.CurrentModeUpdate.CurrentModeID)
			c.configChangedLocked()
		}
	case "usage_update":
		u := u.UsageUpdate
		// The agent's own turn ends with the usage_update its harness says
		// ends it (Transcript.OwnTurnEnded); without a Transcript, any.
		var ownEnded, released bool // the turn that ends here, for the meter once the cost is in
		if ends := c.kind.transcript == nil || c.kind.transcript.OwnTurnEnded(u); ends {
			ownEnded, c.ownNoted = c.ownTurn, false // ended below, once its usage is in
		}
		if c.kind.transcript != nil && !c.started.IsZero() && !c.stopped && c.kind.transcript.TurnDone(u) {
			switch {
			case c.steered > 0: // the result of the work a steered message cut short: the turn goes on
				c.steered = 0
			case c.backgroundLocked(c.turnFrom): // the agent holds a turn for the subagents it started
				c.releaseLocked()
				released = true
			}
		}
		// The end of the agent's own turn: its items have settled. During one of
		// Nushi's, which ends with the prompt's answer, a model call's.
		c.copyLocked(c.started.IsZero())
		c.usage.Used, c.usage.Size = int64(u.Used), int64(u.Size) //nolint:gosec // token counts, far below the limits
		if u.Cost != nil {                                        // else the cost reported last still stands
			c.usage.Cost, c.usage.Currency, c.costed = u.Cost.Amount, u.Cost.Currency, true
		}
		c.usageMetaLocked(u.Meta)
		c.usageChangedLocked()
		switch {
		case released:
			c.meterLocked(model.UsageReleased, nil)
		case ownEnded:
			c.meterLocked(model.UsageOwn, nil)
		}
		if ownEnded {
			c.endOwnTurnLocked(model.TurnDone, "")
		}
	case "session_info_update":
		var t string // a title cleared (null) is left as it was
		if v := u.SessionInfoUpdate.Title.Value; v != nil {
			t = *v
		}
		forkTitle := c.kind.transcript != nil && c.kind.transcript.ForkTitle(t, c.record.Title)
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
		was := it.Status
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
		c.timeCallLocked(it, cmp.Or(was, "pending"))
		c.subagentLocked(it)
		c.backgroundCommandLocked(it)
		c.workflowLocked(it)
		c.publishLocked(*it)
		c.reportedLocked(*it)
		c.passedOnLocked(*it)
		if callEnded(string(t.Status)) {
			c.openedPullLocked(*it)
			c.pushedLocked(*it)
			c.stoppedLocked(*it)
			c.copyLocked(false)
			if it.Parent != "" {
				c.relatedStepLocked()
			}
		}
		if callEnded(string(t.Status)) && it.Parent == "" && !c.started.IsZero() {
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
// does (see Subagents.Parent).
func (c *chat) parentLocked(u acp.SessionUpdate) string {
	sub := c.kind.subagents
	if sub == nil {
		return ""
	}
	switch {
	case u.AgentMessageChunk != nil:
		return sub.Parent(u.AgentMessageChunk.Meta)
	case u.AgentThoughtChunk != nil:
		return sub.Parent(u.AgentThoughtChunk.Meta)
	case u.ToolCall != nil:
		return sub.Parent(u.ToolCall.Meta)
	case u.ToolCallUpdate != nil:
		if it := c.itemLocked(string(u.ToolCallUpdate.ToolCallID)); it != nil {
			return it.Parent
		}
		return sub.Parent(u.ToolCallUpdate.Meta)
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
	id := string(m.MessageID)
	if kind == model.Thought && id != "" {
		id = "thought-" + id // a thought may share its message's id
	}
	if c.kind.subagents != nil && parent == "" {
		parent = c.kind.subagents.Parent(m.Meta)
	}
	if t := c.kind.transcript; t != nil {
		if kind == model.UserMessage && t.Interrupted(text) {
			return
		}
		if kind == model.AgentMessage && parent == "" && text != "" {
			if n, ok := t.Notice(m.Meta, text); ok {
				c.agentNoticeLocked(n)
				return
			}
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
	if s, ok := m.Meta[model.SentMeta].(string); ok && c.muted && kind != model.Thought {
		item.Sent, _ = time.Parse(time.RFC3339Nano, s) // a zero time if it isn't one: not known
	}
	c.unnotedLocked(&item)
	c.readToSubagentLocked(&item)
	c.addLocked(item)
}

// agentNoticeLocked adds a notice of the agent's own (Transcript.Notice). One
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
// ToolReader).
func (c *chat) toolCallLocked(it *model.Item, meta map[string]any, input json.RawMessage) (ownText bool) {
	return c.kind.toolReader != nil && c.kind.toolReader.ToolCall(it, meta, input)
}

// planLocked shows the agent's plan: it replaces the plan of the current
// turn (since the last user message), or starts one, unless the plan is
// the chat's latest unchanged. Claude sends its plan again as each prompt
// starts (docs/facts/claude.md), which session/load doesn't replay: a
// card for it would repeat the plan in every turn, and live and a reload
// would differ.
func (c *chat) planLocked(entries []acp.PlanEntry) {
	plan := make([]model.PlanEntry, 0, len(entries))
	for _, e := range entries {
		plan = append(plan, model.PlanEntry{Content: e.Content, Status: string(e.Status)})
	}
	turn := true // still in the current turn, going back
	for i := len(c.items) - 1; i >= 0; i-- {
		switch it := &c.items[i]; {
		case it.Kind == model.UserMessage:
			turn = false
		case it.Kind == model.Plan && turn:
			it.Plan = plan
			c.publishLocked(*it)
			return
		case it.Kind == model.Plan:
			if slices.Equal(it.Plan, plan) {
				return
			}
			c.addLocked(model.Item{Kind: model.Plan, Plan: plan})
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
// (ToolReader).
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
			// No old text is a new file, "" an empty one (ACP's Diff).
			status, old := "added", ""
			if d.OldText != nil {
				status, old = "modified", *d.OldText
			}
			diffs = append(diffs, model.FileChange{Path: c.rel(d.Path), Status: status, Old: old, New: d.NewText})
		}
	}
	it.Text, it.Diffs, it.Images = strings.Join(parts, "\n\n"), diffs, images
}

// image decodes an image the agent sent, and takes its hash and size once,
// beside the decoding (model.Image.Hash); one given only by URI is left
// out.
func image(i *acp.ImageContent) (model.Image, bool) {
	data, err := base64.StdEncoding.DecodeString(i.Data)
	if err != nil || len(data) == 0 {
		return model.Image{}, false
	}
	return described(model.Image{MimeType: i.MimeType, Data: data}), true
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

// endOwnTurnLocked ends the agent's own turn, if one runs: with a verdict
// (end, and failure with TurnFailed) as a turn of Nushi's ends, which
// notifies and marks the chat done (turnEndedLocked; ADR 0141), or, with
// NotEnded, only its flags, for a turn something else supersedes.
//
// Only a harness that tells the end (a Transcript) has a verdict to give.
// Without one, an own turn is only guessed from updates after Nushi's turn,
// a late result among them, and any usage ends it: a verdict would notify
// "finished" a second time, or "failed" when an idle agent quits. Its
// calls' clocks stop, as at a turn's end, with no verdict.
func (c *chat) endOwnTurnLocked(end model.TurnEnd, failure string) {
	if !c.ownTurn {
		return
	}
	c.ownTurn, c.ownNoted = false, false
	c.lookRelatedLocked()
	switch {
	case end == model.NotEnded:
		c.statusChangedLocked()
	case c.kind.transcript == nil:
		if c.endCallsLocked() {
			c.copyLocked(true)
		}
		c.statusChangedLocked()
	default:
		c.turnEndedLocked(end, failure)
	}
}

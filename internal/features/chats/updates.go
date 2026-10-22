package chats

import (
	"path/filepath"
	"strings"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// SessionUpdate turns the agent's updates into transcript items.
func (c *chat) SessionUpdate(n acp.SessionNotification) {
	c.mu.Lock()
	defer c.mu.Unlock()
	switch u := n.Update; u.SessionUpdate {
	case "user_message_chunk": // replayed by session/load
		c.chunkLocked(model.UserMessage, u.UserMessageChunk)
	case "agent_message_chunk":
		c.chunkLocked(model.AgentMessage, u.AgentMessageChunk)
	case "agent_thought_chunk":
		c.chunkLocked(model.Thought, u.AgentThoughtChunk)
	case "plan":
		c.planLocked(u.Plan.Entries)
	case "tool_call":
		t := u.ToolCall
		item := model.Item{ID: string(t.ToolCallID), Kind: model.ToolCall, Title: t.Title,
			ToolKind: string(t.Kind), Status: string(t.Status), Paths: c.paths(t.Locations)}
		item.Text, item.Diffs = c.output(t.Content)
		if it := c.itemLocked(item.ID); it != nil { // a repeated tool_call replaces the call
			*it = item
			c.publishLocked(item)
			return
		}
		c.addLocked(item)
	case "config_option_update":
		c.replaceConfigLocked(u.ConfigOptionUpdate.ConfigOptions)
		c.configChangedLocked()
	case "current_mode_update":
		if i := modeIndex(c.config); i >= 0 {
			c.config[i].Current = string(u.CurrentModeUpdate.CurrentModeID)
			c.configChangedLocked()
		}
	case "session_info_update":
		if t := u.SessionInfoUpdate.Title; t != "" {
			c.saveLocked(func(s *model.Session) { s.Title = t })
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
		if t.Content != nil {
			it.Text, it.Diffs = c.output(t.Content)
		}
		c.publishLocked(*it)
	}
}

// chunkLocked adds a chunk of a message: to the message with its id, or,
// when it has none, to the last item if that is a message of the same kind.
func (c *chat) chunkLocked(kind model.ItemKind, m *acp.ContentChunk) {
	if m.Content.Text == nil {
		return
	}
	text := m.Content.Text.Text
	id := string(m.MessageID)
	if kind == model.Thought && id != "" {
		id = "thought-" + id // a thought may share its message's id
	}
	it := c.itemLocked(id)
	if m.MessageID == "" && len(c.items) > 0 {
		it = &c.items[len(c.items)-1]
	}
	if it != nil && it.Kind == kind {
		it.Text += text
		c.emitLocked(model.Event{ChatID: c.id, Item: &model.Item{ID: it.ID, Kind: kind, Text: text}, Append: true})
		return
	}
	c.addLocked(model.Item{ID: id, Kind: kind, Text: text})
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

// output renders a tool call's content as markdown, its diffs apart.
func (c *chat) output(content []acp.ToolCallContent) (string, []model.FileChange) {
	var parts []string
	var diffs []model.FileChange
	for _, tc := range content {
		switch {
		case tc.Content != nil && tc.Content.Content.Text != nil:
			parts = append(parts, tc.Content.Content.Text.Text)
		case tc.Diff != nil:
			d := tc.Diff
			status := "modified"
			if d.OldText == "" {
				status = "added"
			}
			diffs = append(diffs, model.FileChange{Path: c.rel(d.Path), Status: status, Old: d.OldText, New: d.NewText})
		case tc.Terminal != nil:
			parts = append(parts, "(terminal "+string(tc.Terminal.TerminalID)+")")
		}
	}
	return strings.Join(parts, "\n\n"), diffs
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
	if r, err := filepath.Rel(c.session.Folder, path); err == nil && filepath.IsLocal(r) {
		return r
	}
	return path
}

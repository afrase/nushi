package chats

import (
	"cmp"
	"encoding/base64"
	"encoding/json"
	"path/filepath"
	"slices"
	"strings"

	"github.com/afrase/nushi/acp"
	"github.com/afrase/nushi/internal/model"
)

// update turns the agent's updates into transcript items.
func (c *chat) update(n acp.SessionNotification) {
	c.mu.Lock()
	defer c.mu.Unlock()
	switch u := n.Update; u.SessionUpdate {
	case "user_message_chunk": // replayed by session/load
		c.chunkLocked(model.UserMessage, u.UserMessageChunk)
	case "agent_message_chunk":
		if !c.silentLocked(u.AgentMessageChunk) {
			c.chunkLocked(model.AgentMessage, u.AgentMessageChunk)
		}
	case "agent_thought_chunk":
		c.chunkLocked(model.Thought, u.AgentThoughtChunk)
	case "plan":
		c.planLocked(u.Plan.Entries)
	case "tool_call":
		t := u.ToolCall
		item := model.Item{ID: string(t.ToolCallID), Kind: model.ToolCall, Title: t.Title,
			ToolKind: string(t.Kind), Status: string(t.Status), Paths: c.paths(t.Locations)}
		c.setOutput(&item, t.Content)
		fromClaude(&item, t.Meta, t.RawInput)
		if it := c.itemLocked(item.ID); it != nil { // a repeated tool_call replaces the call
			*it = item
			c.publishLocked(item)
			return
		}
		c.addLocked(item)
	case "available_commands_update":
		c.commands = []model.Command{}
		for _, a := range u.AvailableCommandsUpdate.AvailableCommands {
			cmd := model.Command{Name: a.Name, Description: a.Description}
			if a.Input != nil {
				cmd.Hint = a.Input.Hint
			}
			c.commands = append(c.commands, cmd)
		}
		c.emitLocked(model.Event{ChatID: c.id, Commands: slices.Clone(c.commands)})
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
		c.usage.Used, c.usage.Size = u.Used, u.Size
		if u.Cost != nil { // else the cost reported last still stands
			c.usage.Cost, c.usage.Currency = u.Cost.Amount, u.Cost.Currency
		}
		c.usageChangedLocked()
	case "session_info_update":
		// Claude titles a fork "<title> (fork)"; a moved chat keeps its title.
		if t := u.SessionInfoUpdate.Title; t != "" && t != c.session.Title+" (fork)" {
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
		if t.Content != nil && it.Tool != "SubagentHandback" { // its output is only an acknowledgement
			c.setOutput(it, t.Content)
		}
		fromClaude(it, t.Meta, t.RawInput)
		c.publishLocked(*it)
	}
}

// chunkLocked adds a chunk of a message (text or an image): to the message
// with its id, or, when it has none, to the last item if that is a message
// of the same kind.
func (c *chat) chunkLocked(kind model.ItemKind, m *acp.ContentChunk) {
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
	parent, _ := claudeMeta(m.Meta)
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
		c.emitLocked(model.Event{ChatID: c.id, Item: &model.Item{ID: it.ID, Kind: kind, Text: text}, Append: true})
		return
	}
	c.addLocked(model.Item{ID: id, Kind: kind, Text: text, Images: images, Parent: parent})
}

// claudeMeta reads what Claude adds under _meta.claudeCode: the subagent
// tool call an update comes from (the subagent's own tool calls, text and
// thinking), and a tool call's tool name.
func claudeMeta(meta map[string]any) (parent, tool string) {
	cc, _ := meta["claudeCode"].(map[string]any)
	parent, _ = cc["parentToolUseId"].(string)
	tool, _ = cc["toolName"].(string)
	return parent, tool
}

// fromClaude adds what Claude tells about a tool call: the subagent it
// comes from, its tool's name, for one that starts a subagent (Agent, Task)
// the subagent's type, and for a subagent's SubagentHandback, which ends
// it, the report it hands back as its output. Claude may send the input
// in a later update than the name.
func fromClaude(it *model.Item, meta map[string]any, input json.RawMessage) {
	parent, tool := claudeMeta(meta)
	it.Parent, it.Tool = cmp.Or(it.Parent, parent), cmp.Or(tool, it.Tool)
	var in struct {
		Type    string `json:"subagent_type"`
		Message string `json:"message"`
	}
	json.Unmarshal(input, &in)
	switch it.Tool {
	case "Agent", "Task":
		it.Agent = cmp.Or(in.Type, it.Agent, "Agent")
	case "SubagentHandback":
		it.Text = cmp.Or(in.Message, it.Text)
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
// markdown, its diffs and images apart.
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
		case tc.Terminal != nil:
			parts = append(parts, "(terminal "+string(tc.Terminal.TerminalID)+")")
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
	if r, err := filepath.Rel(c.session.Folder, path); err == nil && filepath.IsLocal(r) {
		return r
	}
	return path
}

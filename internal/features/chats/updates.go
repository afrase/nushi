package chats

import (
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
	case "tool_call":
		t := u.ToolCall
		item := model.Item{ID: string(t.ToolCallID), Kind: model.ToolCall, Title: t.Title,
			ToolKind: string(t.Kind), Status: string(t.Status), Text: output(t.Content)}
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
		if t.Content != nil {
			it.Text = output(t.Content)
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
	it := c.itemLocked(string(m.MessageID))
	if m.MessageID == "" && len(c.items) > 0 {
		it = &c.items[len(c.items)-1]
	}
	if it != nil && it.Kind == kind {
		it.Text += text
		c.emitLocked(model.Event{ChatID: c.id, Item: &model.Item{ID: it.ID, Kind: kind, Text: text}, Append: true})
		return
	}
	c.addLocked(model.Item{ID: string(m.MessageID), Kind: kind, Text: text})
}

func (c *chat) publishLocked(it model.Item) {
	c.emitLocked(model.Event{ChatID: c.id, Item: &it})
}

// output renders a tool call's content as markdown.
func output(content []acp.ToolCallContent) string {
	var parts []string
	for _, tc := range content {
		switch {
		case tc.Content != nil && tc.Content.Content.Text != nil:
			parts = append(parts, tc.Content.Content.Text.Text)
		case tc.Diff != nil:
			d := tc.Diff
			parts = append(parts, fence("diff", "--- "+d.Path+"\n+++ "+d.Path+"\n"+diffLines("-", d.OldText)+diffLines("+", d.NewText)))
		case tc.Terminal != nil:
			parts = append(parts, "(terminal "+string(tc.Terminal.TerminalID)+")")
		}
	}
	return strings.Join(parts, "\n\n")
}

func diffLines(prefix, text string) string {
	if text == "" {
		return ""
	}
	return prefix + strings.ReplaceAll(strings.TrimSuffix(text, "\n"), "\n", "\n"+prefix) + "\n"
}

// fence puts text in a fenced code block whose fence is longer than any run
// of backticks inside it, so the text can't end the block early.
func fence(lang, text string) string {
	longest, run := 0, 0
	for _, r := range text {
		if r == '`' {
			run++
			longest = max(longest, run)
		} else {
			run = 0
		}
	}
	f := strings.Repeat("`", max(3, longest+1))
	return f + lang + "\n" + strings.TrimSuffix(text, "\n") + "\n" + f
}

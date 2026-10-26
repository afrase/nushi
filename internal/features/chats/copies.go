package chats

import (
	"slices"

	"github.com/afrase/nushi/internal/model"
)

// Nushi keeps its own read-only copy of each chat's transcript, as it was
// shown (ADR 0047), for what the agent no longer replays: what came before
// a compaction, and a chat whose session the agent deleted. The agent's
// session stays the source: the copy is never sent to it. Items are written
// as they settle (a message once another item follows it, a tool call once
// it ended, all of them when a turn ends or the agent stops), not as they
// stream. Side chats have none: nobody sees them again.

// The notices a merge of a copy and the agent's replay draws.
const (
	compactedNotice = "compacted"       // the agent compacted the conversation here: before it, the copy alone
	differsNotice   = "history_differs" // the agent's history differs from the copy from here
)

// Copies keeps the copies (internal/transcripts).
type Copies interface {
	// Append adds items, or writes again ones it has; after[i] is the item
	// before items[i] in the transcript ("" for the first).
	Append(chat string, items []model.Item, after []string) error
	// Cut takes item and every item after it out; Drop that item only.
	Cut(chat, item string) error
	Drop(chat, item string) error
	// Replace writes a chat's copy anew.
	Replace(chat string, items []model.Item) error
	// Read returns a chat's copy; nil when it has none.
	Read(chat string) ([]model.Item, error)
	Delete(chat string) error
}

// UseCopies has chats keep copies of their transcripts in c while on
// says so; set once at startup.
func (s *Service) UseCopies(c Copies, on func() bool) {
	s.copies, s.copiesOn = c, on
}

// shownOnly says an item is the chat's state rather than its history:
// notices of how its reopen went, and those the merge of a copy and the
// agent's replay draws. The copy never has them.
func shownOnly(it model.Item) bool {
	return it.Kind == model.Notice && slices.Contains([]string{"reopen_failed", "not_ready", "folder_gone", "session_gone", compactedNotice, differsNotice}, it.Status)
}

// settled says an item is as it will stay, as far as the transcript can
// tell: a message once another item follows it (last says none does), a
// tool call once it ended, a prompt or question once answered; a plan
// changes until the turn ends.
func settled(it model.Item, last bool) bool {
	switch it.Kind {
	case model.AgentMessage, model.Thought:
		return !last
	case model.ToolCall:
		return it.Status == "completed" || it.Status == "failed"
	case model.Permission, model.Question:
		return it.Status != "pending"
	case model.Plan:
		return false
	default:
		return true
	}
}

// copyLocked writes the items that changed since the copy last had them
// and have settled, or with all every one of them (a turn ended, the agent
// stopped). While copies are off nothing is written.
func (c *chat) copyLocked(all bool) {
	if c.copies == nil || c.parent != nil || len(c.unsaved) == 0 {
		return
	}
	if !c.copiesOn() {
		clear(c.unsaved)
		return
	}
	var items []model.Item
	var after []string
	prev := ""
	for i, it := range c.items {
		if shownOnly(it) {
			delete(c.unsaved, it.ID)
			continue
		}
		if c.unsaved[it.ID] && (all || settled(it, i == len(c.items)-1)) {
			delete(c.unsaved, it.ID)
			items, after = append(items, it), append(after, prev)
		}
		prev = it.ID
	}
	if all {
		clear(c.unsaved) // items gone meanwhile
	}
	if err := c.copies.Append(c.id, items, after); err != nil {
		c.logLocked().Warn("transcript copy not written", "items", len(items), "err", err)
	}
}

// cutCopyLocked cuts the copy where the transcript was cut, before item
// (a rewind), whether copies are on or not: the copy keeps to what the chat
// shows.
func (c *chat) cutCopyLocked(item string) {
	for id := range c.unsaved {
		if c.indexLocked(id) < 0 {
			delete(c.unsaved, id)
		}
	}
	if c.copies != nil && c.parent == nil {
		if err := c.copies.Cut(c.id, item); err != nil {
			c.logLocked().Warn("transcript copy not cut", "err", err)
		}
	}
}

// dropCopyLocked takes an item that's gone from the transcript out of the
// copy, if it may be in it.
func (c *chat) dropCopyLocked(it model.Item) {
	if c.unsaved[it.ID] || shownOnly(it) || c.copies == nil || c.parent != nil {
		delete(c.unsaved, it.ID)
		return
	}
	if err := c.copies.Drop(c.id, it.ID); err != nil {
		c.logLocked().Warn("transcript copy: item not dropped", "err", err)
	}
}

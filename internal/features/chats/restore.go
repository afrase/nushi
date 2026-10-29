package chats

import (
	"reflect"
	"slices"
	"strconv"
	"strings"

	"github.com/afrase/nushi/internal/model"
)

// A chat reopens through session/load, which replays the agent's session.
// The replay goes aside rather than into the transcript (replaying), and
// is merged with the chat's copy (merge); the transcript becomes what the
// merge made, and the copy with it. Until then, and when there is no agent
// to replay (an archived chat, one whose session is gone), the transcript
// is the copy.

// replayKinds are the updates session/load replays a transcript with.
var replayKinds = []string{"user_message_chunk", "agent_message_chunk", "agent_thought_chunk", "plan", "tool_call", "tool_call_update"}

// stepKinds are the updates of a subagent's session taken as its steps.
var stepKinds = []string{"agent_message_chunk", "agent_thought_chunk", "tool_call", "tool_call_update"}

// loadCopyLocked makes a chat's copy its transcript, as a chat looked up
// after a daemon start shows it: what was under way when it was written
// can't go on now.
func (c *chat) loadCopyLocked() {
	if c.copies == nil {
		return
	}
	items, err := c.copies.Read(c.id)
	if err != nil {
		c.logLocked().Warn("transcript copy not read", "err", err)
		return
	}
	for i := range items {
		ended(&items[i])
		c.noteID(items[i].ID)
	}
	c.items = items
}

// ended marks what an item had under way as over: a tool call fails, a
// prompt or question is cancelled, a subagent fails, a background command's
// end can't be known.
func ended(it *model.Item) {
	switch {
	case it.Kind == model.ToolCall && (it.Status == "pending" || it.Status == "in_progress"):
		it.Status = "failed"
	case (it.Kind == model.Permission || it.Kind == model.Question) && it.Status == "pending":
		it.Status = "cancelled"
	}
	if it.Subagent != nil && it.Subagent.State == "running" {
		sa := *it.Subagent
		sa.State, sa.Said = "failed", ""
		it.Subagent = &sa
	}
	if it.BackgroundCommand != nil && it.BackgroundCommand.State == "running" {
		sh := *it.BackgroundCommand
		sh.State = "started"
		it.BackgroundCommand = &sh
	}
}

// noteID keeps the ids Nushi gives items (item-N) past one it gave before.
func (c *chat) noteID(id string) {
	if n, err := strconv.Atoi(strings.TrimPrefix(id, "item-")); err == nil && strings.HasPrefix(id, "item-") {
		c.lastItem = max(c.lastItem, n)
	}
}

// restoreLocked makes the chat's transcript from its copy and the agent's
// replay, tells the app what changed, and keeps the copy to what it shows.
func (c *chat) restoreLocked(replayed []model.Item) {
	var copied []model.Item
	if c.copies != nil {
		var err error
		if copied, err = c.copies.Read(c.id); err != nil {
			c.logLocked().Warn("transcript copy not read", "err", err)
		}
	}
	items := merge(copied, replayed, c.dialect.Compacted)
	var compacted, differs bool
	for i := range items {
		it := &items[i]
		c.noteID(it.ID)
		if it.ID != "" {
			continue
		}
		c.lastItem++
		it.ID = "item-" + strconv.Itoa(c.lastItem)
		switch it.Status {
		case compactedNotice:
			it.Title, compacted = "Compacted here", true
		case differsNotice:
			it.Text, differs = c.kind.Title+"'s history differs from Nushi's copy from here on", true
		}
	}
	// A prompt the copy has pending was left by an agent that stopped; one
	// the agent asked while it replayed waits on the user still.
	for i := range items {
		if asking(items[i]) && !c.liveLocked(items[i].ID) {
			items[i].Status = "cancelled"
		}
	}
	for _, it := range c.items {
		if c.liveLocked(it.ID) && !slices.ContainsFunc(items, func(o model.Item) bool { return o.ID == it.ID }) {
			items = append(items, it)
		}
	}
	c.showLocked(items)
	clear(c.unsaved)
	c.saveCopyLocked(copied, items)
	c.logLocked().Info("transcript restored", "copy", len(copied), "replay", len(replayed), "shown", len(items), "compacted", compacted, "differs", differs)
}

// showLocked makes items the transcript: the items from the first that
// differs on are cut, and sent again.
func (c *chat) showLocked(items []model.Item) {
	same := 0
	for same < len(c.items) && same < len(items) && reflect.DeepEqual(c.items[same], items[same]) {
		same++
	}
	if same < len(c.items) {
		c.emitLocked(model.Event{ChatID: c.id, Cut: c.items[same].ID})
	}
	c.items = items
	for _, it := range items[same:] {
		c.emitLocked(model.Event{ChatID: c.id, Item: &it})
	}
}

// saveCopyLocked makes the copy (it had copied) what the chat shows, but
// for what only shows: the items at its end it lacks are added, or it is
// written anew.
func (c *chat) saveCopyLocked(copied, shown []model.Item) {
	if c.copies == nil || c.parent != nil || !c.copiesOn() {
		return
	}
	want := slices.DeleteFunc(slices.Clone(shown), shownOnly)
	n := len(copied)
	var err error
	switch {
	case n == 0 || n <= len(want) && reflect.DeepEqual(copied, want[:n]):
		after := make([]string, len(want)-n)
		for i := range after {
			if n+i > 0 {
				after[i] = want[n+i-1].ID
			}
		}
		err = c.copies.Append(c.id, want[n:], after)
	default:
		err = c.copies.Replace(c.id, want)
	}
	if err != nil {
		c.logLocked().Warn("transcript copy not written", "items", len(want), "err", err)
	}
}

package chats

import (
	"bytes"
	"encoding/json"
	"reflect"
	"slices"
	"strconv"
	"strings"
	"time"

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

// messageTimes is when the agent's own files say a session's messages were
// sent (MessageDater), for restoreLocked. Those files can be long: it
// runs without the chat's lock.
func (c *chat) messageTimes(sid, folder string) map[string]time.Time {
	if c.kind.messageDater == nil {
		return nil
	}
	return c.kind.messageDater.MessageTimes(sid, folder)
}

// restoreLocked makes the chat's transcript from its copy and the agent's
// replay, tells the app what changed, and keeps the copy to what it shows.
// times is what messageTimes read.
func (c *chat) restoreLocked(replayed []model.Item, times map[string]time.Time) {
	var copied []model.Item
	if c.copies != nil {
		var err error
		if copied, err = c.copies.Read(c.id); err != nil {
			c.logLocked().Warn("transcript copy not read", "err", err)
		}
	}
	date := func(it *model.Item) {
		if (it.Kind == model.UserMessage || it.Kind == model.AgentMessage) && it.Sent.IsZero() {
			it.Sent = times[it.ID]
		}
	}
	for i := range replayed {
		date(&replayed[i]) // the copy's may go by an id of Nushi's: pick takes it from here
	}
	items := merge(copied, replayed, c.kind.transcript)
	var compacted, differs bool
	for i := range items {
		it := &items[i]
		c.noteID(it.ID)
		date(it)
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

// showLocked makes items the transcript. An item still in its place that
// changed is sent where it is; only from the first item out of place are
// they cut and sent again, or a client would take down what it shows and
// put it back one item at a time to, say, add the time to an old message.
func (c *chat) showLocked(items []model.Item) {
	kept := 0
	for kept < len(c.items) && kept < len(items) && c.items[kept].ID == items[kept].ID {
		kept++
	}
	old := c.items
	if kept < len(old) {
		c.emitLocked(model.Event{ChatID: c.id, Cut: old[kept].ID})
	}
	c.items = items
	for i, it := range items {
		if i >= kept || !sameItem(old[i], it) {
			c.emitLocked(model.Event{ChatID: c.id, Item: &it})
		}
	}
}

// sameItem says a and b are the same item, one perhaps as the copy has it.
// A copy's item has been through JSON, so a time in it is the same instant
// with no monotonic reading and another location, which reflect.DeepEqual
// tells apart: every message sent since the daemon started would count as
// changed, and a reload would take the transcript down from the first of
// them and send it all again.
func sameItem(a, b model.Item) bool {
	if reflect.DeepEqual(a, b) {
		return true
	}
	ja, err := json.Marshal(a)
	if err != nil {
		return false
	}
	jb, err := json.Marshal(b)
	return err == nil && bytes.Equal(ja, jb)
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

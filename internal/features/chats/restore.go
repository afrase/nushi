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

// underWay says an item has something under way that ended would end.
func underWay(it model.Item) bool {
	return it.Kind == model.ToolCall && (it.Status == "pending" || it.Status == "in_progress") ||
		(it.Kind == model.Permission || it.Kind == model.Question) && it.Status == "pending" ||
		it.Subagent != nil && it.Subagent.State == "running" ||
		it.BackgroundCommand != nil && it.BackgroundCommand.State == "running"
}

// ended marks what an item had under way as over, as a chat's copy read
// back after a daemon start shows it (letgo.go): a tool call fails, a
// prompt or question is cancelled, a subagent fails, a background
// command's end can't be known.
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
// times is what messageTimes read. The items, when they are the copy's as
// it stands (mirrored), stand for it: a long copy isn't read a second time
// while the transcript holds it (ADR 0103).
func (c *chat) restoreLocked(replayed []model.Item, times map[string]time.Time) {
	var copied []model.Item
	switch {
	case c.copies == nil:
	case c.mirrored && len(c.unsaved) == 0:
		copied = slices.DeleteFunc(slices.Clone(c.items), shownOnly)
	default:
		var err error
		if copied, err = c.copies.Read(c.id); err != nil {
			c.logLocked().Warn("transcript copy not read", "err", err)
		}
		c.unread = err != nil // merged with the replay, the copy may be written again
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
	c.repinLocked(items)
	c.showLocked(items)
	clear(c.unsaved)
	c.saveCopyLocked(copied, items)
	c.logLocked().Info("transcript restored", "copy", len(copied), "replay", len(replayed), "shown", len(items), "compacted", compacted, "differs", differs)
}

// showLocked makes items the transcript. What stays, in the order it was,
// stays: a changed item is sent where it is and a new one is sent to where
// it goes (a compaction's mark, which the copy doesn't keep). Only from the
// first that went or moved are items cut and sent again, or a client would
// take down what it shows and put it back one item at a time.
func (c *chat) showLocked(items []model.Item) {
	old := c.items
	place := make(map[string]int, len(items))
	for i, it := range items {
		place[it.ID] = i
	}
	kept, last := 0, -1
	for kept < len(old) {
		i, ok := place[old[kept].ID]
		if !ok || i < last {
			break
		}
		kept, last = kept+1, i
	}
	if kept < len(old) {
		c.emitLocked(model.Event{ChatID: c.id, Cut: old[kept].ID})
	}
	was := make(map[string]model.Item, kept)
	for _, it := range old[:kept] {
		was[it.ID] = it
	}
	c.items = items
	for _, it := range items {
		if prev, ok := was[it.ID]; !ok || !sameItem(prev, it) {
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
// written anew. One that couldn't be read (unread) is left as it is.
func (c *chat) saveCopyLocked(copied, shown []model.Item) {
	if c.copies == nil {
		return
	}
	if !c.copiesOn() || c.unread {
		c.mirrored = false
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
	c.mirrored = err == nil
	if err != nil {
		c.logLocked().Warn("transcript copy not written", "items", len(want), "err", err)
	}
}

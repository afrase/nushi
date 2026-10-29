package chats

import (
	"context"
	"log/slog"
	"slices"
	"time"

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
	Has(chat string) bool
	// List returns every chat's copy, largest first.
	List() ([]model.TranscriptCopy, error)
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
func settled(it *model.Item, last bool) bool {
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
	for i := range c.items {
		it := &c.items[i]
		if shownOnly(*it) {
			delete(c.unsaved, it.ID)
			continue
		}
		if c.unsaved[it.ID] && (all || settled(it, i == len(c.items)-1)) {
			delete(c.unsaved, it.ID)
			items, after = append(items, *it), append(after, prev)
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

// CopyEntry is a chat's copy as Settings lists it: whose it is.
type CopyEntry struct {
	model.TranscriptCopy
	Title, Agent string // "" for a chat Nushi no longer has
}

// ListCopies returns every chat's copy, largest first.
func (s *Service) ListCopies() ([]CopyEntry, error) {
	if s.copies == nil {
		return nil, nil
	}
	list, err := s.copies.List()
	if err != nil {
		return nil, err
	}
	stored, err := s.sessions.Sessions()
	if err != nil {
		return nil, err
	}
	// By id: thousands of chats would make a search per copy quadratic.
	byID := make(map[string]model.Session, len(stored))
	for _, sess := range stored {
		byID[sess.ID] = sess
	}
	out := make([]CopyEntry, len(list))
	for i, c := range list {
		out[i].TranscriptCopy = c
		if sess, ok := byID[c.Chat]; ok {
			out[i].Title, out[i].Agent = cmpTitle(sess), sess.Agent
		}
	}
	return out, nil
}

// ClearCopies deletes the copies of chats, and returns how many there were
// and their size. A chat goes on as before, its history from its agent
// alone; one whose session its agent deleted, kept for its copy, goes
// unless its work keeps it (gone.go).
func (s *Service) ClearCopies(ctx context.Context, chats []string) (n int, bytes int64, err error) {
	if s.copies == nil {
		return 0, 0, nil
	}
	list, err := s.copies.List()
	if err != nil {
		return 0, 0, err
	}
	for _, c := range list {
		if !slices.Contains(chats, c.Chat) {
			continue
		}
		if err := s.copies.Delete(c.Chat); err != nil {
			return n, bytes, err
		}
		n, bytes = n+1, bytes+c.Bytes
		s.mu.Lock()
		ch := s.chats[c.Chat]
		s.mu.Unlock()
		if ch == nil {
			continue
		}
		ch.mu.Lock()
		gone := ch.sessionGone
		ch.mu.Unlock()
		if gone {
			s.expire(ctx, ch, "its transcript's copy was cleared")
		}
	}
	return n, bytes, nil
}

// Older returns the chats whose copies were last written before age ago.
func (s *Service) Older(age time.Duration) ([]string, error) {
	if s.copies == nil {
		return nil, nil
	}
	list, err := s.copies.List()
	var ids []string
	for _, c := range list {
		if time.Since(c.Modified) > age {
			ids = append(ids, c.Chat)
		}
	}
	return ids, err
}

// copiesCheck is how often copies past their days are looked for.
var copiesCheck = time.Hour

// AutoClearCopies deletes the copies last written more than days() ago
// (0: none), now and each hour, until Close.
func (s *Service) AutoClearCopies(days func() int) {
	go func() {
		for {
			s.mu.Lock()
			closing := s.closing
			s.mu.Unlock()
			if closing {
				return
			}
			if d := days(); d > 0 {
				s.clearOlder(time.Duration(d) * 24 * time.Hour)
			}
			time.Sleep(copiesCheck)
		}
	}()
}

func (s *Service) clearOlder(age time.Duration) {
	ids, err := s.Older(age)
	if err == nil && len(ids) > 0 {
		var n int
		var bytes int64
		n, bytes, err = s.ClearCopies(context.Background(), ids)
		slog.Info("transcript copies cleared", "why", "older than "+age.String(), "copies", n, "bytes", bytes)
	}
	if err != nil {
		slog.Warn("clearing old transcript copies", "err", err)
	}
}

package chats

import (
	"errors"
	"slices"

	"github.com/afrase/nushi/internal/model"
)

// ErrNoItem is a page asked for before an item the chat doesn't have: it
// changed since the client's snapshot (a rewind, a compaction's replay).
var ErrNoItem = errors.New("no such item: the chat changed")

// RecentPart is a chat's snapshot with only its recent items.
type RecentPart struct {
	Chat    model.Chat   // its Items are the recent part
	Older   int          // how many items come before them
	Running []model.Item // those before them whose subagent or background command runs, or that ask the user
}

// Recent returns a snapshot of a chat with only its last n items, reaching
// back as a page does (pageStart), with the items before them still
// running or asking: a chat's background tasks show (and stop) before their
// page is loaded, and so does a permission prompt or question a background
// subagent asked long ago, which the chat waits on. Only those items are
// copied (ADR 0026).
func (s *Service) Recent(chatID string, n int) (RecentPart, error) {
	c, err := s.open(chatID)
	if err != nil {
		return RecentPart{}, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.inCopy {
		return c.recentInCopyLocked(n)
	}
	start := pageStart(c.items, len(c.items), n)
	return RecentPart{Chat: c.snapshotLocked(slices.Clone(c.items[start:])), Older: start, Running: runningIn(c.items[:start])}, nil
}

// recentInCopyLocked is Recent for a chat whose items were let go: only
// the part is read whole from the copy. Nothing before it runs or asks
// (reading back ends what was under way).
func (c *chat) recentInCopyLocked(n int) (RecentPart, error) {
	heads, err := c.headsLocked()
	if err != nil {
		return RecentPart{}, err
	}
	start := pageStart(heads, len(heads), n)
	items, err := c.wholeLocked(heads[start:])
	if err != nil {
		return RecentPart{}, err
	}
	return RecentPart{Chat: c.snapshotLocked(items), Older: start}, nil
}

// runningIn is those of items whose subagent or background command runs,
// or that ask the user and are still pending.
func runningIn(items []model.Item) []model.Item {
	var out []model.Item
	for i := range items {
		if running(items[i]) || asking(items[i]) {
			out = append(out, items[i])
		}
	}
	return out
}

// Items returns the page of a chat's items before the one of id before: n
// at most, reaching back to the call of a subagent whose steps are in it,
// and how many items come before the page. Only the page is copied, so a
// long chat's pages cost what they hold; one whose items were let go reads
// only the page whole from its copy (letgo.go).
func (s *Service) Items(chatID, before string, n int) ([]model.Item, int, error) {
	c, err := s.open(chatID)
	if err != nil {
		return nil, 0, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	items := c.items
	if c.inCopy { // a page of the copy's heads, only it read whole
		if items, err = c.headsLocked(); err != nil {
			return nil, 0, err
		}
	}
	end := slices.IndexFunc(items, func(it model.Item) bool { return it.ID == before })
	if end < 0 {
		return nil, 0, ErrNoItem
	}
	start := pageStart(items, end, n)
	if c.inCopy {
		page, err := c.wholeLocked(items[start:end])
		return page, start, err
	}
	return slices.Clone(items[start:end]), start, nil
}

// maxReach is how far before its n items a page reaches back for a
// subagent's call: a subagent that ran beside thousands of items would
// otherwise bring them all into every page. Its steps then come without
// it until the page that has its call is loaded, and today's app shows
// them as loose tool calls, as if the chat's own agent made them, even
// for a running one: its call comes with the recent part
// (RecentPart.Running), but the app's transcript groups steps only under
// a call among its items.
const maxReach = 500

// pageStart is where a page of items ending before end starts: n items
// back, and further back to the call that started a subagent whose steps
// are in the page (and that call's own), so the subagent shows whole,
// within maxReach of it. It looks back only for the calls it
// wants, without an index of the items.
func pageStart(items []model.Item, end, n int) int {
	start := max(0, end-n)
	floor := max(0, start-maxReach)
	want := map[string]bool{}
	// take adds items[from:to] to the page: their calls are wanted, unless
	// they are in it already.
	take := func(from, to int) {
		for _, it := range items[from:to] {
			if it.Parent != "" {
				want[it.Parent] = true
			}
		}
		for _, it := range items[from:to] {
			delete(want, it.ID)
		}
	}
	take(start, end)
	for i := start - 1; i >= floor && len(want) > 0; i-- {
		if want[items[i].ID] {
			take(i, start)
			start = i
		}
	}
	return start
}

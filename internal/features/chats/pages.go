package chats

import (
	"errors"
	"slices"

	"github.com/afrase/nushi/internal/model"
)

// ErrNoItem is a page asked for before an item the chat doesn't have: it
// changed since the client's snapshot (a rewind, a compaction's replay).
var ErrNoItem = errors.New("no such item: the chat changed")

// Recent returns a snapshot of a chat with only its last n items, reaching
// back as a page does (pageStart), and how many items come before them.
// Only those items are copied (ADR 0026).
func (s *Service) Recent(chatID string, n int) (model.Chat, int, error) {
	c, err := s.open(chatID)
	if err != nil {
		return model.Chat{}, 0, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	start := pageStart(c.items, len(c.items), n)
	return c.snapshotLocked(start), start, nil
}

// Items returns the page of a chat's items before the one of id before: n
// at most, reaching back to the call of a subagent whose steps are in it,
// and how many items come before the page. Only the page is copied, so a
// long chat's pages cost what they hold.
func (s *Service) Items(chatID, before string, n int) ([]model.Item, int, error) {
	c, err := s.open(chatID)
	if err != nil {
		return nil, 0, err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	end := slices.IndexFunc(c.items, func(it model.Item) bool { return it.ID == before })
	if end < 0 {
		return nil, 0, ErrNoItem
	}
	start := pageStart(c.items, end, n)
	return slices.Clone(c.items[start:end]), start, nil
}

// pageStart is where a page of items ending before end starts: n items
// back, and further back to the call that started a subagent whose steps
// are in the page (and that call's own), so the subagent shows whole. It
// looks back only for the calls it wants, without an index of the items.
func pageStart(items []model.Item, end, n int) int {
	start := max(0, end-n)
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
	for i := start - 1; i >= 0 && len(want) > 0; i-- {
		if want[items[i].ID] {
			take(i, start)
			start = i
		}
	}
	return start
}
